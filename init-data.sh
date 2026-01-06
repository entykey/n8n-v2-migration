#!/bin/bash
set -e

echo "🚀 Initializing PostgreSQL for n8n..."

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" <<-'EOSQL'

-- ================================
-- 1. Required extensions for n8n
-- ================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ================================
-- 2. Ensure public schema exists
-- ================================

CREATE SCHEMA IF NOT EXISTS public;

-- ================================
-- 3. Safety permissions
-- ================================

GRANT ALL ON SCHEMA public TO CURRENT_USER;
GRANT ALL ON ALL TABLES    IN SCHEMA public TO CURRENT_USER;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO CURRENT_USER;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO CURRENT_USER;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON SEQUENCES TO CURRENT_USER;

-- ================================
-- 4. Optional but recommended
-- ================================

-- Fix search_path (some environments break this)
ALTER DATABASE CURRENT_DATABASE() SET search_path TO public;

-- ================================
-- 5. Diagnostics output
-- ================================

\echo '✅ PostgreSQL initialized for n8n'
\dx

EOSQL

echo "✅ init-data.sh completed successfully"
