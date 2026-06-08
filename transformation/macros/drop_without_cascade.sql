-- Override dbt-postgres drop macros to avoid CASCADE destroying cross-schema dependents.
--
-- Default:
--   drop table if exists <relation> cascade
--   drop materialized view if exists <relation> cascade
--
-- CASCADE destroys ALL objects that depend on the relation, including views/matviews
-- from OTHER dbt runs/jobs that dbt doesn't know about.
--
-- This override removes CASCADE. If the drop fails (dependent objects exist),
-- the backup is left for cleanup at next run start.
--
-- See: dbt-core issues #2801, #9246 — known 5+ year bug, still open.

{% macro postgres__drop_table(relation) -%}
    drop table if exists {{ relation }}
{%- endmacro %}


{% macro postgres__drop_materialized_view(relation) -%}
    drop materialized view if exists {{ relation }}
{%- endmacro %}


{% macro postgres__drop_view(relation) -%}
    drop view if exists {{ relation }}
{%- endmacro %}
