-- Override dbt-postgres materialized_view materialization to avoid __dbt_backup CASCADE issues.
--
-- Default dbt pattern on full-refresh (PROBLEMATIC):
--   DROP MATERIALIZED VIEW <name>   (without CASCADE → fails when dependents exist)
--
-- Since drop_without_cascade.sql removes CASCADE globally, DROP fails:
--   "cannot drop materialized view X because other objects depend on it"
--
-- This override:
--   First time:    CREATE MATERIALIZED VIEW (normal)
--   Normal run:    REFRESH MATERIALIZED VIEW (fast, no DROP)
--   Full refresh:  DROP CASCADE + CREATE (handles schema changes, all dependents rebuilt by dbt)
--
-- CASCADE is safe here because all dependent MVs are within the same dbt project
-- and will be rebuilt by dbt in the correct topological order.
--
-- See: dbt-core issues #2801, #9246 — known 5+ year bug, still open.

{% materialization materialized_view, adapter='postgres' %}
  {%- set existing_relation = load_cached_relation(this) -%}
  {%- set target_relation = this.incorporate(type='materialized_view') -%}
  {% set grant_config = config.get('grants') %}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {%- if existing_relation is none -%}
    -- First time: create new materialized view
    {% call statement('main') -%}
      create materialized view {{ target_relation }} as {{ sql }}
    {%- endcall %}

  {%- elif should_full_refresh() -%}
    -- Full refresh (--full-refresh): DROP CASCADE + CREATE
    -- Needed when adding/removing columns (schema changes)
    -- CASCADE is safe: all dependent MVs are in same dbt project, will be rebuilt after
    {% call statement('drop_main') -%}
      drop materialized view if exists {{ target_relation }} cascade
    {%- endcall %}
    {% call statement('main') -%}
      create materialized view {{ target_relation }} as {{ sql }}
    {%- endcall %}

  {%- else -%}
    -- Normal: REFRESH MATERIALIZED VIEW (fast, no DROP, no CASCADE risk)
    -- Data-only refresh. Schema changes require --full-refresh.
    {% call statement('main') -%}
      refresh materialized view {{ target_relation }}
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
