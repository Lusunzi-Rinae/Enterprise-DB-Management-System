--=======PART A: STORED PROCEDURES========

----PROCEDURE FOR ADDING NEW CUSTOMER
CREATE PROCEDURE AddNewCustomer
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @PhoneNumber NVARCHAR(10),
    @Email NVARCHAR(100)
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION

        IF @FirstName IS NULL OR @LastName IS NULL
        BEGIN
            RAISERROR('First name and last name are required.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END
        IF @Email IS NULL 
        BEGIN
            RAISERROR('Email is required.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END
         
         IF @PhoneNumber IS NULL
        BEGIN
            RAISERROR('Phone number is required.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END

        INSERT INTO Person.BusinessEntity DEFAULT VALUES

       DECLARE @BusinessEntityID INT = SCOPE_IDENTITY()


        INSERT INTO Person.Person (BusinessEntityID, FirstName, LastName,PersonType)
        VALUES (@BusinessEntityID , @FirstName, @LastName,'IN')
        
        INSERT INTO Person.EmailAddress (BusinessEntityID, EmailAddress)
        VALUES (@BusinessEntityID, @Email)

        INSERT INTO Person.PersonPhone(BusinessEntityID, PhoneNumber,PhoneNumberTypeID)
        VALUES(@BusinessEntityID,@PhoneNumber,1)

        INSERT INTO Sales.Customer (PersonID)
        VALUES (@BusinessEntityID)

        COMMIT TRANSACTION
    END TRY

    BEGIN CATCH
        ROLLBACK TRANSACTION
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

-- PROCEDURE FOR UPDATING PRODUCT PRICE
CREATE PROCEDURE UpdateProductPrice
    @ProductID INT,
    @NewPrice MONEY
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION

        IF @NewPrice <= 0
        BEGIN
            RAISERROR('Price must be greater than zero.', 16, 1)
            ROLLBACK TRANSACTION
            RETURN
        END

        UPDATE Production.Product
        SET ListPrice = @NewPrice
        WHERE ProductID = @ProductID

        COMMIT TRANSACTION
    END TRY

    BEGIN CATCH
        ROLLBACK TRANSACTION
        PRINT ERROR_MESSAGE()
    END CATCH
END
GO

-- CREATE TABLE FOR ARCHIVED CUSTOMERS
CREATE TABLE Sales.CustomerArchive
(
    ArchiveID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    TerritoryID INT NULL,
    LastOrderDate DATE NULL,
    ArchivedDate DATETIME NOT NULL
)
GO

-- PROCEDURE FOR ARCHIVING AND DELETING INACTIVE CUSTOMERS
CREATE PROCEDURE usp_ArchiveInactiveCustomers
    @InactiveDays INT = 365,
    @ArchiveOnly BIT = 1  -- 1 = archive only, 0 = delete
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF @InactiveDays <= 0
        BEGIN
            THROW 50020, 'Inactive days must be positive', 1
        END
        
        DECLARE @CutoffDate DATE = DATEADD(DAY, -@InactiveDays, GETDATE());
        
        INSERT INTO Sales.CustomerArchive (CustomerID, TerritoryID, LastOrderDate, ArchivedDate)
        SELECT 
            c.CustomerID,
            c.TerritoryID,
            MAX(soh.OrderDate) AS LastOrderDate,
            GETDATE()
        FROM Sales.Customer c
        LEFT JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID
        GROUP BY c.CustomerID, c.TerritoryID
        HAVING MAX(soh.OrderDate) < @CutoffDate OR MAX(soh.OrderDate) IS NULL
        
        DECLARE @ArchivedCount INT = @@ROWCOUNT;
        
        IF @ArchiveOnly = 0
        BEGIN
            DELETE FROM Sales.Customer
            WHERE CustomerID IN (
                SELECT c.CustomerID
                FROM Sales.Customer c
                WHERE NOT EXISTS(
                SELECT 1 FROM Sales.SalesOrderHeader soh
                WHERE soh.CustomerID=c.CustomerID
                )
            )
            SELECT @ArchivedCount AS ArchivedCount, 'Customers deleted' AS Action
        END
        ELSE
        BEGIN
            SELECT @ArchivedCount AS ArchivedCount, 'Customers archived (not deleted)' AS Action
        END
        
        COMMIT TRANSACTION
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION
        
        SELECT 
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage
    END CATCH
END
GO

-- PROCEDURE FOR MONTHLY SALES REPORT
CREATE PROCEDURE MonthlySalesReport
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT
        YEAR(OrderDate) AS Year,
        MONTH(OrderDate) AS Month,
        SUM(TotalDue) AS TotalSales
    FROM Sales.SalesOrderHeader
    WHERE OrderDate BETWEEN @StartDate AND @EndDate
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
    ORDER BY Year, Month;
END
GO

-- PROCEDURE FOR TOP 10 BEST SELLING PRODUCTS
CREATE PROCEDURE Top10BestSellingProducts
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT TOP 10
        P.Name,
        SUM(SOD.OrderQty) AS TotalSold
    FROM Sales.SalesOrderDetail SOD
    JOIN Production.Product P
        ON SOD.ProductID = P.ProductID
    JOIN Sales.SalesOrderHeader SOH
        ON SOD.SalesOrderID = SOH.SalesOrderID
    WHERE SOH.OrderDate BETWEEN @StartDate AND @EndDate
    GROUP BY P.Name
    ORDER BY TotalSold DESC;
END
GO

-- PROCEDURE FOR EMPLOYEE PERFORMANCE HISTORY
CREATE PROCEDURE EmployeePerfomanceHistory
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SELECT 
        p.FirstName,
        p.LastName,
        COUNT(SalesOrderID) AS TotalOrders
    FROM Sales.SalesOrderHeader soh
    JOIN Person.Person p ON p.BusinessEntityID = soh.SalesPersonID
    WHERE soh.OrderDate BETWEEN @StartDate AND @EndDate
    GROUP BY p.FirstName, p.LastName
    ORDER BY TotalOrders DESC
END
GO

-- TEST
EXEC EmployeePerfomanceHistory '2012-02-13', '2013-03-27'
