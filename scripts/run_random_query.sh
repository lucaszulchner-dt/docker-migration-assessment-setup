docker exec -u 0 -it hive-server /bin/bash

git clone https://github.com/hortonworks/hive-testbench

JDBC="jdbc:hive2://localhost:10000/tpcds_db"
QUERY_PATH="/opt/hive/hive-testbench/sample-queries-tpcds"

for i in {1..5}
do
   RANDOM_QUERY=$(find $QUERY_PATH -name "query*.sql" | shuf -n 1)

   echo "------------------------------------------------"
   echo "Run #$i: Executing $RANDOM_QUERY"
   beeline -u "$JDBC" -n root -e "$(cat $RANDOM_QUERY)"

   sleep 5
done