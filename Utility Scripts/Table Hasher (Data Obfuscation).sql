/*
Author: Aviad Deri
Date: 2022-08-21
Description:

This script implements a solution to hash (obfuscate) sensitive textual data.

The procedure "RefreshPreProdTables" finds all textual columns in all tables in all or specified databases
and obfuscates their contents using 256-bit SHA2 hashing.

If you want to exclude specific tables from this process, they must be inserted into the table RefreshPreProdTablesExclude.

The table RefreshPreProdTablesLog will hold an audit log of all tables being obfuscated.
*/
USE [Maintenance]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RefreshPreProdTablesExclude](
	[TABLE_CATALOG] [sysname] NOT NULL,
	[TABLE_NAME] [sysname] NOT NULL,
	[COLUMN_NAME] [sysname] NOT NULL
) 
GO
CREATE TABLE [dbo].[RefreshPreProdTablesLog](
	[LogId] [bigint] IDENTITY(1,1) NOT NULL,
	[LogDatabase] [sysname] NOT NULL,
	[LogCommand] [nvarchar](max) NOT NULL,
	[LogStart] [datetime] NULL,
	[LogEnd] [datetime] NULL,
	[LogError] [nvarchar](500) NULL,
PRIMARY KEY CLUSTERED ([LogId] ASC))
GO
CREATE PROCEDURE [dbo].[RefreshPreProdTables](@PopulateList BIT, @ExecHash BIT,@DBList SYSNAME='ALL')
AS
BEGIN
	IF (@PopulateList=1)
	BEGIN
		--Populate tables list
		DECLARE @dbname SYSNAME 
		DECLARE @str NVARCHAR(MAX)
		DECLARE DBCursor CURSOR
		READ_ONLY FORWARD_ONLY STATIC LOCAL
		FOR 
			SELECT name 
			FROM sys.databases 
			WHERE name NOT IN ('master','model','msdb','tempdb','maintenance')
			AND HAS_DBACCESS([name]) = 1
			AND @DBList='ALL'
			
			UNION ALL

			SELECT name 
			FROM sys.databases 
			WHERE name = @DBList
			AND @DBList<>'ALL'

		OPEN DBCursor
		FETCH NEXT FROM DBCursor INTO @dbname  
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			SET @str =
				'INSERT INTO dbo.RefreshPreProdTablesLog
				 SELECT '''+@dbname+''',
					''UPDATE '+QUOTENAME(@dbname)+'.''+QUOTENAME(TABLE_SCHEMA)+''.''+QUOTENAME(TABLE_NAME)+ '' SET ''+
						STRING_AGG(CONCAT_WS(''='',QUOTENAME(COLUMN_NAME),''CAST(HASHBYTES(''''SHA2_256'''',''+QUOTENAME(COLUMN_NAME)+'') AS ''+DATA_TYPE)+''(''+
						CASE CHARACTER_MAXIMUM_LENGTH
							WHEN -1 THEN ''MAX''
							ELSE CAST(CHARACTER_MAXIMUM_LENGTH as NVARCHAR(5))
						END
						+''))'','',''),NULL,NULL,NULL
				 FROM  '+QUOTENAME(@dbname)+'.INFORMATION_SCHEMA.COLUMNS c INNER JOIN '+QUOTENAME(@dbname)+'.sys.tables t ON c.TABLE_NAME=t.name  
				 WHERE 
					DATA_TYPE IN (''char'',''nchar'',''ntext'',''nvarchar'',''text'',''varchar'') 
					AND (TABLE_CATALOG+''-''+TABLE_NAME+''-''+COLUMN_NAME) NOT IN (SELECT TABLE_CATALOG+''-''+TABLE_NAME+''-''+COLUMN_NAME COLLATE DATABASE_DEFAULT FROM dbo.RefreshPreProdTablesExclude)
				 GROUP BY TABLE_SCHEMA,TABLE_NAME'

			--print @str
			exec (@str)
			FETCH NEXT FROM DBCursor INTO @dbname
		END
		CLOSE DBCursor 
		DEALLOCATE DBCursor 
	END
	IF (@ExecHash=1)
	BEGIN
		--Run over the tables
		DECLARE 
			@LogID BIGINT, 
			@LogCommand NVARCHAR(MAX)
		DECLARE CommandCursor CURSOR
		READ_ONLY FORWARD_ONLY STATIC LOCAL
		FOR
			SELECT LogID, LogCommand 
			FROM dbo.RefreshPreProdTablesLog
			WHERE LogEnd IS NULL
				AND LogDatabase=@DBList
		OPEN CommandCursor
		FETCH NEXT FROM CommandCursor INTO @LogID, @LogCommand
		WHILE @@FETCH_STATUS = 0 
		BEGIN
			UPDATE dbo.RefreshPreProdTablesLog SET LogStart=GETDATE() WHERE LogID=@LogID
			PRINT @LogCommand
			BEGIN TRY
				EXEC (@LogCommand)
			END TRY
			BEGIN CATCH
				UPDATE dbo.RefreshPreProdTablesLog SET LogError=ERROR_MESSAGE() WHERE LogID=@LogID
			END CATCH
			UPDATE dbo.RefreshPreProdTablesLog SET LogEnd=GETDATE() WHERE LogID=@LogID
			FETCH NEXT FROM CommandCursor INTO @LogID, @LogCommand
		END
		CLOSE CommandCursor 
		DEALLOCATE CommandCursor 
	END
END
