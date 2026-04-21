from .orders import build_orders_resource
from .customers import build_customers_resource
from .products import build_products_resource
from .locations import build_locations_resource
from .events import build_events_resource
from .users import build_users_resource
from .custom_collections import build_custom_collections_resource
from .smart_collections import build_smart_collections_resource

__all__ = [
    "build_orders_resource",
    "build_customers_resource",
    "build_products_resource",
    "build_locations_resource",
    "build_events_resource",
    "build_users_resource",
    "build_custom_collections_resource",
    "build_smart_collections_resource",
]
