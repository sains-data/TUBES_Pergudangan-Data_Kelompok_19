-- =====================================================
-- 10_Security.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Logins, Users, and Roles (RBAC)
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

USE datamart_bau_itera;
GO

PRINT '>> Setting up Security (Logins, Users, Roles)...';

-- =====================================================
-- 1. CREATE SERVER LOGINS (If not exists)
-- =====================================================
-- Note: CHECK_POLICY = OFF is used for dev simplicity. 
-- In production, enable password policies.

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'user_bi')
BEGIN
    CREATE LOGIN user_bi WITH PASSWORD = 'BiPassItera2025!', CHECK_POLICY = OFF;
    PRINT '>> Login user_bi created.';
END

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'user_etl')
BEGIN
    CREATE LOGIN user_etl WITH PASSWORD = 'EtlPassItera2025!', CHECK_POLICY = OFF;
    PRINT '>> Login user_etl created.';
END
GO

-- =====================================================
-- 2. CREATE DATABASE USERS
-- =====================================================

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'user_bi')
BEGIN
    CREATE USER user_bi FOR LOGIN user_bi;
    PRINT '>> Database User user_bi created.';
END

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'user_etl')
BEGIN
    CREATE USER user_etl FOR LOGIN user_etl;
    PRINT '>> Database User user_etl created.';
END
GO

-- =====================================================
-- 3. CREATE DATABASE ROLES
-- =====================================================

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'role_analyst' AND type = 'R')
BEGIN
    CREATE ROLE role_analyst;
    PRINT '>> Role role_analyst created.';
END

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'role_etl_admin' AND type = 'R')
BEGIN
    CREATE ROLE role_etl_admin;
    PRINT '>> Role role_etl_admin created.';
END
GO

-- =====================================================
-- 4. GRANT PERMISSIONS (SCHEMA LEVEL)
-- =====================================================
-- Note: Granting on SCHEMA covers tables, views, and procs within it automatically.

PRINT '>> Granting Permissions...';

-- --- ROLE: ANALYST (Read Only) ---
-- Grant SELECT on schemas needed for analysis
GRANT SELECT ON SCHEMA :: dim TO role_analyst;
GRANT SELECT ON SCHEMA :: fact TO role_analyst;
GRANT SELECT ON SCHEMA :: analytics TO role_analyst;
GRANT SELECT ON SCHEMA :: reports TO role_analyst;

-- --- ROLE: ETL ADMIN (Full Access) ---
-- Grant CONTROL (All Privileges) on schemas needed for ETL
GRANT CONTROL ON SCHEMA :: stg TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: dim TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: fact TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: etl_log TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: dw TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: analytics TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: reports TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: etl TO role_etl_admin;

-- Specifically allow execution of Stored Procedures in 'etl' schema
GRANT EXECUTE ON SCHEMA :: etl TO role_etl_admin;

GO

-- =====================================================
-- 5. ASSIGN USERS TO ROLES
-- =====================================================

PRINT '>> Assigning Users to Roles...';

-- Add user_bi to role_analyst
ALTER ROLE role_analyst ADD MEMBER user_bi;

-- Add user_etl to role_etl_admin
ALTER ROLE role_etl_admin ADD MEMBER user_etl;

-- =====================================================
-- SUCCESS MESSAGE
-- =====================================================

PRINT '>> Security setup completed successfully.';
PRINT '>> Roles: role_analyst (read-only), role_etl_admin (full)';
PRINT '>> Users: user_bi (analyst), user_etl (etl admin)';
GO
