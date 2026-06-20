--=======PART C: PERFORMANCE OPTIMIZATION========

---INDEXING

SET STATISTICS TIME ON

-- CREATING INDEX
CREATE INDEX IN_ORDERQTY
ON Sales.SalesOrderDetail(OrderQty)

-- QUERY USING THE INDEX
SELECT * FROM Sales.SalesOrderDetail
WHERE OrderQty = 1


---QUERY OPTIMIZATION

-- BEFORE: inefficient (function on column prevents index use)
SET STATISTICS TIME ON
SELECT * FROM Sales.SalesOrderHeader
WHERE YEAR(OrderDate) = 2014

-- AFTER: optimized (range filter allows index use)
SELECT * FROM Sales.SalesOrderHeader
WHERE OrderDate >= '2014-01-01'
AND OrderDate < '2015-01-01'


--======MONITORING PROCEDURES============

-- PROCEDURE: DETECT LONG RUNNING QUERIES
CREATE PROCEDURE LongRunningQueries
AS
BEGIN
    SELECT
        session_id,
        status,
        start_time,
        command,
        total_elapsed_time / 1000 AS elapsed_seconds
    FROM sys.dm_exec_requests 
    WHERE total_elapsed_time > 5000
END
GO

EXEC LongRunningQueries

-- PROCEDURE: CHECK DATABASE SIZE
CREATE PROCEDURE DataBase_Size
AS
BEGIN
    SELECT
        DB_NAME(database_id) AS DatabaseName,
        name AS FileName,
        type_desc AS FileType,
        (size * 8 / 1024) AS SizeMB
    FROM sys.master_files
    WHERE database_id = DB_ID('AdventureWorks2022')
END
GO

EXEC DataBase_Size

-- PROCEDURE: MONITOR INDEX FRAGMENTATION
CREATE PROCEDURE IndexFragmentation
AS
BEGIN
    SELECT 
        dbschemmas.[name] AS SchemaName,
        dbtables.[name] AS TableName,
        dbindexes.[name] AS IndexName,
        indexstats.avg_fragmentation_in_percent
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') indexstats
    JOIN sys.tables dbtables ON dbtables.[object_id] = indexstats.[object_id]
    JOIN sys.schemas dbschemmas ON dbtables.[schema_id] = dbschemmas.[schema_id]
    JOIN sys.indexes dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
        AND indexstats.index_id = dbindexes.index_id
    WHERE indexstats.avg_fragmentation_in_percent > 10
    ORDER BY indexstats.avg_fragmentation_in_percent DESC
END
GO

EXEC IndexFragmentation
