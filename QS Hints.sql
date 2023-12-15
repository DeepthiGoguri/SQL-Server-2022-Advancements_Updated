/********* Query Hints in Query Store *************/

--Example of the code using OPTION 
USE [Adventureworks]
GO
SELECT * FROM Person.Address
WHERE City = 'SEATTLE' AND PostalCode = 98104
OPTION (RECOMPILE, USE HINT ('QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_110'));
GO

/* Creating the Stored procedure */
IF EXISTS (
		SELECT *
		FROM sys.objects
		WHERE type = 'P'
			AND name = 'Salesinformation'
		)
	DROP PROCEDURE dbo.Salesinformation
GO

CREATE PROCEDURE dbo.Salesinformation @productID [int]
AS
BEGIN
	SELECT [SalesOrderID]
		,[ProductID]
		,[OrderQty]
	FROM [Sales].[SalesOrderDetailEnlarged]
	WHERE [ProductID] = @productID;
END;

/* 
SELECT [ProductID], COUNT(ProductID)
FROM [Sales].[SalesOrderDetailEnlarged]
GROUP BY [ProductID]
HAVING COUNT(ProductID)>1
order by COUNT(ProductID) desc
*/
/* Clearing the Query store and Cache */
ALTER DATABASE [AdventureWorks]

SET QUERY_STORE CLEAR;

/* Clean the procedure cache */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE

/* Executing the sp resulting in many rows with this parameter */
EXEC dbo.Salesinformation 870

/* This parameter will result in only couple of rows, it reuses the same execution plan */
EXEC dbo.Salesinformation 942

/* Find the query ID associated with the query
Source: https://docs.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints?view=azuresqldb-current
*/
SELECT query_sql_text
	,q.query_id
FROM sys.query_store_query_text qt
INNER JOIN sys.query_store_query q ON qt.query_text_id = q.query_text_id
WHERE query_sql_text LIKE N'%@productID int%'
	AND query_sql_text NOT LIKE N'%query_store%';
GO

/* Set the Query hint by using the sp sp_query_store_set_hints
Source: https://docs.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints?view=azuresqldb-current
*/
EXEC sp_query_store_set_hints @query_id = 1
	,@value = N'OPTION(RECOMPILE)';
GO

/* Execute the sp again with two parameters */
EXEC dbo.Salesinformation 870

EXEC dbo.Salesinformation 942

/* Check for the Query hints that are enabled 
Source: https://docs.microsoft.com/en-us/sql/relational-databases/performance/query-store-hints?view=azuresqldb-current*/
SELECT query_hint_id
	,query_id
	,query_hint_text
	,last_query_hint_failure_reason
	,last_query_hint_failure_reason_desc
	,query_hint_failure_count
	,source
	,source_desc
FROM sys.query_store_query_hints;
GO

/* MAXDOP HINT */
EXEC sp_query_store_set_hints @query_id = 1
	,@value = N'OPTION(MAXDOP 1)';
GO

/* Clean the procedure cache */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE

EXEC dbo.Salesinformation 870

EXEC dbo.Salesinformation 942

/* Multiple query hints */
EXEC sp_query_store_set_hints @query_id = 1
	,@value = N'OPTION(RECOMPILE,MAXDOP 1)';
GO

/* Clean the procedure cache */
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE

EXEC dbo.Salesinformation 870

EXEC dbo.Salesinformation 942

/* Remove the Query hints from Query Store */
EXEC sp_query_store_clear_hints @query_id = 1;
GO

/* Recheck for the Query hints to make sure Query hints are diabled */
SELECT query_hint_id
	,query_id
	,query_hint_text
	,last_query_hint_failure_reason
	,last_query_hint_failure_reason_desc
	,query_hint_failure_count
	,source
	,source_desc
FROM sys.query_store_query_hints;
GO

/* For supported Query hints
https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver16
*/