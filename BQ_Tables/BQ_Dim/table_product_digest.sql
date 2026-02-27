/* 

- focal-elf-631.standard_digest.product_digest
- Label table with information on the product.
- Key: product_id
- Notes:
    + product_id might be duplicated. When joining to other tables, use platform_id as well

Schema
    - product_id
    - advertiser_id
    - title
    - type
    - os
    - tracking_bundle
    - domain
    - app_store_bundle
    - app_store_url
    - app_tracking_bundle
    - web
    - category
    - platform
    - service
    - version
    - timestamp
    - is_archived
    - original_json

    column_name	data_type	is_nullable
    product_id	STRING	YES
    advertiser_id	STRING	YES
    title	STRING	YES
    type	STRING	YES
    os	STRING	YES
    tracking_bundle	STRING	YES
    domain	STRING	YES
    app_store_bundle	STRING	YES
    app_store_url	STRING	YES
    app_tracking_bundle	STRING	YES
    web	STRING	YES
    category	STRING	YES
    platform	STRING	YES
    service	STRING	YES
    version	TIMESTAMP	YES
    timestamp	TIMESTAMP	YES
    is_archived	BOOL	YES
    original_json	STRING	YES


*/