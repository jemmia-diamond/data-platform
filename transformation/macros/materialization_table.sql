-- Override dbt-postgres table materialization to avoid __dbt_backup CASCADE pattern.
--
-- Default dbt pattern (DANGEROUS):
--   1. CREATE TABLE __dbt_tmp AS ...
--   2. ALTER TABLE current RENAME TO __dbt_backup   (dependents now point to __dbt_backup)
--   3. ALTER TABLE __dbt_tmp RENAME TO current
--   4. DROP TABLE __dbt_backup CASCADE               (destroys ALL dependent objects!)
--
-- This override:
--   Normal run:  TRUNCATE + INSERT  → same OID preserved, no CASCADE, dependents safe
--   Full refresh: DROP CASCADE + CREATE  → intentional full rebuild (all dependents get rebuilt)
--
-- See: dbt-core issues #2801, #9246 — known 5+ year bug, still open.

{% materialization table, adapter='postgres' %}
  {%- set existing_relation = load_cached_relation(this) -%}
  {%- set target_relation = this.incorporate(type='table') %}
  {% set grant_config = config.get('grants') %}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {%- if existing_relation is none -%}
    -- First time: create new table
    {% call statement('main') -%}
      {{ get_create_table_as_sql(False, target_relation, sql) }}
    {%- endcall %}

  {%- elif should_full_refresh() -%}
    -- Full refresh (--full-refresh): create tmp → rename swap → drop backup CASCADE
    -- Intentional: all dependent objects should be rebuilt from scratch
    {%- set intermediate_relation = make_intermediate_relation(target_relation) -%}
    {%- set backup_relation_type = existing_relation.type -%}
    {%- set backup_relation = make_backup_relation(target_relation, backup_relation_type) -%}

    {{ drop_relation_if_exists(load_cached_relation(intermediate_relation)) }}
    {{ drop_relation_if_exists(load_cached_relation(backup_relation)) }}

    {% call statement('main') -%}
      {{ get_create_table_as_sql(False, intermediate_relation, sql) }}
    {%- endcall %}

    {% do create_indexes(intermediate_relation) %}

    {% set existing_relation = load_cached_relation(existing_relation) %}
    {% if existing_relation is not none %}
      {{ adapter.rename_relation(existing_relation, backup_relation) }}
    {% endif %}

    {{ adapter.rename_relation(intermediate_relation, target_relation) }}

    {{ run_hooks(post_hooks, inside_transaction=True) }}

    {% set should_revoke = should_revoke(existing_relation, full_refresh_mode=True) %}
    {% do apply_grants(target_relation, grant_config, should_revoke=should_revoke) %}
    {% do persist_docs(target_relation, model) %}

    {{ adapter.commit() }}

    -- Drop backup outside transaction
    {{ drop_relation_if_exists(backup_relation) }}

    {{ run_hooks(post_hooks, inside_transaction=False) }}
    {{ return({'relations': [target_relation]}) }}

  {%- else -%}
    -- Normal run: TRUNCATE + INSERT (preserves OID, no CASCADE, dependents safe)
    {% call statement('main') -%}
      truncate table {{ target_relation }};
      insert into {{ target_relation }} {{ sql }}
    {%- endcall %}

  {%- endif -%}

  {% set should_revoke = should_revoke(existing_relation, full_refresh_mode=True) %}
  {% do apply_grants(target_relation, grant_config, should_revoke=should_revoke) %}
  {% do persist_docs(target_relation, model) %}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  {{ adapter.commit() }}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
