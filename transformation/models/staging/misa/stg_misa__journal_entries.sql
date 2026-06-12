{{ config(
    materialized='view',
    schema='staging'
) }}

with raw_journal_entries as (
    select
    -- 		data_details,
            (data_details -> 0 ->> 'posted_date')::DATE AS posted_date,
            (data_details -> 0 ->> 'account_number') AS account_number,
            (data_details -> 0 ->> 'account_object_code') AS account_object_code,
            (data_details -> 0 ->> 'account_object_name') AS account_object_name,
            (data_details -> 0 ->> 'budget_item_code') AS budget_item_code,
            (data_details -> 0 ->> 'budget_item_name') AS budget_item_name,
            (data_details -> 0 ->> 'corresponding_account_number') AS corresponding_account,
            (data_details -> 0 ->> 'credit_amount')::NUMERIC AS credit_amount,
            (data_details -> 0 ->> 'custom_field1') AS custom_field1,
            (data_details -> 0 ->> 'debit_amount')::NUMERIC AS debit_amount,
            (data_details -> 0 ->> 'description') AS description,
            (data_details -> 0 ->> 'employee_code') AS employee_code,
            (data_details -> 0 ->> 'employee_name') AS employee_name,
            (data_details -> 0 ->> 'expense_item_code') AS expense_item_code,
            (data_details -> 0 ->> 'expense_item_name') AS expense_item_name,

            -- Dữ liệu từ hình 2
            (data_details -> 0 ->> 'inv_date')::DATE AS inv_date,
            (data_details -> 0 ->> 'inv_no') AS inv_no,
            (data_details -> 0 ->> 'journal_memo') AS journal_memo,
            (data_details -> 0 ->> 'lending_agreement_refno') AS lending_agreement_refno,
            (data_details -> 0 ->> 'list_item_code') AS list_item_code,
            (data_details -> 0 ->> 'list_item_name') AS list_item_name,
            (data_details -> 0 ->> 'loan_agreement_refno') AS loan_agreement_refno,
            (data_details -> 0 ->> 'order_no') AS order_no,
            (data_details -> 0 ->> 'organization_unit_code') AS organization_unit_code,
            (data_details -> 0 ->> 'organization_unit_name') AS organization_unit_name,
            (data_details -> 0 ->> 'project_work_code') AS project_work_code,
            (data_details -> 0 ->> 'refdate')::DATE AS refdate,
            (data_details -> 0 ->> 'refno') AS refno,
            (data_details -> 0 ->> 'reftype_name') AS reftype_name
    from {{ source('misa', 'journal_entries') }}
)
select
    date_trunc('month', posted_date + INTERVAL '2 month') - INTERVAL '1 day' as posted_date,
    account_number,
    concat(date_trunc('month', posted_date + INTERVAL '2 month') - INTERVAL '1 day' , '_', account_number) as time_account_key,
    account_object_code,
    account_object_name,
    budget_item_code,
    budget_item_name,
    corresponding_account,
    credit_amount,
    custom_field1,
    debit_amount,
    description,
    employee_code,
    employee_name,
    expense_item_code,
    expense_item_name,

    inv_date,
    inv_no,
    journal_memo,
    lending_agreement_refno,
    list_item_code,
    list_item_name,
    loan_agreement_refno,
    order_no,
    organization_unit_code,
    organization_unit_name,
    project_work_code,
    refdate,
    refno,
    reftype_name
from raw_journal_entries