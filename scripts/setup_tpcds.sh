
docker-compose down -v

docker-compose up -d

docker exec -it -u 0 hive-server bash

apt-get update && apt-get install -y curl unzip git

curl https://install.duckdb.org | sh
export PATH='/root/.duckdb/cli/latest':$PATH

cat <<EOF > generate_all.sql
INSTALL tpcds;
LOAD tpcds;
CALL dsdgen(sf=1);
COPY call_center            TO 'call_center.dat'          (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY catalog_page           TO 'catalog_page.dat'         (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY catalog_returns        TO 'catalog_returns.dat'      (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY catalog_sales          TO 'catalog_sales.dat'        (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY customer               TO 'customer.dat'             (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY customer_address       TO 'customer_address.dat'     (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY customer_demographics  TO 'customer_demographics.dat' (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY date_dim               TO 'date_dim.dat'             (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY household_demographics TO 'household_demographics.dat' (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY income_band            TO 'income_band.dat'          (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY inventory              TO 'inventory.dat'            (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY item                   TO 'item.dat'                 (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY promotion              TO 'promotion.dat'            (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY reason                 TO 'reason.dat'               (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY ship_mode              TO 'ship_mode.dat'            (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY store                  TO 'store.dat'                (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY store_returns          TO 'store_returns.dat'        (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY store_sales            TO 'store_sales.dat'          (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY time_dim               TO 'time_dim.dat'             (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY warehouse              TO 'warehouse.dat'            (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY web_page               TO 'web_page.dat'             (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY web_returns            TO 'web_returns.dat'          (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY web_sales              TO 'web_sales.dat'            (FORMAT CSV, DELIMITER '|', HEADER FALSE);
COPY web_site               TO 'web_site.dat'             (FORMAT CSV, DELIMITER '|', HEADER FALSE);
EOF

duckdb < generate_all.sql

mkdir -p /data/tpcds_db
chmod 777 /data/tpcds_db

beeline -u jdbc:hive2://localhost:10000 -n root -e "CREATE DATABASE IF NOT EXISTS tpcds_db LOCATION '/data/tpcds_db';"

curl -o alltables.sql https://raw.githubusercontent.com/hortonworks/hive-testbench/hdp3/ddl-tpcds/text/alltables.sql

beeline -u jdbc:hive2://localhost:10000 -n root

set hivevar:DB=tpcds_db;
set hivevar:LOCATION=/data/tpcds_db;

!run alltables.sql
!exit

TABLES="call_center catalog_page catalog_returns catalog_sales customer customer_address customer_demographics date_dim household_demographics income_band inventory item promotion reason ship_mode store store_returns store_sales time_dim warehouse web_page web_returns web_sales web_site"
for t in $TABLES; do
    chmod 777 ${t}.dat
    beeline -u jdbc:hive2://localhost:10000 -n root \
      -e "USE tpcds_db; LOAD DATA LOCAL INPATH '${PWD}/${t}.dat' OVERWRITE INTO TABLE ${t};"  
done

#generate metadata (optional? generates extra data, didn't change anything on my tests but if I DESCRIBE FORMATTER table_name; this does adds new datapoints)
TABLES="call_center catalog_page catalog_returns catalog_sales customer customer_address customer_demographics date_dim household_demographics income_band inventory item promotion reason ship_mode store store_returns store_sales time_dim warehouse web_page web_returns web_sales web_site"

for t in $TABLES; do
    echo "Analyzing $t..."
    beeline -u jdbc:hive2://localhost:10000 -n root \
      -e "ANALYZE TABLE tpcds_db.${t} COMPUTE STATISTICS;"
done