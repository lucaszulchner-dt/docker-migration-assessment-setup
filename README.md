# Hive TPC-DS Docker Environment

A Docker-based environment to simulate a Hive workload for [Google Cloud BigQuery Migration Assessment](https://docs.cloud.google.com/bigquery/docs/migration-assessment).

It includes a **Hive Server**, **Metastore (Postgres)**, and an automated script to generate and load **TPC-DS (Scale Factor 1)** test data using DuckDB.

---

## Quick Start

### 1. Start Services

```bash
docker-compose up -d
```

### 2. Generate & Load TPC-DS Data

Once the containers are running, run the setup script inside the container. This script installs dependencies, generates data, and loads it into Hive.

```bash
docker exec -it hive-server bash /scripts/setup_tpcds_all_in_one.sh
```

> **Note:** This process may take a few minutes as it generates ~1GB of data.

### 3. Connect & Run Queries

Access the Hive CLI via Beeline:

```bash
docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000 -n root
```

Run a sample query:

```sql
USE tpcds_db;
SELECT * FROM customer;
```

---

## Architecture & Volumes

| Service      | Port    | Description                                                          |
|--------------|---------|----------------------------------------------------------------------|
| HiveServer2  | `10000` | Main entry point. Mounts `hive-site.xml` and the Migration Hook JAR. |
| Metastore    | `9083`  | Metadata service backed by Postgres.                                 |
| Postgres     | `5432`  | Internal database for the Metastore.                                 |

### Key Mounts

- **`./scripts`** — Mounted to `/scripts` (contains TPC-DS generation tools).
- **`./hive-hook`** — Contains the migration assessment JAR.
- **`./data`** — Persists Hive warehouse data.

---

## ⚠️ Known Issues

### Query Execution Hangs

- **Status:** Queries with the migration hook enabled may fail execution.
- **Impact:** Migration logs are written successfully to the output directory despite the failure.
