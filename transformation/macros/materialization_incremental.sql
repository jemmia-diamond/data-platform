-- Override dbt-postgres incremental materialization to avoid __dbt_backup CASCADE pattern.
--
-- Problem with default incremental + --full-refresh:
--   1. CREATE TABLE __dbt_tmp AS ...
--   2. ALTER TABLE current RENAME TO __dbt_backup   (dependents now point to __dbt_backup)
--   3. ALTER TABLE __dbt_tmp RENAME TO current
--   4. DROP TABLE __dbt_backup CASCADE              (would destroy cross-schema dependents!)
--
-- With drop_without_cascade.sql removing CASCADE, step 4 FAILS if dependents exist.
--
-- This override:
--   First run:    CREATE TABLE (normal)
--   Normal run:   Default incremental merge (delete+insert with unique_key)
--   Full refresh: Create temp → detect schema changes → ALTER TABLE sync → TRUNCATE → INSERT
--                 Preserves OID, supports schema changes, no CASCADE, dependents safe
--
-- See: dbt-core issues #2801, #9246 — known 5+ year bug, still open.

{% materialization incremental, adapter='postgres' %}
  {%- set existing_relation = load_cached_relation(this) -%}
  {%- set target_relation = this.incorporate(type='table') -%}
  {%- set temp_relation = make_temp_relation(target_relation) -%}
  {%- set unique_key = config.get('unique_key') -%}
  {%- set full_refresh_mode = should_full_refresh() -%}
  {%- set on_schema_change = incremental_validate_on_schema_change(config.get('on_schema_change'), default='ignore') -%}
  {% set grant_config = config.get('grants') %}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {%- if existing_relation is none -%}
    -- First time: create new table
    {% set build_sql = get_create_table_as_sql(False, target_relation, sql) %}
    {% call statement("main") %}
        {{ build_sql }}
    {% endcall %}
    {% do create_indexes(target_relation) %}

  {%- elif full_refresh_mode -%}
    -- Full refresh without CASCADE: ALTER TABLE + TRUNCATE + INSERT pattern
    --
    -- 1. Create temp table from new SQL (to detect schema)
    -- 2. Sync schema changes: ALTER TABLE target ADD/DROP columns
    -- 3. TRUNCATE target (preserves OID, dependents still point to it)
    -- 4. INSERT new data into target
    -- 5. Drop temp table
    -- No rename/swap/__dbt_backup → no CASCADE risk

    -- Step 1: Create temp table to detect new schema
    {% do run_query(get_create_table_as_sql(True, temp_relation, sql)) %}

    -- Step 2: Sync schema changes (add new columns, optionally drop old)
    {%- set schema_changes = check_for_schema_changes(temp_relation, existing_relation) -%}
    {%- if schema_changes['schema_changed'] -%}
      {%- set add_columns = schema_changes['source_not_in_target'] -%}
      {%- if add_columns | length > 0 -%}
        {%- do alter_relation_add_remove_columns(target_relation, add_columns, none) -%}
        {% set add_msg %}
          [incremental full-refresh] Added {{ add_columns | length }} column(s) to {{ target_relation }}:
          {% for col in add_columns %}  - {{ col.name }} ({{ col.data_type }})
          {% endfor %}
        {% endset %}
        {% do log(add_msg, info=true) %}
      {%- endif -%}
    {%- endif -%}

    -- Step 3-4: TRUNCATE + INSERT (preserves OID, no CASCADE)
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

  {%- else -%}
    -- Normal incremental run: use default strategy (delete+insert for postgres)
    {% do run_query(get_create_table_as_sql(True, temp_relation, sql)) %}
    {%- set contract_config = config.get('contract') -%}
    {%- if not contract_config or not contract_config.enforced -%}
      {% do adapter.expand_target_column_types(
               from_relation=temp_relation,
               to_relation=target_relation) %}
    {%- endif -%}
    {%- set dest_columns = process_schema_changes(on_schema_change, temp_relation, existing_relation) -%}
    {%- if not dest_columns -%}
      {%- set dest_columns = adapter.get_columns_in_relation(existing_relation) -%}
    {%- endif -%}
    {%- set incremental_predicates = config.get('predicates', none) or config.get('incremental_predicates', none) -%}
    {%- set strategy_sql_macro_func = adapter.get_incremental_strategy_macro(context, config.get('incremental_strategy') or 'default') -%}
    {%- set strategy_arg_dict = ({'target_relation': target_relation, 'temp_relation': temp_relation, 'unique_key': unique_key, 'dest_columns': dest_columns, 'incremental_predicates': incremental_predicates }) -%}
    {%- set build_sql = strategy_sql_macro_func(strategy_arg_dict) -%}
    {% call statement("main") %}
        {{ build_sql }}
    {% endcall %}

  {%- endif -%}

  {% set should_revoke = should_revoke(existing_relation, full_refresh_mode) %}
  {% do apply_grants(target_relation, grant_config, should_revoke=should_revoke) %}
  {% do persist_docs(target_relation, model) %}

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  -- `COMMIT` happens here
  {% do adapter.commit() %}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {{ return({'relations': [target_relation]}) }}

{% endmaterialization %}
