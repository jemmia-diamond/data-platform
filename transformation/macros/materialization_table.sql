-- Override dbt-postgres table materialization to avoid __dbt_backup CASCADE pattern.
--
-- Default dbt pattern (DANGEROUS):
--   1. CREATE TABLE __dbt_tmp AS ...
--   2. ALTER TABLE current RENAME TO __dbt_backup   (dependents now point to __dbt_backup)
--   3. ALTER TABLE __dbt_tmp RENAME TO current
--   4. DROP TABLE __dbt_backup CASCADE               (destroys ALL dependent objects!)
--
-- This override:
--   First time:    CREATE TABLE (normal)
--   Normal run:    Create temp → detect schema changes → ALTER TABLE sync → TRUNCATE → INSERT
--                  Preserves OID, supports schema changes (add columns), no CASCADE
--   Full refresh:  Same pattern as normal run (full data replacement via TRUNCATE+INSERT)
--
-- See: dbt-core issues #2801, #9246 — known 5+ year bug, still open.

{% materialization table, adapter='postgres' %}
  {%- set existing_relation = load_cached_relation(this) -%}
  {%- set target_relation = this.incorporate(type='table') -%}
  {%- set temp_relation = make_temp_relation(target_relation) -%}
  {% set grant_config = config.get('grants') %}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {%- if existing_relation is none -%}
    -- First time: create new table
    {% call statement('main') -%}
      {{ get_create_table_as_sql(False, target_relation, sql) }}
    {%- endcall %}
    {% do create_indexes(target_relation) %}

  {%- else -%}
    -- Existing table: temp → detect schema changes → ALTER TABLE sync → TRUNCATE → INSERT
    -- This avoids the rename/swap/__dbt_backup pattern entirely. Preserves OID, no CASCADE.

    -- Step 1: Create temp table from new SQL (to detect new schema)
    {% do run_query(get_create_table_as_sql(True, temp_relation, sql)) %}

    -- Step 2: Detect and apply schema changes (add new columns)
    {%- set schema_changes = check_for_schema_changes(temp_relation, existing_relation) -%}
    {%- if schema_changes['schema_changed'] -%}
      {%- set add_columns = schema_changes['source_not_in_target'] -%}
      {%- if add_columns | length > 0 -%}
        {%- do alter_relation_add_remove_columns(target_relation, add_columns, none) -%}
        {% set add_msg %}
          [table] Added {{ add_columns | length }} column(s) to {{ target_relation }}:
          {% for col in add_columns %}  - {{ col.name }} ({{ col.data_type }})
          {% endfor %}
        {% endset %}
        {% do log(add_msg, info=true) %}
      {%- endif -%}
    {%- endif -%}

    -- Step 3-4: TRUNCATE + INSERT (only matching columns)
    {%- set source_columns = adapter.get_columns_in_relation(temp_relation) -%}
    {%- set dest_columns = adapter.get_columns_in_relation(target_relation) -%}
    {%- set dest_col_names = [] -%}
    {%- for col in dest_columns -%}
      {%- do dest_col_names.append(col.name) -%}
    {%- endfor -%}
    {%- set select_columns = [] -%}
    {%- for col in source_columns -%}
      {%- if col.name in dest_col_names -%}
        {%- do select_columns.append(col.quoted) -%}
      {%- endif -%}
    {%- endfor -%}

    {% call statement('main') -%}
      truncate table {{ target_relation }};
      insert into {{ target_relation }} ({{ select_columns | join(', ') }})
      select {{ select_columns | join(', ') }} from {{ temp_relation }}
    {%- endcall %}

    -- Step 5: Drop temp table
    {% do adapter.drop_relation(temp_relation) %}

  {%- endif -%}

  {% set should_revoke = should_revoke(existing_relation, full_refresh_mode=True) %}
  {% do apply_grants(target_relation, grant_config, should_revoke=should_revoke) %}
  {% do persist_docs(target_relation, model) %}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  {{ adapter.commit() }}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
