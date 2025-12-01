-- =====================================================
-- 10_Security.sql
-- POSTGRESQL VERSION (Fixed from SQL Server)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Users and Roles (RBAC)
-- Engine  : PostgreSQL 14+
-- =====================================================

-- =====================================================
-- 1. CREATE ROLES
-- =====================================================

DROP ROLE IF EXISTS role_analyst CASCADE;
DROP ROLE IF EXISTS role_etl_admin CASCADE;

CREATE ROLE role_analyst WITH NOINHERIT;
CREATE ROLE role_etl_admin WITH NOINHERIT;

-- =====================================================
-- 2. CREATE USERS (LOGINS)
-- =====================================================

DROP USER IF EXISTS user_bi CASCADE;
DROP USER IF EXISTS user_etl CASCADE;

CREATE USER user_bi WITH PASSWORD 'BiPassItera2025!' NOINHERIT;
CREATE USER user_etl WITH PASSWORD 'EtlPassItera2025!' NOINHERIT;

-- =====================================================
-- 3. GRANT PERMISSIONS (SCHEMA LEVEL)
-- =====================================================

-- --- ROLE: ANALYST (Read Only) ---
GRANT USAGE ON SCHEMA dim TO role_analyst;
GRANT USAGE ON SCHEMA fact TO role_analyst;
GRANT USAGE ON SCHEMA analytics TO role_analyst;
GRANT USAGE ON SCHEMA reports TO role_analyst;

GRANT SELECT ON ALL TABLES IN SCHEMA dim TO role_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA fact TO role_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO role_analyst;
GRANT SELECT ON ALL TABLES IN SCHEMA reports TO role_analyst;

-- --- ROLE: ETL ADMIN (Full Access) ---
GRANT USAGE ON SCHEMA stg TO role_etl_admin;
GRANT USAGE ON SCHEMA dim TO role_etl_admin;
GRANT USAGE ON SCHEMA fact TO role_etl_admin;
GRANT USAGE ON SCHEMA etl_log TO role_etl_admin;
GRANT USAGE ON SCHEMA dw TO role_etl_admin;
GRANT USAGE ON SCHEMA analytics TO role_etl_admin;
GRANT USAGE ON SCHEMA reports TO role_etl_admin;
GRANT USAGE ON SCHEMA etl TO role_etl_admin;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA stg TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dim TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA fact TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA etl_log TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA dw TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA analytics TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA reports TO role_etl_admin;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA stg TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA dim TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA fact TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA etl_log TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA dw TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA analytics TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA reports TO role_etl_admin;

GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA etl TO role_etl_admin;
GRANT ALL PRIVILEGES ON ALL PROCEDURES IN SCHEMA etl TO role_etl_admin;

-- =====================================================
-- 4. ASSIGN USERS TO ROLES
-- =====================================================

GRANT role_analyst TO user_bi;
GRANT role_etl_admin TO user_etl;

-- =====================================================
-- 5. SET ROLE DEFAULT
-- =====================================================

ALTER USER user_bi IN DATABASE datamart_bau_itera SET ROLE role_analyst;
ALTER USER user_etl IN DATABASE datamart_bau_itera SET ROLE role_etl_admin;

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================

SELECT 'Security setup completed successfully.' as status;
SELECT 'Roles created: role_analyst, role_etl_admin' as info1;
SELECT 'Users created: user_bi, user_etl' as info2;

-- ====================== END OF FILE ======================
