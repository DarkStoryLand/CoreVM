-- ============================================================================
-- DarkStory LAND - High-Performance Database Initialization & Restoration
-- Target: Microsoft SQL Server on Linux (Docker / Ubuntu)
-- Optimization: Read Committed Snapshot Isolation (RCSI), TempDB Multi-Files,
--               Fast Auto-Growth (64MB), and Zero-Lock Concurrency
-- Run with: sqlcmd -v GAMESRV_PASSWORD="..." -i restore_databases.sql
-- (entrypoint.sh passes GAMESRV_PASSWORD from docker/.env)
-- ============================================================================

USE [master];
GO

PRINT '>>> Initializing DarkStory LAND Database Engine with Peak Performance Tuning...';
GO

-- 1. Ensure GameSrv Server Login Exists (password from the GAMESRV_PASSWORD sqlcmd variable)
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'GameSrv')
BEGIN
    PRINT '>>> Creating server login: GameSrv';
    CREATE LOGIN [GameSrv]
    WITH PASSWORD = N'$(GAMESRV_PASSWORD)',
    DEFAULT_DATABASE = [master],
    CHECK_EXPIRATION = OFF,
    CHECK_POLICY = OFF;
END
ELSE
BEGIN
    PRINT '>>> Server login GameSrv already exists; syncing password with docker/.env.';
    ALTER LOGIN [GameSrv] WITH PASSWORD = N'$(GAMESRV_PASSWORD)';
END
GO

-- Least privilege: GameSrv only needs db_owner on the three game databases (section 5),
-- not sysadmin on the whole SQL Server instance.
IF IS_SRVROLEMEMBER(N'sysadmin', N'GameSrv') = 1
BEGIN
    PRINT '>>> Removing GameSrv from sysadmin (least privilege).';
    ALTER SERVER ROLE [sysadmin] DROP MEMBER [GameSrv];
END
GO

-- 2. Restore MHCMember (Account and Auth Database)
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'MHCMember')
BEGIN
    PRINT '>>> Restoring Database [MHCMember] from backup...';
    RESTORE DATABASE [MHCMember]
    FROM DISK = N'/var/opt/mssql/backup/MHCMEMBER.bak'
    WITH 
        MOVE N'mhcmember' TO N'/var/opt/mssql/data/MHCMember.mdf',
        MOVE N'mhcmember_log' TO N'/var/opt/mssql/data/MHCMember_log.ldf',
        REPLACE,
        STATS = 10;
    PRINT '>>> [OK] MHCMember restored successfully.';
END
ELSE
BEGIN
    PRINT '>>> [OK] Database [MHCMember] already exists. Skipping restore.';
END
GO

-- 3. Restore MHGame (Main Game World Database)
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'MHGame')
BEGIN
    PRINT '>>> Restoring Database [MHGame] from backup...';
    RESTORE DATABASE [MHGame]
    FROM DISK = N'/var/opt/mssql/backup/MHGAME.bak'
    WITH 
        MOVE N'MHGAME' TO N'/var/opt/mssql/data/MHGame.mdf',
        MOVE N'MHGAME_log' TO N'/var/opt/mssql/data/MHGame_log.ldf',
        REPLACE,
        STATS = 10;
    PRINT '>>> [OK] MHGame restored successfully.';
END
ELSE
BEGIN
    PRINT '>>> [OK] Database [MHGame] already exists. Skipping restore.';
END
GO

-- 4. Restore MHLog (Server Logging Database)
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'MHLog')
BEGIN
    PRINT '>>> Restoring Database [MHLog] from backup...';
    RESTORE DATABASE [MHLog]
    FROM DISK = N'/var/opt/mssql/backup/MHLOG.bak'
    WITH 
        MOVE N'MHLOG' TO N'/var/opt/mssql/data/MHLog.mdf',
        MOVE N'MHLOG_log' TO N'/var/opt/mssql/data/MHLog_log.ldf',
        REPLACE,
        STATS = 10;
    PRINT '>>> [OK] MHLog restored successfully.';
END
ELSE
BEGIN
    PRINT '>>> [OK] Database [MHLog] already exists. Skipping restore.';
END
GO

-- 5. Configure Users and Permissions for GameSrv in all 3 databases
USE [MHCMember];
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'GameSrv')
BEGIN
    CREATE USER [GameSrv] FOR LOGIN [GameSrv];
END
ELSE
BEGIN
    -- A restored .bak carries the user with the old server's SID; re-link it to this login
    ALTER USER [GameSrv] WITH LOGIN = [GameSrv];
END
ALTER ROLE [db_owner] ADD MEMBER [GameSrv];
GO

USE [MHGame];
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'GameSrv')
BEGIN
    CREATE USER [GameSrv] FOR LOGIN [GameSrv];
END
ELSE
BEGIN
    -- A restored .bak carries the user with the old server's SID; re-link it to this login
    ALTER USER [GameSrv] WITH LOGIN = [GameSrv];
END
ALTER ROLE [db_owner] ADD MEMBER [GameSrv];
GO

USE [MHLog];
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'GameSrv')
BEGIN
    CREATE USER [GameSrv] FOR LOGIN [GameSrv];
END
ELSE
BEGIN
    -- A restored .bak carries the user with the old server's SID; re-link it to this login
    ALTER USER [GameSrv] WITH LOGIN = [GameSrv];
END
ALTER ROLE [db_owner] ADD MEMBER [GameSrv];
GO

-- ============================================================================
-- 6. HIGH-CONCURRENCY DATABASE ENGINE OPTIMIZATION (HIGH PLAYER SCALING)
-- ============================================================================

-- A. Enable Read Committed Snapshot Isolation (RCSI)
-- Eliminates read locks completely! Readers never block Writers; Writers never block Readers.
-- Prevents deadlock error 1205 during guild wars, market trading, and boss raids.
PRINT '>>> Enabling Read Committed Snapshot Isolation (RCSI) on MHGame & MHCMember...';
IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = N'MHGame') = 0
BEGIN
    ALTER DATABASE [MHGame] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
    ALTER DATABASE [MHGame] SET ALLOW_SNAPSHOT_ISOLATION ON;
    PRINT '>>> [OK] RCSI enabled on MHGame.';
END
GO

IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = N'MHCMember') = 0
BEGIN
    ALTER DATABASE [MHCMember] SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
    ALTER DATABASE [MHCMember] SET ALLOW_SNAPSHOT_ISOLATION ON;
    PRINT '>>> [OK] RCSI enabled on MHCMember.';
END
GO

-- B. Optimize Auto-Growth to Prevent Disk Stalls (64MB chunks instead of 1MB)
PRINT '>>> Optimizing Database File Auto-Growth to 64MB...';
ALTER DATABASE [MHGame] MODIFY FILE (NAME = N'MHGAME', FILEGROWTH = 64MB);
ALTER DATABASE [MHGame] MODIFY FILE (NAME = N'MHGAME_log', FILEGROWTH = 64MB);
ALTER DATABASE [MHCMember] MODIFY FILE (NAME = N'mhcmember', FILEGROWTH = 32MB);
ALTER DATABASE [MHCMember] MODIFY FILE (NAME = N'mhcmember_log', FILEGROWTH = 32MB);
ALTER DATABASE [MHLog] MODIFY FILE (NAME = N'MHLOG', FILEGROWTH = 32MB);
ALTER DATABASE [MHLog] MODIFY FILE (NAME = N'MHLOG_log', FILEGROWTH = 32MB);
GO

-- C. Configure TempDB Multi-Data Files (Eliminates GAM/PFS allocation bottlenecks)
USE [master];
GO
PRINT '>>> Optimizing TempDB for Multi-Core Allocation...';
IF NOT EXISTS (SELECT * FROM sys.master_files WHERE database_id = 2 AND name = N'tempdev2')
BEGIN
    ALTER DATABASE [tempdb] ADD FILE (NAME = N'tempdev2', FILENAME = N'/var/opt/mssql/data/tempdb2.ndf', SIZE = 64MB, FILEGROWTH = 64MB);
    ALTER DATABASE [tempdb] ADD FILE (NAME = N'tempdev3', FILENAME = N'/var/opt/mssql/data/tempdb3.ndf', SIZE = 64MB, FILEGROWTH = 64MB);
    ALTER DATABASE [tempdb] ADD FILE (NAME = N'tempdev4', FILENAME = N'/var/opt/mssql/data/tempdb4.ndf', SIZE = 64MB, FILEGROWTH = 64MB);
    PRINT '>>> [OK] TempDB configured with 4 parallel allocation data files.';
END
GO

PRINT '>>> [OK] DarkStory LAND database optimization completed successfully!';
GO
