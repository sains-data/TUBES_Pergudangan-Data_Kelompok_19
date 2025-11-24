-- =====================================================
-- 10_Security.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Create Logins, Users, and Roles (RBAC)
-- Engine  : Microsoft SQL Server 2019+
-- Dependencies: 01_Create_Database.sql must be executed first
-- =====================================================

/*
    SECURITY MODEL (SQL SERVER):
    1. Logins : Authentication at Server Level.
    2. Users  : Authorization at Database Level (Mapped to Logins).
    3. Roles  : Grouping permissions.
*/

-- =====================================================
-- 1. CLEANUP (Idempotent Logic)
-- =====================================================

-- Drop Users from Roles if they exist
IF IS_ROLEMEMBER('role_analyst', 'user_bi') = 1 ALTER ROLE role_analyst DROP MEMBER user_bi;
IF IS_ROLEMEMBER('role_etl_admin', 'user_etl') = 1 ALTER ROLE role_etl_admin DROP MEMBER user_etl;

-- Drop Database Users
IF USER_ID('user_bi') IS NOT NULL DROP USER user_bi;
IF USER_ID('user_etl') IS NOT NULL DROP USER user_etl;

-- Drop Database Roles
IF DATABASE_PRINCIPAL_ID('role_analyst') IS NOT NULL DROP ROLE role_analyst;
IF DATABASE_PRINCIPAL_ID('role_etl_admin') IS NOT NULL DROP ROLE role_etl_admin;

-- Note: We do not drop Server Logins automatically to prevent locking out connections 
-- if this script is run on a shared server. We create them if missing.

-- =====================================================
-- 2. CREATE DATABASE ROLES
-- =====================================================

CREATE ROLE role_analyst;
CREATE ROLE role_etl_admin;
GO

-- =====================================================
-- 3. GRANT PERMISSIONS (Schema Level)
-- =====================================================
-- SQL Server Best Practice: Granting on SCHEMA automatically covers 
-- all current AND future tables/views/sequences in that schema.

-- --- ROLE: ANALYST (Read Only) ---
GRANT USAGE ON SCHEMA :: dim TO role_analyst; -- Allow access to schema
GRANT USAGE ON SCHEMA :: fact TO role_analyst;
GRANT USAGE ON SCHEMA :: analytics TO role_analyst;
GRANT USAGE ON SCHEMA :: reports TO role_analyst;

GRANT SELECT ON SCHEMA :: dim TO role_analyst;
GRANT SELECT ON SCHEMA :: fact TO role_analyst;
GRANT SELECT ON SCHEMA :: analytics TO role_analyst;
GRANT SELECT ON SCHEMA :: reports TO role_analyst;

-- --- ROLE: ETL ADMIN (Full Access) ---
-- 'CONTROL' implies all permissions (Select, Insert, Update, Delete, Alter, etc.)
GRANT CONTROL ON SCHEMA :: stg TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: dim TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: fact TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: etl_log TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: dw TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: analytics TO role_etl_admin;
GRANT CONTROL ON SCHEMA :: reports TO role_etl_admin;

-- Grant Execute for Stored Procedures
GRANT EXECUTE TO role_etl_admin;

GO

-- =====================================================
-- 4. CREATE LOGINS (Server Level) & USERS (DB Level)
-- =====================================================

-- User 1: user_bi (Power BI)
-- Create Login (if not exists) in MASTER context check
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'user_bi')
BEGIN
    -- WARNING: Change password policy for production
    CREATE LOGIN user_bi WITH PASSWORD = 'BiPassItera2025!', CHECK_POLICY = OFF;
END

-- Create Database User mapped to Login
IF USER_ID('user_bi') IS NULL
BEGIN
    CREATE USER user_bi FOR LOGIN user_bi;
END

-- User 2: user_etl (ETL Scripts)
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'user_etl')
BEGIN
    CREATE LOGIN user_etl WITH PASSWORD = 'EtlPassItera2025!', CHECK_POLICY = OFF;
END

IF USER_ID('user_etl') IS NULL
BEGIN
    CREATE USER user_etl FOR LOGIN user_etl;
END
GO

-- =====================================================
-- 5. ASSIGN ROLES
-- =====================================================

ALTER ROLE role_analyst ADD MEMBER user_bi;
ALTER ROLE role_etl_admin ADD MEMBER user_etl;
GO

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================
PRINT '======================================================';
PRINT '10_Security.sql executed successfully';
PRINT '======================================================';
PRINT 'Roles created: role_analyst, role_etl_admin';
PRINT 'Permissions assigned via Schema-level grants.';
PRINT 'Users mapped:';
PRINT '1. user_bi (Mapped to role_analyst)';
PRINT '2. user_etl (Mapped to role_etl_admin)';
PRINT '======================================================';

-- ====================== END OF FILE ======================
