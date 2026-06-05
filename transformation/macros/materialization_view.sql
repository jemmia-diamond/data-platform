-- Override dbt-postgres view materialization to avoid __dbt_backup CASCADE pattern.
--
-- Default dbt pattern (DANGEROUS):
--   1. ALTER VIEW old RENAME TO __dbt_backup       (dependents now point to __dbt_backup)
--   2. CREATE VIEW old AS ...                       (new view)
--   3. DROP VIEW __dbt_backup CASCADE               (destroys ALL dependent views!)
--
-- This override:
--   Normal run:  CREATE OR REPLACE VIEW  → no rename, no CASCADE, dependent views safe
--   Full refresh: DROP CASCADE + CREATE  → handles column removals
--
{% materialization view, adapter='postgres' %}
  {%- set existing_relation = load_cached_relation(this) -%}
  {%- set target_relation = this.incorporate(type='view') -%}
  {% set grant_config = config.get('grants') %}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {%- if existing_relation is none -%}
    -- First time: create new view
    {% call statement('main') -%}
      create view {{ target_relation }} as {{ sql }}
    {%- endcall %}

  {%- elif should_full_refresh() -%}
    -- Full refresh (--full-refresh): drop + recreate
    -- Needed when removing columns that dependents reference
    -- With eager mode, all dependent views will be rebuilt after
    {% call statement('drop_main') -%}
      drop view if exists {{ target_relation }} cascade
    {%- endcall %}
    {% call statement('main') -%}
      create view {{ target_relation }} as {{ sql }}
    {%- endcall %}

  {%- else -%}
    -- Normal: CREATE OR REPLACE VIEW (no __dbt_backup, no CASCADE)
    -- Adding columns: works perfectly
    -- Removing columns: fails with clear error → use --full-refresh
    {% call statement('main') -%}
      create or replace view {{ target_relation }} as {{ sql }}
    {%- endcall %}
  {%- endif -%}

  {% set should_revoke = should_revoke(existing_relation, full_refresh_mode=True) %}
  {% do apply_grants(target_relation, grant_config, should_revoke=should_revoke) %}

  {% do persist_docs(target_relation, model) -%}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  {{ adapter.commit() }}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
