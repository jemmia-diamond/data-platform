from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

from dlt.extract.resource import DltResource
from dlt.sources.rest_api import RESTAPIConfig, rest_api_resources


@dataclass(frozen=True)
class TableSpec:
    """Specification for a NocoDB table to ingest."""

    resource_name: str
    table_id: str
    primary_key: Optional[str | list[str]]
    incremental_field: Optional[str]
    view_id: Optional[str] = None
    fields: Optional[str] = None
    column_hints: dict[str, dict[str, str]] = field(default_factory=dict)


# --- R&D ------------------------------------------------------------------
# --- Supply ----------------------------------------------------------------
# --- Marketing -------------------------------------------------------------

TABLE_SPECS: tuple[TableSpec, ...] = (
    # === R&D ===
    TableSpec(
        resource_name="designs",
        table_id="ma0vp8g1sv25mua",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,code,erp_code,backup_code,design_type,gender,design_year,design_seq,usage_status,shape_of_main_stone,product_line,source,variant_number,gold_weight,main_stone,stone_quantity,stone_weight,diamond_holder,design_code,new_code,design_status,published_scope,jewelry_rd_style,ring_band_type,ring_band_style,ring_head_style,ecom_showed,social_post,website,RENDER,RETOUCH,tag,created_date,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="design_details",
        table_id="mxhzqdiwzvkxdf0",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,gold_weight,labour_cost,shape_of_main_stone,main_stone_length,main_stone_width,melee_total_price,design_melee_details,database_created_at,database_updated_at",
        column_hints={
            "database_created_at": {"data_type": "timestamp"},
            "shape_of_main_stone": {"data_type": "text"},
            "main_stone_length": {"data_type": "double"},
            "main_stone_width": {"data_type": "double"},
        },
    ),
    TableSpec(
        resource_name="design_design_images",
        table_id="mj4ak6p2fh804wj",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,design_id,material_color,retouch,tick_sync_to_haravan,note,database_created_at,database_updated_at",
    ),
    # === Supply ===
    TableSpec(
        resource_name="diamonds",
        table_id="m4qggn3vyz5qyqi",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,barcode,report_lab,report_no,price,cogs,product_group,shape,cut,color,clarity,fluorescence,edge_size_1,edge_size_2,carat,original_code,SKU,product_id,variant_id,product_name,qty_onhand,qty_available,qty_commited,qty_incoming,vendor,published_scope,is_incoming,is_have_invoice,country_of_origin,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="moissanite",
        table_id="mohak48lzcj6de0",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,product_group,shape,length,width,color,clarity,fluorescence,cut,polish,symmetry,product_group_norm,shape_norm,length_norm,width_norm,color_norm,clarity_norm,fluorescence_norm,cut_norm,polish_norm,symmetry_norm,haravan_product_id,haravan_variant_id,auto_create,title,price,barcode,moissanite_serials,database_updated_at",
        column_hints={
            "database_updated_at": {"data_type": "timestamp"},
        },
    ),
    TableSpec(
        resource_name="diamond_price_list",
        table_id="mfk81jnuyo6gur8",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,size,color,clarity,title,carat,price,sale_off_price,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="products",
        table_id="mhx7y71vqz64ydn",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,haravan_product_id,vendor,haravan_product_type,design_id,published_scope,title,product_title,ecom_title,handle,template_suffix,published,price_max,price_min,auto_create_haravan,estimated_gold_weight,has_360,diamond_shape,stone_min_width,stone_max_width,stone_min_length,stone_max_length,design_type,design_gender,design_source,design_year,design_seq,design_variant,design_code,ma_thiet_ke_cu,ma_erp,tag,sold_before_2025,plate_parameters,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="variants",
        table_id="mkab64qnm6ab9r5",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,haravan_variant_id,haravan_product_id,barcode,sku,product_id,price,final_discount_price,qty_available,qty_onhand,qty_commited,qty_incoming,category,applique_material,fineness,material_color,size_type,ring_size,title,estimated_gold_weight,design_code,design_type,design_gender,design_source,design_seq,design_variant,design_year,ma_thiet_ke_cu,ma_erp,haravan_product_type,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="variant_serials",
        table_id="mm80xzmei7q85k7",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,serial_number,printing_batch,encode_barcode,final_encoded_barcode,gold_weight,diamond_weight,quantity,supplier,cogs,price,barcode,sku,variant_id,order_id,stock_id,order_on,order_reference,product_name,displayed_title,fulfillment_status_value,last_rfid_scan_time,arrival_date,actual_gold_price,actual_melee_price,actual_labor_cost,is_have_invoice,supplier_invoice,address_invoice,policy,haravan_product_type,design_code,ma_thiet_ke_cu,ma_erp,stock_at,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="temporary_products",
        table_id="m87hzbjkusszj4q",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,haravan_product_id,haravan_variant_id,customer_name,customer_phone,variant_title,code,price,product_information,design_id,category,applique_material,material_color,size_type,ring_size,fineness,design_code,summary,use_case,ticket_type,product_group,gia_report_no,request_code,ref_design_code,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="jewelries",
        table_id="mot7cjdr7uapmcr",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,barcode,category,subcategory,supplier_code,supplier,gold_weight,diamond_weight,price,cogs,quantity,order_code,gender,applique_material,fineness,material_color,size_type,ring_size,storage_size_type,storage_size_1,storage_size_2,design_id,product_name,product_group,product_type,SKU,NEWSKU,design_code,design_type,design_gender,design_source,design_year,design_seq,design_variant,haravan_product_type,vendor,qty_onhand,qty_commited,qty_incoming,qty_available,published_scope,type,supply_product_type,printing_batch,diamond_holder,code_in_title,ring_pair_id,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="variants_haravan_collection",
        table_id="m9kbvsd875ga6pl",
        primary_key=["variants_id", "haravan_collections_id"],
        incremental_field="database_updated_at",
        fields="variants_id,haravan_collections_id,database_updated_at",
    ),
    # === Marketing ===
    TableSpec(
        resource_name="products_haravan_collection",
        table_id="m0ndwr6sst0xywa",
        primary_key=["products_id", "haravan_collections_id"],
        incremental_field="database_updated_at",
        fields="products_id,haravan_collections_id,positive,database_updated_at",
    ),
    TableSpec(
        resource_name="diamonds_haravan_collection",
        table_id="m4nfkbe9wt73fiy",
        primary_key=["diamond_id", "haravan_collection_id", "position"],
        incremental_field="database_updated_at",
        fields="diamond_id,haravan_collection_id,position,is_primary,synced_at,created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="collections",
        table_id="muqhbu3bfkfhxpk",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,collection_name,design_code,database_created_at,database_updated_at",
    ),
    TableSpec(
        resource_name="haravan_collections",
        table_id="m7k3ehq5fv2aijy",
        primary_key="id",
        incremental_field="database_updated_at",
        fields="id,collection_type,title,products_count,haravan_id,auto_create,handle,is_excluded,is_exclusive,discount_type,discount_value,start_date,end_date,database_updated_at",
    ),
)


def build_table_resource(
    *,
    spec: TableSpec,
    base_url: str,
    api_token: str,
    start_date: str,
    end_date: Optional[str] = None,
    full_refresh: bool = False,
) -> DltResource:
    """Create a DltResource for a specific NocoDB table."""
    sync_timestamp = datetime.now(timezone.utc).isoformat()
    endpoint_params: dict[str, Any] = {
        "limit": 200,
    }
    if spec.view_id:
        endpoint_params["viewId"] = spec.view_id
    if spec.fields:
        endpoint_params["fields"] = spec.fields
    if spec.incremental_field and not full_refresh:
        endpoint_params["sort"] = spec.incremental_field

    incremental_config = None
    if spec.incremental_field and not full_refresh:
        def _nodb_convert(val: Any) -> str:
            start_clause = f"({spec.incremental_field},ge,exactDate,{val})"
            if end_date:
                return f"{start_clause}~and({spec.incremental_field},lt,exactDate,{end_date})"
            return start_clause

        incremental_config = {
            "cursor_path": spec.incremental_field,
            "initial_value": start_date,
            "start_param": "where",
            "convert": _nodb_convert,
        }

    resource_def: dict[str, Any] = {
        "name": spec.resource_name,
        "write_disposition": "merge",
        "endpoint": {
            "path": f"tables/{spec.table_id}/records",
            "params": endpoint_params,
            "data_selector": "list",
            "paginator": {
                "type": "offset",
                "limit": 200,
                "total_path": "pageInfo.totalRows",
            },
            "incremental": incremental_config,
        },
    }
    if spec.primary_key:
        resource_def["primary_key"] = spec.primary_key

    config: RESTAPIConfig = {
        "client": {
            "base_url": base_url,
            "headers": {
                "xc-token": api_token,
                "Content-Type": "application/json",
            },
        },
        "resources": [resource_def],
    }

    resource = rest_api_resources(config)[0]
    resource.add_map(lambda item: {**item, "_db_updated_at": sync_timestamp})
    resource.apply_hints(
        columns={
            "_db_updated_at": {
                "data_type": "timestamp",
                "nullable": False,
            }
        }
    )
    resource.max_table_nesting = 0
    return resource


__all__ = ["TableSpec", "TABLE_SPECS", "build_table_resource"]