-- Set all databases to 130 compatibility level
-- Part of the SQL Server DBA Toolbox at https://github.com/DavidSchanzer/Sql-Server-DBA-Toolbox
-- This script sets all user databases to Compatibility Level 130 (SQL Server 2016)

EXEC dbo.sp_foreachdb @command = 'ALTER DATABASE ? SET COMPATIBILITY_LEVEL = 130',
                      @user_only = 1;
