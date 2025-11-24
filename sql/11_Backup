-- =====================================================
-- 11_Backup.sql
-- Project : Data Mart Biro Akademik Umum ITERA
-- Purpose : Backup & Recovery Strategy Procedures
-- Engine  : Microsoft SQL Server 2019+
-- =====================================================

/*
    BACKUP STRATEGY:
    1. Full Backup: Weekly (Sunday @ 02:00)
    2. Differential Backup: Daily (Mon-Sat @ 02:00)
    3. Transaction Log Backup: Every 4 Hours
    
    NOTE: Ensure the backup directory exists before running these procedures.
*/

-- =====================================================
-- 1. PROCEDURE: FULL BACKUP
-- =====================================================
IF OBJECT_ID('dbo.usp_Backup_Full', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_Backup_Full;
GO

CREATE PROCEDURE dbo.usp_Backup_Full
    @BackupPath NVARCHAR(255) = N'C:\Backups\' -- Ganti path sesuai server
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FileName NVARCHAR(500);
    DECLARE @DateStamp NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
    DECLARE @DBName NVARCHAR(50) = DB_NAME();

    -- Format: DBName_FULL_YYYYMMDD_HHMMSS.bak
    SET @FileName = @BackupPath + @DBName + '_FULL_' + @DateStamp + '.bak';

    PRINT 'Starting FULL Backup for ' + @DBName + ' to ' + @FileName;

    BEGIN TRY
        BACKUP DATABASE @DBName
        TO DISK = @FileName
        WITH 
            FORMAT,             -- Overwrite header if exists
            COMPRESSION,        -- Compress to save space
            INIT,               -- Overwrite existing file
            NAME = 'Full Database Backup',
            STATS = 10;         -- Show progress every 10%
            
        PRINT 'FULL Backup completed successfully.';
        
        -- Log to Job Execution (Optional integration)
        IF OBJECT_ID('etl_log.job_execution', 'U') IS NOT NULL
            INSERT INTO etl_log.job_execution (job_name, status) VALUES ('Backup_Full', 'Success');
    END TRY
    BEGIN CATCH
        PRINT 'Error during FULL Backup: ' + ERROR_MESSAGE();
    END CATCH
END
GO

-- =====================================================
-- 2. PROCEDURE: DIFFERENTIAL BACKUP
-- =====================================================
IF OBJECT_ID('dbo.usp_Backup_Diff', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_Backup_Diff;
GO

CREATE PROCEDURE dbo.usp_Backup_Diff
    @BackupPath NVARCHAR(255) = N'C:\Backups\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FileName NVARCHAR(500);
    DECLARE @DateStamp NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
    DECLARE @DBName NVARCHAR(50) = DB_NAME();

    -- Format: DBName_DIFF_YYYYMMDD_HHMMSS.bak
    SET @FileName = @BackupPath + @DBName + '_DIFF_' + @DateStamp + '.bak';

    PRINT 'Starting DIFFERENTIAL Backup for ' + @DBName + ' to ' + @FileName;

    BEGIN TRY
        BACKUP DATABASE @DBName
        TO DISK = @FileName
        WITH 
            DIFFERENTIAL,       -- Capture only changes since last Full Backup
            COMPRESSION,
            INIT,
            NAME = 'Differential Database Backup',
            STATS = 10;
            
        PRINT 'DIFFERENTIAL Backup completed successfully.';
    END TRY
    BEGIN CATCH
        PRINT 'Error during DIFFERENTIAL Backup: ' + ERROR_MESSAGE();
    END CATCH
END
GO

-- =====================================================
-- 3. PROCEDURE: TRANSACTION LOG BACKUP
-- =====================================================
IF OBJECT_ID('dbo.usp_Backup_Log', 'P') IS NOT NULL DROP PROCEDURE dbo.usp_Backup_Log;
GO

CREATE PROCEDURE dbo.usp_Backup_Log
    @BackupPath NVARCHAR(255) = N'C:\Backups\'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FileName NVARCHAR(500);
    DECLARE @DateStamp NVARCHAR(20) = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
    DECLARE @DBName NVARCHAR(50) = DB_NAME();

    -- Format: DBName_LOG_YYYYMMDD_HHMMSS.trn
    SET @FileName = @BackupPath + @DBName + '_LOG_' + @DateStamp + '.trn';

    PRINT 'Starting TRANSACTION LOG Backup for ' + @DBName + ' to ' + @FileName;

    BEGIN TRY
        -- Check Recovery Model first
        IF (SELECT recovery_model_desc FROM sys.databases WHERE name = @DBName) = 'SIMPLE'
        BEGIN
            PRINT 'WARNING: Database is in SIMPLE recovery model. Log backup skipped.';
            RETURN;
        END

        BACKUP LOG @DBName
        TO DISK = @FileName
        WITH 
            COMPRESSION,
            NOINIT,             -- Append to existing media set if needed
            NAME = 'Transaction Log Backup',
            STATS = 10;
            
        PRINT 'LOG Backup completed successfully.';
    END TRY
    BEGIN CATCH
        PRINT 'Error during LOG Backup: ' + ERROR_MESSAGE();
    END CATCH
END
GO

-- =====================================================
-- SUCCESS NOTICE
-- =====================================================
PRINT '======================================================';
PRINT '11_Backup.sql executed successfully';
PRINT '======================================================';
PRINT 'Backup procedures created:';
PRINT '1. dbo.usp_Backup_Full (Weekly)';
PRINT '2. dbo.usp_Backup_Diff (Daily)';
PRINT '3. dbo.usp_Backup_Log  (Hourly)';
PRINT '';
PRINT 'To execute manually: EXEC dbo.usp_Backup_Full @BackupPath = ''C:\YourPath\'';';
PRINT '======================================================';

-- ====================== END OF FILE ======================
