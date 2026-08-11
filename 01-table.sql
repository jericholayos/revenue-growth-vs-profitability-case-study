set search_path TO retail;

-- staging table
CREATE TABLE flat_table (
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(80),
    customer_id VARCHAR(80),
    customer_name VARCHAR(80),
    segment VARCHAR(80),
    country VARCHAR(80),
    city VARCHAR(80),
    state VARCHAR(80),
    postal_code VARCHAR(20),
    region VARCHAR(80),
    product_id VARCHAR(80),
    category VARCHAR(80),
    sub_category VARCHAR(80),
    product_name VARCHAR(255),
    sales DECIMAL(10,2),
    quantity INT,
    discount DECIMAL(3,2),
    profit DECIMAL(10,2)
);



/*====== STAR SCHEMA!!!! =======*/

-- customers table
CREATE TABLE dim_customer (
	customer_id VARCHAR(80) PRIMARY KEY,
	customer_name VARCHAR(80),
	segment VARCHAR(80)
);

INSERT INTO dim_customer (customer_id, customer_name, segment)
SELECT DISTINCT
	customer_id,
	customer_name,
	segment
FROM flat_table
WHERE customer_id IS NOT NULL;


-- products table
CREATE TABLE dim_product (
	product_id VARCHAR(80) PRIMARY KEY,
	product_name VARCHAR(255),
	category VARCHAR(80),
	sub_category VARCHAR(80)
);

INSERT INTO dim_product (product_id, product_name, category, sub_category)
SELECT DISTINCT ON (product_id)
	product_id,
	product_name,
	category,
	sub_category
FROM flat_table
WHERE product_id IS NOT NULL;
	

-- locations table
CREATE TABLE dim_location (
	location_id SERIAL PRIMARY KEY,
	country VARCHAR(80),
	city VARCHAR(80),
	state VARCHAR(80),
	postal_code VARCHAR(80),
	region VARCHAR(80)
);

INSERT INTO dim_location (country, city, state, postal_code, region)
SELECT DISTINCT 
    country, 
    city, 
    state, 
    postal_code, 
    region
FROM flat_table;


-- managers table
CREATE TABLE dim_managers (
	region VARCHAR(80) PRIMARY KEY,
	regional_manager VARCHAR(80)
);

INSERT INTO dim_managers(region, regional_manager)
SELECT
	region,
	regional_manager
FROM stg_region;

-- returns table
CREATE TABLE dim_returns (
	order_id VARCHAR(80) PRIMARY KEY,
	returned VARCHAR(10)
);

INSERT INTO dim_returns(order_id, returned)
SELECT
	order_id,
	returned
FROM stg_returns;

-- sales table
CREATE TABLE fact_sales (
	sales_id SERIAL PRIMARY KEY,
	order_id VARCHAR(80),
	order_date DATE,
	ship_date DATE,
	ship_mode VARCHAR(80),
	customer_id VARCHAR(80),
	product_id VARCHAR(80),
	location_id INT,
	region VARCHAR(80),
	sales DECIMAL(10,2),
	quantity INT,
	discount DECIMAL(3,2),
	profit DECIMAL(10,2),
	FOREIGN KEY(customer_id) REFERENCES dim_customer(customer_id),
	FOREIGN KEY(product_id) REFERENCES dim_product(product_id),
	FOREIGN KEY(location_id) REFERENCES dim_location(location_id),
	FOREIGN KEY(region) REFERENCES dim_managers(region)
);


INSERT INTO fact_sales (
    order_id,
    order_date,
    ship_date,
    ship_mode,
    customer_id,
    product_id,
    location_id,
    region,
    sales,
    quantity,
    discount,
    profit
)
SELECT 
    f.order_id,
    f.order_date,
    f.ship_date,
    f.ship_mode,
    f.customer_id,
    f.product_id,
    l.location_id,
    f.region,
    f.sales,
    f.quantity,
    f.discount,
    f.profit
FROM retail.flat_table f
JOIN retail.dim_location l 
  ON f.country IS NOT DISTINCT FROM l.country
 AND f.city IS NOT DISTINCT FROM l.city
 AND f.state IS NOT DISTINCT FROM l.state
 AND f.postal_code IS NOT DISTINCT FROM l.postal_code
 AND f.region IS NOT DISTINCT FROM l.region;

 
-- Staging table for region
CREATE TABLE stg_region (
	region VARCHAR(80),
	regional_manager VARCHAR(80)
);

-- staging table for returns
CREATE TABLE stg_returns (
	order_id VARCHAR(80),
	returned VARCHAR(80)
);





















