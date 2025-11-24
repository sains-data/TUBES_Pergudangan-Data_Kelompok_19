-- =====================================================
-- 10_Security.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Roles and Users for Data Mart Access
-- Engine  : PostgreSQL
-- Dependencies: 01_Create_Database.sql must be executed first
-- =====================================================

-- 1. RESET ROLES & USERS (Idempotent)
-- Hati-hati: Drop user hanya dilakukan agar script bisa di-run ulang tanpa error
DROP USER IF EXISTS user_bi;
DROP USER IF EXISTS user_etl;
DROP ROLE IF EXISTS role_analyst;
DROP ROLE IF EXISTS role_etl_admin;

-- 2. CREATE ROLES
-- Role untuk Analis BI (Read Only Access)
CREATE ROLE role_analyst;

-- Role untuk ETL Process (Read/Write/Execute Access)
CREATE ROLE role_etl_admin;

-- 3. GRANT USAGE ON SCHEMAS
-- Analyst perlu akses ke schema akhir (Dim, Fact, Analytics, Reports)
GRANT USAGE ON SCHEMA dim, fact, analytics, reports TO role_analyst;

-- ETL perlu akses ke SEMUA schema termasuk Staging dan Log
GRANT USAGE ON SCHEMA stg, dim, fact, etl_log, dw, analytics, reports TO role_etl_admin;

-- 4. GRANT PRIVILEGES FOR ANALYST (Read Only)
-- Hanya boleh SELECT data
GRANT SELECT ON ALL TABLES IN SCHEMA dim TO role_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA fact TO role_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO role_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA reports TO role_analyst;

-- Pastikan tabel yang dibuat di masa depan juga otomatis bisa dibaca oleh Analyst
ALTER DEFAULT PRIVILEGES IN SCHEMA dim GRANT SELECT ON TABLES TO role_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA fact GRANT SELECT ON TABLES TO role_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA analytics GRANT SELECT ON TABLES TO role_analyst;
ALTER DEFAULT PRIVILEGES IN SCHEMA reports GRANT SELECT ON TABLES TO role_analyst;

-- 5. GRANT PRIVILEGES FOR ETL ADMIN (Full Access)
-- Boleh melakukan CRUD (Create, Read, Update, Delete)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA stg TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dim TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA fact TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA etl_log TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dw TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA reports TO role_etl_admin;

-- Grant akses ke Sequence (agar ETL bisa insert data baru dengan auto-increment ID)
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA stg TO role_etl_admin;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA dim TO role_etl_admin;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA fact TO role_etl_admin;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA etl_log TO role_etl_admin;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA dw TO role_etl_admin;

-- Pastikan tabel masa depan juga otomatis bisa diakses ETL
ALTER DEFAULT PRIVILEGES IN SCHEMA stg GRANT ALL PRIVILEGES ON TABLES TO role_etl_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA dim GRANT ALL PRIVILEGES ON TABLES TO role_etl_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA fact GRANT ALL PRIVILEGES ON TABLES TO role_etl_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA etl_log GRANT ALL PRIVILEGES ON TABLES TO role_etl_admin;

-- 6. CREATE USERS & ASSIGN ROLES
-- User untuk Feby (Power BI Connection)
CREATE USER user_bi WITH PASSWORD 'BiPassItera2025!';
GRANT role_analyst TO user_bi;

-- User untuk Zahra (ETL Scripts / Python)
CREATE USER user_etl WITH PASSWORD 'EtlPassItera2025!';
GRANT role_etl_admin TO user_etl;

-- =====================================================
-- NOTICE & VERIFICATION
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '======================================================';
    RAISE NOTICE '10_Security.sql executed successfully';
    RAISE NOTICE '======================================================';
    RAISE NOTICE 'Roles created: role_analyst, role_etl_admin';
    RAISE NOTICE 'Users created:';
    RAISE NOTICE '1. user_bi (Password: BiPassItera2025!) -> Read Only';
    RAISE NOTICE '2. user_etl (Password: EtlPassItera2025!) -> Full Access';
    RAISE NOTICE '======================================================';
END $$;
