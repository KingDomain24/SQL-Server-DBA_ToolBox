-- Set all databases to 150 compatibility level
-- Part of the SQL Server DBA Toolbox at https://github.com/DavidSchanzer/Sql-Server-DBA-Toolbox
-- This script sets all user databases to Compatibility Level 150 (SQL Server 2019)

EXEC dbo.sp_foreachdb @command = 'ALTER DATABASE ? SET COMPATIBILITY_LEVEL = 150',
                      @user_only = 1;
