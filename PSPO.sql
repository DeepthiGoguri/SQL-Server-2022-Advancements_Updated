/*Enable Query store on database throught T-sql */
ALTER DATABASE [StackOverflow2013]
SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE);

/* set query store options 
Source code: https://docs.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver15
*/
ALTER DATABASE [StackOverflow2013]

SET QUERY_STORE(OPERATION_MODE = READ_WRITE, 
CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), 
DATA_FLUSH_INTERVAL_SECONDS = 3000, MAX_STORAGE_SIZE_MB = 500, 
INTERVAL_LENGTH_MINUTES = 15, SIZE_BASED_CLEANUP_MODE = AUTO,
QUERY_CAPTURE_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, 
WAIT_STATS_CAPTURE_MODE = ON);

ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON 

USE StackOverflow2013;
GO
ALTER DATABASE CURRENT SET COMPATIBILITY_LEVEL = 160;
GO


SET STATISTICS IO, TIME ON;
USE StackOverflow2013
GO
IF EXISTS (
		SELECT *
		FROM sys.objects
		WHERE type = 'P'
			AND name = 'Reputationinfo'
		)
	DROP PROCEDURE dbo.Reputationinfo
GO
CREATE OR ALTER PROCEDURE dbo.Reputationinfo
  @Reputation int
AS
	SELECT *
	FROM dbo.Users
	WHERE Reputation=@Reputation
	ORDER BY DisplayName;
GO



/*
This query text was retrieved from showplan XML, and may be truncated.
*/

--SELECT *
--	FROM dbo.Users
--	WHERE Reputation=@Reputation
--	ORDER BY DisplayName option 
--	(PLAN PER VALUE(ObjectID = 917578307, QueryVariantID = 2, 
--	predicate_range([StackOverflow2013].[dbo].[Users].[Reputation] = @Reputation, 
--	100.0, 1000000.0)))

USE [StackOverflow2013]
GO
SELECT sh.* 
FROM sys.stats AS s
CROSS APPLY sys.dm_db_stats_histogram(s.object_id, s.stats_id) AS sh
WHERE name = 'Reputation' 
AND s.object_id =OBJECT_ID('dbo.Users')
ORDER BY equal_rows DESC
GO

EXEC dbo.Reputationinfo @Reputation =5714
GO 3

EXEC dbo.Reputationinfo @Reputation =1
GO 2

EXEC dbo.Reputationinfo @Reputation =13
GO 3



SELECT 
usecounts, plan_handle, text, objtype
FROM sys.dm_exec_cached_plans
CROSS APPLY sys.dm_exec_sql_text (plan_handle)
WHERE text LIKE '%ORDER BY DisplayName%'
and objtype = 'Prepared'
GO

/*Query reference:
https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-stats-transact-sql?view=sql-server-ver16
*/

SELECT
    qs.execution_count AS "Execution Count",
    SUBSTRING(qt.text,qs.statement_start_offset/2 +1, 
                 (CASE WHEN qs.statement_end_offset = -1 
                       THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
                       ELSE qs.statement_end_offset END -
                            qs.statement_start_offset
                 )/2
             ) AS "Query Text", 
 qs.query_hash, 
   qs.query_plan_hash,
   qs.plan_handle,
   qs.sql_handle,
   qp.query_plan,
   qt.text
FROM sys.dm_exec_query_stats AS qs 
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt 
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qt.text like '%ORDER BY DisplayName%'
ORDER BY 
     qs.execution_count DESC


SELECT qs.query_plan_hash,
qs.query_hash,
qs.execution_count,
qs.max_elapsed_time,
qs.max_rows,
qs.last_dop,
qs.last_grant_kb,
qs.last_worker_time,
qp.query_plan
FROM sys.dm_exec_query_stats AS qs 
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS qt 
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qt.text like '%ORDER BY DisplayName%'
ORDER BY 
     qs.execution_count DESC


/*clear the Query store */
ALTER DATABASE [StackOverflow2013]
SET QUERY_STORE CLEAR;

/* Clean the procedure cache */
USE [StackOverflow2013]
GO
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE


/*view the variant info 
Source: https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-query-variant?view=sql-server-ver16
*/

SELECT 
	qspl.plan_type_desc AS query_plan_type, 
	qspl.plan_id as query_store_planid, 
	qspl.query_id as query_store_queryid, 
	qsqv.query_variant_query_id as query_store_variant_queryid,
	qsqv.parent_query_id as query_store_parent_queryid,
	qsqv.dispatcher_plan_id as query_store_dispatcher_planid,
	OBJECT_NAME(qsq.object_id) as module_name, 
	qsq.query_hash, 
	qsqtxt.query_sql_text,
	convert(xml,qspl.query_plan)as show_plan_xml,
	qsrs.last_execution_time as last_execution_time,
	qsrs.count_executions AS number_of_executions,
	qsq.count_compiles AS number_of_compiles 
FROM sys.query_store_runtime_stats AS qsrs
	JOIN sys.query_store_plan AS qspl 
		ON qsrs.plan_id = qspl.plan_id 
	JOIN sys.query_store_query_variant qsqv 
		ON qspl.query_id = qsqv.query_variant_query_id
	JOIN sys.query_store_query as qsq
		ON qsqv.parent_query_id = qsq.query_id
	JOIN sys.query_store_query_text AS qsqtxt  
		ON qsq.query_text_id = qsqtxt .query_text_id  
ORDER BY qspl.query_id, qsrs.last_execution_time;
GO

/*view the dispatcher and variant info */
SELECT
	qspl.plan_type_desc AS query_plan_type, 
	qspl.plan_id as query_store_planid, 
	qspl.query_id as query_store_queryid, 
	qsqv.query_variant_query_id as query_store_variant_queryid,
	qsqv.parent_query_id as query_store_parent_queryid, 
	qsqv.dispatcher_plan_id as query_store_dispatcher_planid,
	qsq.query_hash, 
	qsqtxt.query_sql_text, 
	CONVERT(xml,qspl.query_plan)as show_plan_xml,
	qsq.count_compiles AS number_of_compiles,
	qsrs.last_execution_time as last_execution_time,
	qsrs.count_executions AS number_of_executions
FROM sys.query_store_query qsq
	LEFT JOIN sys.query_store_query_text qsqtxt
		ON qsq.query_text_id = qsqtxt.query_text_id
	LEFT JOIN sys.query_store_plan qspl
		ON qsq.query_id = qspl.query_id
	LEFT JOIN sys.query_store_query_variant qsqv
		ON qsq.query_id = qsqv.query_variant_query_id
	LEFT JOIN sys.query_store_runtime_stats qsrs
		ON qspl.plan_id = qsrs.plan_id
	LEFT JOIN sys.query_store_runtime_stats_interval qsrsi
		ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
WHERE qspl.plan_type = 1 or qspl.plan_type = 2
ORDER BY qspl.query_id, qsrs.last_execution_time;
GO
