-- =====================================================
-- 11_Backup.sql
-- SQL SERVER VERSION (CORRECTED)
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Backup Infrastructure & Strategy
-- Target  : SQL Server 2019+ / Azure SQL
-- =====================================================

/*
    NOTE: SQL Server Backup Strategy
    
    1. Full Backup (T-SQL Command):
       BACKUP DATABASE [datamart_bau_itera] 
       TO DISK = 'C:\Backups\datamart_bau_itera_full.bak' 
       WITH FORMAT, INIT, COMPRESSION;
       
    2. Restore Backup (T-SQL Command):
       USE master;
       RESTORE DATABASE [datamart_bau_itera] 
       FROM DISK = 'C:\Backups\datamart_bau_itera_full.bak' 
       WITH REPLACE;
       
    3. Azure SQL Specific:
       Azure SQL Database handles automated backups automatically (PITR).
       Manual export can be done via BACPAC files in Azure Portal.
*/

USE datamart_bau_itera;
GO

PRINT '>> Creating Backup Logging Infrastructure...';
GO

-- =====================================================
-- 1. BACKUP LOGGING TABLE
-- =====================================================

IF OBJECT_ID('dw.backup_log', 'U') IS NULL
BEGIN
    CREATE TABLE dw.backup_log (
        backup_id INT IDENTITY(1,1) PRIMARY KEY,
        backup_type VARCHAR(50), -- 'Full', 'Differential', 'Log'
        backup_timestamp DATETIME DEFAULT GETDATE(),
        backup_file VARCHAR(500),
        status VARCHAR(20), -- 'Success', 'Failed'
        notes VARCHAR(MAX)
    );
    
    CREATE INDEX ix_backup_log_timestamp ON dw.backup_log(backup_timestamp);
    PRINT '>> Table dw.backup_log created.';
END
GO

-- =====================================================
-- 2. PROCEDURE: LOG BACKUP EXECUTION
-- =====================================================

CREATE OR ALTER PROCEDURE dw.usp_LogBackup
    @p_backup_type VARCHAR(50),
    @p_backup_file VARCHAR(500),
    @p_status VARCHAR(20),
    @p_notes VARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NewId INT;

    INSERT INTO dw.backup_log (backup_type, backup_file, status, notes)
    VALUES (@p_backup_type, @p_backup_file, @p_status, @p_notes);
    
    SET @NewId = SCOPE_IDENTITY();
    
    PRINT '>> Backup logged with ID: ' + CAST(@NewId AS VARCHAR(20));
    RETURN @NewId;
END;
GO

-- =====================================================
-- 3. BACKUP HISTORY VIEW
-- =====================================================

CREATE OR ALTER VIEW dw.vw_backup_history AS
SELECT 
    backup_id,
    backup_type,
    backup_timestamp,
    backup_file,
    status,
    notes
FROM dw.backup_log
-- ORDER BY clause in views is only allowed if TOP is used, 
-- but usually sorting is done in the query, not the view.
-- We'll keep standard selection here.
GO

-- =====================================================
-- SUCCESS MESSAGES
-- =====================================================

PRINT '>> 11_Backup.sql executed successfully.';
PRINT '>> Use: EXEC dw.usp_LogBackup ... to record manual backups.';
GO
