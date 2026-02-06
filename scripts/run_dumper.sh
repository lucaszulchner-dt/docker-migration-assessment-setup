#dumper
docker exec -it -u 0 hive-metastore bash

apt-get update && apt-get install -y curl unzip

curl -L -O https://github.com/google/dwh-migration-tools/releases/download/v1.7.0/dwh-migration-tools-v1.7.0.zip

curl -L -O https://github.com/google/dwh-migration-tools/releases/download/v1.7.0/SHA256SUMS.txt

sha256sum --check SHA256SUMS.txt

unzip dwh-migration-tools-v1.7.0.zip

cd dwh-migration-tools-v1.7.0/dumper/bin

./dwh-migration-dumper \
  --connector hiveql \
  --host localhost \
  --port 9083 \
  --hive-metastore-version 3.1.3 \
  --assessment \
  --output /data/assessment.zip



