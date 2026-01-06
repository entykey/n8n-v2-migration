# 📘 Upgrade n8n v1.120.x → v2.x (PostgreSQL, Docker Compose)

Created by: NGUYEN HUU ANH TUAN
Created time: January 5, 2026 5:30 PM
Last edited by: NGUYEN HUU ANH TUAN
Last updated time: January 6, 2026 11:16 AM


## 🎯 Mục tiêu

- Upgrade **n8n từ v1.120.x lên v2.x**
- **KHÔNG mất dữ liệu** (workflow, credentials)
- Sử dụng **PostgreSQL + Redis**
- Fix triệt để lỗi migration:
    
    ```
    functiongen_random_uuid() does not exist
    ```
    

---

## 🧱 Cấu trúc thư mục

```
.
├── docker-compose.yml
├── docker-compose-v1-backup.yml   # (optional) compose cũ
├── .env
├── init-data.sh
└── README.md
```

---

## ⚙️ Yêu cầu

- Docker + Docker Compose v2
- Không đổi `N8N_ENCRYPTION_KEY` trong suốt quá trình upgrade

---

## 🔐 File `.env`

```
# ====================
# POSTGRESQL DATABASE
# ====================
POSTGRES_USER=postgres
POSTGRES_PASSWORD=Abc@1234
POSTGRES_DB=n8n_db
POSTGRES_NON_ROOT_USER=n8n_user
POSTGRES_NON_ROOT_PASSWORD=Abc@1234

# ====================
# N8N CONFIGURATION
# ====================
N8N_HOST=localhost  # Tạm thời dùng localhost để test
N8N_ENCRYPTION_KEY=Abc@1234Abc@1234Abc@1234Abc@1234

# ====================
# TEMPORARY FOR TESTING
# ====================
# Comment SSL settings for now
# N8N_SSL_CERT=/home/certs/fullchain.pem
# N8N_SSL_KEY=/home/certs/privkey.pem

# Change to HTTP for testing
N8N_PROTOCOL=http
WEBHOOK_URL=http://${N8N_HOST}:8443
WEBHOOK_TUNNEL_URL=http://${N8N_HOST}:8443
VUE_APP_URL_BASE_API=http://${N8N_HOST}:8443
N8N_PORT=5678  # Change to default HTTP port

```

⚠️ **RẤT QUAN TRỌNG**

`N8N_ENCRYPTION_KEY` phải **giữ nguyên** giữa v1 và v2

→ nếu đổi, credentials sẽ bị lỗi.

---

## 🗄️ init-data.sh (chỉ chạy khi DB mới)

> File này chỉ dùng khi khởi tạo database mới
> 
> 
> Không chạy lại với DB đã có data.
> 

```bash
#!/bin/bash
set -e

echo "🚀 Initializing PostgreSQL for n8n..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
  CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

  CREATE SCHEMA IF NOT EXISTS public;

  GRANT ALL ON SCHEMA public TO "$POSTGRES_USER";
  GRANT ALL ON ALL TABLES IN SCHEMA public TO "$POSTGRES_USER";
  GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO "$POSTGRES_USER";

  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES TO "$POSTGRES_USER";

  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO "$POSTGRES_USER";
EOSQL

echo "✅ PostgreSQL initialized successfully for n8n"

```

---

## 🧪 PHASE 1 — Reproduce: Chạy n8n v1.120.x & tạo data (workflow)

```bash
docker compose down -v
docker compose up -d
```

- Truy cập UI n8n v1
- Tạo workflow
- Lưu workflow
- (Optional) tạo credential

👉 Xác nhận: **có data trong DB**

---

## 🔎 PHASE 2 — Chuẩn bị database cho upgrade (BẮT BUỘC)

### 1️⃣ Vào PostgreSQL

```bash
dockerexec -it postgres psql -U postgres
```

### 2️⃣ Xác định DB n8n

```sql
\l
```

Ví dụ thấy DB:

```
n8n_db
```

### 3️⃣ Kết nối đúng DB

```sql
\c n8n_db
```

### 4️⃣ Enable extensions (QUAN TRỌNG NHẤT)

```sql
CREATE EXTENSION IFNOTEXISTS pgcrypto;
CREATE EXTENSION IFNOTEXISTS "uuid-ossp";
```

### 5️⃣ Verify

```sql
\dx
```

Phải thấy:

```
pgcrypto
uuid-ossp
```

👉 Nếu **không có `pgcrypto`** → upgrade v2 **SẼ FAIL**

---

## 💾 (Khuyến nghị) Backup DB trước khi upgrade

```bash
dockerexec postgres pg_dump -U postgres n8n_db > before_upgrade.sql
```

---

## 🚀 PHASE 3 — Upgrade lên n8n v2.x (KHÔNG mất data)

### 1️⃣ Sửa `docker-compose.yml`

Chỉ đổi image:

```diff
- image: n8nio/n8n:1.120.4
+ image: n8nio/n8n:2.3.0
```

Áp dụng cho:

- `n8n`
- `n8n-worker`

❌ Không đổi volumes / env / encryption key

---

### 2️⃣ Restart stack (KHÔNG `v`)

```bash
docker compose down
docker compose pull
docker compose up -d
```

Log từ lúc chèn data vào phiên bản 1.120.4

```bash
user@TuanhayhoMacBookPro n8n-test % docker compose up -d
[+] Running 8/8
 ✔ Network n8n-test_n8n-network     Created                                                                                                                                       0.2s
 ✔ Volume "n8n-test_n8n_storage"    Created                                                                                                                                       0.0s
 ✔ Volume "n8n-test_db_storage"     Created                                                                                                                                       0.0s
 ✔ Volume "n8n-test_redis_storage"  Created                                                                                                                                       0.0s
 ✔ Container postgres               Healthy                                                                                                                                      12.1s
 ✔ Container redis                  Healthy                                                                                                                                       6.6s
 ✔ Container n8n                    Started                                                                                                                                      12.0s
 ✔ Container n8n_worker             Started     
                                                                                                                                  12.2s
user@TuanhayhoMacBookPro n8n-test % docker exec -it postgres psql -U postgres

psql (11.16 (Debian 11.16-1.pgdg90+1))
Type "help" for help.

postgres=# \c postgres
You are now connected to database "postgres" as user "postgres".
postgres-# \dx
                 List of installed extensions
  Name   | Version |   Schema   |         Description
---------+---------+------------+------------------------------
 plpgsql | 1.0     | pg_catalog | PL/pgSQL procedural language
(1 row)

postgres-# \l
                                 List of databases
   Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
-----------+----------+----------+------------+------------+-----------------------
 n8n_db    | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
 template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
           |          |          |            |            | postgres=CTc/postgres
(4 rows)

postgres-# \c n8n_db
You are now connected to database "n8n_db" as user "postgres".

n8n_db=# CREATE EXTENSION IF NOT EXISTS pgcrypto;
NOTICE:  extension "pgcrypto" already exists, skipping
CREATE EXTENSION
n8n_db=# CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
NOTICE:  extension "uuid-ossp" already exists, skipping
CREATE EXTENSION
n8n_db=# \dx
                            List of installed extensions
   Name    | Version |   Schema   |                   Description
-----------+---------+------------+-------------------------------------------------
 pgcrypto  | 1.3     | public     | cryptographic functions
 plpgsql   | 1.0     | pg_catalog | PL/pgSQL procedural language
 uuid-ossp | 1.1     | public     | generate universally unique identifiers (UUIDs)
(3 rows)

n8n_db=# \q

What's next:
    Try Docker Debug for seamless, persistent debugging tools in any container or image → docker debug postgres
    Learn more at https://docs.docker.com/go/debug-cli/
user@TuanhayhoMacBookPro n8n-test % docker compose down
[+] Running 5/5
 ✔ Container n8n_worker          Removed                                                                                                                             0.9s
 ✔ Container n8n                 Removed                                                                                                                             0.5s
 ✔ Container postgres            Removed                                                                                                                             0.7s
 ✔ Container redis               Removed                                                                                                                             0.8s
 ✔ Network n8n-test_n8n-network  Removed                                                                                                                             0.6s
user@TuanhayhoMacBookPro n8n-test % docker compose pull

[+] Pulling 4/4
 ✔ n8n-worker Skipped - Image is already being pulled by n8n                                                                                                         0.0s
 ✔ redis Pulled                                                                                                                                                      9.1s
 ✔ postgres Pulled                                                                                                                                                   9.6s
 ✔ n8n Pulled                                                                                                                                                       10.9s
user@TuanhayhoMacBookPro n8n-test % docker compose up -d

[+] Running 5/5
 ✔ Network n8n-test_n8n-network  Created                                                                                                                             0.2s
 ✔ Container postgres            Healthy                                                                                                                            12.5s
 ✔ Container redis               Healthy                                                                                                                             7.5s
 ✔ Container n8n                 Started                                                                                                                            12.6s
 ✔ Container n8n_worker          Started                                                                                                                            12.6s
user@TuanhayhoMacBookPro n8n-test %
```

---

### 3️⃣ Theo dõi migration

```bash
docker logs -f n8n
```

Log thành công sẽ có dạng:

```
2026-01-06 11:03:56 Last session crashed
2026-01-06 11:04:06 Initializing n8n process
2026-01-06 11:04:07 n8n ready on ::, port 5678
2026-01-06 11:04:07 n8n Task Broker ready on 127.0.0.1, port 5679
2026-01-06 11:04:07 Failed to start Python task runner in internal mode. because Python 3 is missing from this system. Launching a Python runner in internal mode is intended only for debugging and is not recommended for production. Users are encouraged to deploy in external mode. See: https://docs.n8n.io/hosting/configuration/task-runners/#setting-up-external-mode
2026-01-06 11:04:07 
2026-01-06 11:04:07 There is a deprecation related to your environment variables. Please take the recommended actions to update your configuration:
2026-01-06 11:04:07  - OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS -> Running manual executions in the main instance in scaling mode is deprecated. Manual executions will be routed to workers in a future version. Please set `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true` to offload manual executions to workers and avoid potential issues in the future. Consider increasing memory available to workers and reducing memory available to main.
2026-01-06 11:04:07 
2026-01-06 11:04:07 [license SDK] Skipping renewal on init: license cert is not initialized
2026-01-06 11:04:10 Registered runner "JS Task Runner" (0TQv3ZHkQpfsMh_Szb2jE) 
2026-01-06 11:04:12 Version: 2.3.0
2026-01-06 11:04:12 
2026-01-06 11:04:12 Editor is now accessible via:
2026-01-06 11:04:12 http://localhost:5678
```

---

## ✅ PHASE 4 — Verify sau upgrade

Truy cập:

👉 [http://localhost:5678](http://localhost:5678/)

Checklist:

- [x]  UI n8n v2 load được
- [x]  Workflow từ v1 **vẫn còn**
- [x]  Workflow mở được
- [x]  Chạy workflow OK
- [x]  Credential không bị invalid

---

## ⚠️ Lỗi thường gặp & cách fix

### ❌ `function gen_random_uuid() does not exist`

➡️ Nguyên nhân: **thiếu pgcrypto trong DB cũ**

➡️ Fix:

```sql
CREATE EXTENSION pgcrypto;
```

---

### ❌ Credential bị lỗi sau upgrade

➡️ Nguyên nhân: đổi `N8N_ENCRYPTION_KEY`

➡️ Fix: khôi phục lại key cũ

---

### ⚠️ Warning Python task runner missing

```
Failed to start Python task runner in internal mode
```

➡️ **Không ảnh hưởng**, có thể bỏ qua

---

## 🏁 Kết luận

- n8n **v1 → v2 upgrade thành công**
- Không mất data
- Root cause lỗi migration: **PostgreSQL thiếu pgcrypto**
- init-data.sh chỉ áp dụng cho DB mới
