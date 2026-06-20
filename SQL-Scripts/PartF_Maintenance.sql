--=======PART F: MAINTENANCE & SERVER HEALTH========

--- INDEX MAINTENANCE PROCEDURE
CREATE PROCEDURE dbo.IndexMaintenance 
    @FragmentationThresholdLow  INT = 5,
    @FragmentationThresholdHigh INT = 30,
    @MaxRuntimeMinutes          INT = 120
AS 
BEGIN
    DECLARE @SchemaName  NVARCHAR(128)
    DECLARE @TableName   NVARCHAR(128)
    DECLARE @IndexName   NVARCHAR(128)
    DECLARE @FragPercent DECIMAL(5,2)
    DECLARE @Command     NVARCHAR(4000)

    DECLARE index_cursor CURSOR FAST_FORWARD READ_ONLY FOR
    SELECT 
        OBJECT_SCHEMA_NAME(ips.object_id) AS SchemaName,
        OBJECT_NAME(ips.object_id)        AS TableName,
        i.name                            AS IndexName,
        ips.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.avg_fragmentation_in_percent > @FragmentationThresholdLow
        AND ips.page_count > 1000
        AND i.name IS NOT NULL

    OPEN index_cursor
    FETCH NEXT FROM index_cursor INTO @SchemaName, @TableName, @IndexName, @FragPercent

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- REBUILD for high fragmentation (>30%)
        IF @FragPercent >= @FragmentationThresholdHigh
        BEGIN
            SET @Command = N'ALTER INDEX ' + QUOTENAME(@IndexName) + 
                          N' ON ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + 
                          N' REBUILD WITH (ONLINE = ON)'
        END
        -- REORGANIZE for moderate fragmentation (5-30%)
        ELSE IF @FragPercent >= @FragmentationThresholdLow
        BEGIN
            SET @Command = N'ALTER INDEX ' + QUOTENAME(@IndexName) + 
                          N' ON ' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + 
                          N' REORGANIZE'
        END

        BEGIN TRY
            EXEC sp_executesql @Command
        END TRY
        BEGIN CATCH
            PRINT ERROR_MESSAGE()
        END CATCH
        
        FETCH NEXT FROM index_cursor INTO @SchemaName, @TableName, @IndexName, @FragPercent
    END
    
    CLOSE index_cursor
    DEALLOCATE index_cursor
END
GO

-- Run Index Maintenance
EXEC dbo.IndexMaintenance

-- DATABASE INTEGRITY CHECK
DBCC CHECKDB('AdventureWorks2022')
WITH NO_INFOMSGS, ALL_ERRORMSGS
