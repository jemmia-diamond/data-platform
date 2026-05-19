{#
    Safely cast a column to JSONB with comprehensive error handling.
    
    This macro handles common data quality issues in JSON columns:
    - NULL values
    - Empty strings
    - Whitespace-only strings
    - Malformed JSON that looks like arrays/objects
    - Complete garbage data
    
    Args:
        column_name: The column to cast (can be text, varchar, or already jsonb)
        default_fallback: Default value when cast fails (default: '[]'::jsonb)
        
    Returns:
        A JSONB value, guaranteed to never throw an error
        
    Usage:
        {{ safe_cast_jsonb('my_json_column') }}
        {{ safe_cast_jsonb('my_json_column', "'{}'::jsonb") }}
        {{ safe_cast_jsonb('my_json_column', 'NULL::jsonb') }}
#}
{% macro safe_cast_jsonb(column_name, default_fallback="'[]'::jsonb") %}
    CASE 
        -- 1. NULL values: return fallback immediately
        WHEN {{ column_name }} IS NULL THEN {{ default_fallback }}
        
        -- 2. Empty or whitespace-only strings: return fallback
        WHEN TRIM({{ column_name }}::text) = '' THEN {{ default_fallback }}
        
        -- 3. Already valid JSON: cast directly
        --    This is the happy path for clean data
        WHEN {{ column_name }}::text IS JSON THEN {{ column_name }}::jsonb
        
        -- 4. Malformed but looks like array: return empty array
        --    Handles cases like "[incomplete" or "[1,2,3" 
        WHEN TRIM({{ column_name }}::text) LIKE '[%' THEN '[]'::jsonb
        
        -- 5. Malformed but looks like object: return empty object
        --    Handles cases like "{{ '{' }}incomplete" or '{{ '{' }}"key":"val'
        WHEN TRIM({{ column_name }}::text) LIKE '{{ '{' }}%' THEN '{{ '{}' }}'::jsonb
        
        -- 6. Ultimate fallback for unrecognizable data
        --    This catches everything else: random text, numbers, etc.
        ELSE {{ default_fallback }}
    END
{% endmacro %}