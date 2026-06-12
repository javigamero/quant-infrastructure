-- 01-init.sql
-- Runs on first database initialization when mounted to /docker-entrypoint-initdb.d.

-- Ensure TimescaleDB extension is available in the default database.
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Logical schema separation for market and analytics workloads.
CREATE SCHEMA IF NOT EXISTS market_data;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Basic least-privilege role for read-only consumers.
DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'quant_reader') THEN
        CREATE ROLE quant_reader;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'quant_maintainer') THEN
        CREATE ROLE quant_maintainer;
    END IF;
END
$$;

-- Allow the read-only role to connect and read current/future objects.
GRANT CONNECT ON DATABASE postgres TO quant_reader;
GRANT USAGE ON SCHEMA market_data, analytics TO quant_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA market_data, analytics TO quant_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA market_data, analytics
GRANT SELECT ON TABLES TO quant_reader;

-- Allow maintainer role full access to current/future objects in both schemas.
GRANT CONNECT ON DATABASE postgres TO quant_maintainer;
GRANT ALL PRIVILEGES ON SCHEMA market_data, analytics TO quant_maintainer;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA market_data, analytics TO quant_maintainer;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA market_data, analytics TO quant_maintainer;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA market_data, analytics TO quant_maintainer;
ALTER DEFAULT PRIVILEGES IN SCHEMA market_data, analytics
GRANT ALL PRIVILEGES ON TABLES TO quant_maintainer;
ALTER DEFAULT PRIVILEGES IN SCHEMA market_data, analytics
GRANT ALL PRIVILEGES ON SEQUENCES TO quant_maintainer;
ALTER DEFAULT PRIVILEGES IN SCHEMA market_data, analytics
GRANT ALL PRIVILEGES ON FUNCTIONS TO quant_maintainer;

-- Create application users and map them to their schemas.
DO
$$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin') THEN
        CREATE ROLE admin WITH LOGIN PASSWORD 'change_me_admin';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'user1') THEN
        CREATE ROLE user1 WITH LOGIN PASSWORD 'change_me_user1';
    END IF;
END
$$;

-- admin: full access in analytics schema.
GRANT CONNECT ON DATABASE postgres TO admin;
GRANT USAGE, CREATE ON SCHEMA analytics TO admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA analytics TO admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA analytics TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
GRANT ALL PRIVILEGES ON TABLES TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
GRANT ALL PRIVILEGES ON SEQUENCES TO admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics
GRANT ALL PRIVILEGES ON FUNCTIONS TO admin;

-- user1: read-only access in market_data schema.
GRANT CONNECT ON DATABASE postgres TO user1;
GRANT USAGE ON SCHEMA market_data TO user1;
GRANT SELECT ON ALL TABLES IN SCHEMA market_data TO user1;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA market_data TO user1;
ALTER DEFAULT PRIVILEGES IN SCHEMA market_data
GRANT SELECT ON TABLES TO user1;
ALTER DEFAULT PRIVILEGES IN SCHEMA market_data
GRANT SELECT ON SEQUENCES TO user1;

-- Set default schema path for each login role.
ALTER ROLE admin SET search_path = analytics, public;
ALTER ROLE user1 SET search_path = market_data, public;
