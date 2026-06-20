--=======PART E: TRIGGERS, LOGGING & EMAIL ALERTS========

----CREATING AUDIT TABLE
CREATE TABLE AuditTable (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(100) NOT NULL,
    ActionType NVARCHAR(10) NOT NULL,
    UserName NVARCHAR(100) NOT NULL,
    ActionDateTime DATETIME NOT NULL,
    Description NVARCHAR(500) NOT NULL
)
GO

-----------CUSTOMER TRIGGERS---------

-- INSERT TRIGGER
CREATE TRIGGER Insert_Trigger
ON Sales.Customer
AFTER INSERT
AS 
BEGIN
    INSERT INTO AuditTable (TableName, ActionType, UserName, ActionDateTime, Description)
    SELECT
        'Sales.Customer',
        'INSERT',
        SYSTEM_USER,
        GETDATE(),
        'The record that was inserted by ' + SYSTEM_USER + ' belong to customer with CustomerID: ' + CAST(inserted.CustomerID AS VARCHAR)
    FROM inserted
END
GO

-- UPDATE TRIGGER
CREATE TRIGGER Update_Trigger
ON Sales.Customer
AFTER UPDATE
AS 
BEGIN
    INSERT INTO AuditTable (TableName, ActionType, UserName, ActionDateTime, Description)
    SELECT
        'Sales.Customer',
        'UPDATE',
        SYSTEM_USER,
        GETDATE(),
        'The record that was updated by ' + SYSTEM_USER + ' belong to customer with CustomerID: ' + CAST(inserted.CustomerID AS VARCHAR)
    FROM inserted
END
GO

-- DELETE TRIGGER
CREATE TRIGGER Delete_Trigger
ON Sales.Customer
AFTER DELETE
AS 
BEGIN
    INSERT INTO AuditTable (TableName, ActionType, UserName, ActionDateTime, Description)
    SELECT
        'Sales.Customer',
        'DELETE',
        SYSTEM_USER,
        GETDATE(),
        'The record that was deleted by ' + SYSTEM_USER + ' belong to customer with CustomerID: ' + CAST(deleted.CustomerID AS VARCHAR)
    FROM deleted
END
GO

------PRODUCT TRIGGERS---------

-- INSERT TRIGGER
CREATE TRIGGER Insert_Product_Trigger
ON Production.Product
AFTER INSERT
AS 
BEGIN
    INSERT INTO AuditTable (TableName, ActionType, UserName, ActionDateTime, Description)
    SELECT
        'Production.Product',
        'INSERT',
        SYSTEM_USER,
        GETDATE(),
        'The record that was inserted by ' + SYSTEM_USER + ' belong to product with ProductID: ' + CAST(inserted.ProductID AS VARCHAR)
    FROM inserted
END
GO

-- UPDATE TRIGGER
CREATE TRIGGER Update_Product_Trigger
ON Production.Product
AFTER UPDATE
AS 
BEGIN
    INSERT INTO AuditTable (TableName, ActionType, UserName, ActionDateTime, Description)
    SELECT
        'Production.Product',
        'UPDATE',
        SYSTEM_USER,
        GETDATE(),
        'The record that was updated by ' + SYSTEM_USER + ' belong to product with ProductID: ' + CAST(inserted.ProductID AS VARCHAR)
    FROM inserted
END
GO

-- DELETE TRIGGER
CREATE TRIGGER Delete_Product_Trigger
ON Production.Product
AFTER DELETE
AS 
BEGIN
    INSERT INTO AuditTable (TableName, ActionType, UserName, ActionDateTime, Description)
    SELECT
        'Production.Product',
        'DELETE',
        SYSTEM_USER,
        GETDATE(),
        'The record that was deleted by ' + SYSTEM_USER + ' belong to product with ProductID: ' + CAST(deleted.ProductID AS VARCHAR)
    FROM deleted
END
GO

------------TESTING TRIGGERS---------
UPDATE Sales.Customer SET ModifiedDate = GETDATE() WHERE CustomerID = 56
UPDATE Production.Product SET ListPrice = 78 WHERE ProductID = 1
SELECT * FROM AuditTable


--------EMAIL ALERTS------

-- Step 1: Enable Database Mail XP
EXEC sp_configure 'show advanced options', 1; RECONFIGURE
EXEC sp_configure 'Database Mail XPs', 1;    RECONFIGURE

-- Step 2: Create a mail account
EXEC msdb.dbo.sysmail_add_account_sp
    @account_name    = 'SQLAlerts',
    @email_address   = 'thapelomrk25@gmail.com',
    @display_name    = 'SQL Server Alerts',
    @mailserver_name = 'smtp.gmail.com',
    @port            = 587,
    @enable_ssl      = 1,
    @username        = 'thapelomrk25@gmail.com',
    @password        = 'fenn jrfv tqhh dlfz'

-- Step 3: Create a profile and link the account
EXEC msdb.dbo.sysmail_add_profile_sp
    @profile_name = 'DBAAlertProfile';

EXEC msdb.dbo.sysmail_add_profileaccount_sp
    @profile_name    = 'DBAAlertProfile',
    @account_name    = 'SQLAlerts',
    @sequence_number = 1

-- Testing the email
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'DBAAlertProfile',
    @recipients   = 'thapelomrk25@gmail.com',
    @subject      = 'Test alert',
    @body         = 'Database Mail is working.'


-- Alert 1: Email When a Product Price Changes
CREATE TRIGGER trg_Product_PriceChange_Alert
ON Production.Product
AFTER UPDATE
AS
BEGIN
    IF UPDATE(ListPrice)
    BEGIN
        DECLARE @ProductID  NVARCHAR(20)
        DECLARE @OldPrice   MONEY
        DECLARE @NewPrice   MONEY
        DECLARE @Body1      NVARCHAR(MAX)

        SELECT TOP 1
            @ProductID = CAST(i.ProductID AS NVARCHAR(20)),
            @OldPrice  = d.ListPrice,
            @NewPrice  = i.ListPrice
        FROM inserted i
        JOIN deleted d ON i.ProductID = d.ProductID

        SET @Body1 = 'Product price was changed by ' + SYSTEM_USER
                   + ' | ProductID: ' + @ProductID
                   + ' | Old Price: ' + CAST(@OldPrice AS NVARCHAR(20))
                   + ' | New Price: ' + CAST(@NewPrice AS NVARCHAR(20))

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'DBAAlertProfile',
            @recipients   = 'thapelomrk25@gmail.com',
            @subject      = 'ALERT: Product Price Changed',
            @body         = @Body1
    END
END
GO

-- Alert 2: Email When a Customer Record is Deleted
CREATE TRIGGER trg_Customer_Delete_Alert
ON Sales.Customer
AFTER DELETE
AS
BEGIN
    DECLARE @CustomerID NVARCHAR(20)
    DECLARE @Body2      NVARCHAR(MAX)

    SELECT TOP 1
        @CustomerID = CAST(CustomerID AS NVARCHAR(20))
    FROM deleted

    SET @Body2 = 'A customer record was DELETED by ' + SYSTEM_USER
               + ' | CustomerID: ' + @CustomerID
               
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'DBAAlertProfile',
        @recipients   = 'thapelomrk25@gmail.com',
        @subject      = 'ALERT: Customer Record Deleted',
        @body         = @Body2
END
GO

-- Alert 2b: Email When a Product Record is Deleted
CREATE TRIGGER trg_Product_Delete_Alert
ON Production.Product
AFTER DELETE
AS
BEGIN
    DECLARE @ProductID NVARCHAR(20)
    DECLARE @Body3     NVARCHAR(MAX)

    SELECT TOP 1
        @ProductID = CAST(ProductID AS NVARCHAR(20))
    FROM deleted

    SET @Body3 = 'A product record was DELETED by ' + SYSTEM_USER
               + ' | ProductID: ' + @ProductID

    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'DBAAlertProfile',
        @recipients   = 'thapelomrk25@gmail.com',
        @subject      = 'ALERT: Product Record Deleted',
        @body         = @Body3
END
GO

-- Alert 3: Email When Critical Customer Data is Updated
CREATE TRIGGER trg_Customer_CriticalUpdate_Alert
ON Sales.Customer
AFTER UPDATE
AS
BEGIN
    IF UPDATE(TerritoryID)
    BEGIN
        DECLARE @CustID NVARCHAR(20)
        DECLARE @Body4  NVARCHAR(MAX)

        SELECT TOP 1
            @CustID = CAST(CustomerID AS NVARCHAR(20))
        FROM inserted

        SET @Body4 = 'Critical customer data was modified by ' + SYSTEM_USER
                   + ' | CustomerID: ' + @CustID
                   + ' | Fields changed: TerritoryID'

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'DBAAlertProfile',
            @recipients   = 'thapelomrk25@gmail.com',
            @subject      = 'ALERT: Critical Customer Data Updated',
            @body         = @Body4
    END
END
GO

-- Test email alerts
UPDATE Production.Product SET ListPrice = 150.00 WHERE ProductID = 1
DELETE FROM Sales.Customer WHERE CustomerID = 1
UPDATE Sales.Customer SET TerritoryID = 10 WHERE CustomerID = 2


-- CONDITIONAL ALERT: Send email only when price changes by more than 10%
CREATE TRIGGER PriceAlert
ON Production.Product
AFTER UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1 FROM deleted d
        JOIN inserted i ON d.ProductID = i.ProductID
        WHERE ABS(i.ListPrice - d.ListPrice) > (d.ListPrice * 0.10)
    )
    BEGIN
        DECLARE @prodid NVARCHAR(20)
        DECLARE @Body5  NVARCHAR(MAX)

        SELECT TOP 1
            @prodid = CAST(ProductID AS NVARCHAR(20))
        FROM inserted

        SET @Body5 = 'Price was changed by over 10% by: ' + SYSTEM_USER
                   + ' | ProductID: ' + @prodid

        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = 'DBAAlertProfile',
            @recipients   = 'thapelomrk25@gmail.com',
            @subject      = 'Price change alert',
            @body         = @Body5
    END
END
GO

-- Test PriceAlert trigger
UPDATE Production.Product SET ListPrice = 20 WHERE ProductID = 719


-- CONDITIONAL ALERT: Send email when sensitive person data is modified
CREATE TRIGGER SensitiveData
ON Person.Person
AFTER UPDATE
AS
BEGIN
    DECLARE @businessId NVARCHAR(20)
    DECLARE @Body6      NVARCHAR(MAX)

    SELECT TOP 1
        @businessId = CAST(BusinessEntityID AS NVARCHAR(20))
    FROM inserted

    SET @Body6 = 'Sensitive data was modified by: ' + SYSTEM_USER
               + ' | BusinessEntityID: ' + @businessId

    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'DBAAlertProfile',
        @recipients   = 'thapelomrk25@gmail.com',
        @subject      = 'Sensitive data Alert',
        @body         = @Body6
END
GO

-- Test SensitiveData trigger
UPDATE Person.Person SET FirstName = 'masana' WHERE BusinessEntityID = 2
