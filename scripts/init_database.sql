/*
===============================================================================
Purpose     : Initializes the DataWarehouse database environment.

Description :
- Drops the existing DataWarehouse database if it exists
- Recreates the database from scratch
- Sets up Bronze, Silver, and Gold schemas for data warehousing

Notes       :
- Uses SINGLE_USER mode with ROLLBACK IMMEDIATE for safe reset
- Script is safe to rerun and intended for local development/testing

===============================================================================
*/


-- Initializing
USE master;
GO

-- Dropping DB if it exists
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO


--CREATING DATABASE DataWarehouse
CREATE DATABASE DataWarehouse;
GO
USE DataWarehouse;
GO


--CREATE SCHEMAS
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC ('CREATE SCHEMA bronze');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC ('CREATE SCHEMA silver');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC ('CREATE SCHEMA gold');
GO



