#invoke with
#docker exec -it hive-server bash /scripts/setup_tpcds_all_in_one.sh


#!/bin/bash
set -e # stop if fails

# 1. install
echo "--- Installing Dependencies ---"
apt-get update -qq && apt-get install -y -qq curl unzip git netcat-openbsd

# 2. duckdb
if ! command -v duckdb &> /dev/null; then
    echo "--- Installing DuckDB ---"
    
    curl -L -o duckdb.zip https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-amd64.zip
    unzip -o duckdb.zip -d /usr/local/bin
    rm duckdb.zip
    chmod +x /usr/local/bin/duckdb
fi

# 3. tpcs data gen
echo "--- Generating TPC-DS Data (SF=1) ---"

if [ ! -f "customer.dat" ]; then
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
else
    echo "Data files already found, skipping generation."
fi

# 4. directories
mkdir -p /data/tpcds_db
chmod 777 /data/tpcds_db
# auth
chmod 777 *.dat

# 5. wait
echo "--- Waiting for HiveServer2 on port 10000 ---"
while ! nc -z 127.0.0.1 10000; do   
  sleep 2
  echo -n "."
done
echo " Ready!"

# 6. db assert
echo "--- Creating Database ---"
beeline -u jdbc:hive2://127.0.0.1:10000 -n root -e "CREATE DATABASE IF NOT EXISTS tpcds_db LOCATION '/data/tpcds_db';"

# 7. create from schema
echo "--- Creating Tables ---"
if [ ! -f "alltables.sql" ]; then
    curl -s -o alltables.sql https://raw.githubusercontent.com/hortonworks/hive-testbench/hdp3/ddl-tpcds/text/alltables.sql
fi

beeline -u jdbc:hive2://127.0.0.1:10000 -n root \
  --hivevar DB=tpcds_db \
  --hivevar LOCATION=/data/tpcds_db \
  -f alltables.sql

# 8. Load
echo "--- Loading Data ---"
TABLES="call_center catalog_page catalog_returns catalog_sales customer customer_address customer_demographics date_dim household_demographics income_band inventory item promotion reason ship_mode store store_returns store_sales time_dim warehouse web_page web_returns web_sales web_site"

CURRENT_DIR=$(pwd)

for t in $TABLES; do
    echo "Loading $t..."
    beeline -u jdbc:hive2://127.0.0.1:10000 -n root \
      --silent=true \
      -e "USE tpcds_db; LOAD DATA LOCAL INPATH '${CURRENT_DIR}/${t}.dat' OVERWRITE INTO TABLE ${t};"
done

echo "--- SUCCESS: TPC-DS Setup Complete ---"