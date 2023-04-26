USE cmcgath
GO

IF NOT EXISTS(SELECT 1 FROM sys.schemas WHERE name = 'pet')
	EXEC sp_executesql N'CREATE SCHEMA pet'
GO

USE cmcgath
GO
--TODO: consider temp tables for dropping
IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalPurchases')
BEGIN
	ALTER TABLE  pet.AnimalPurchases NOCHECK CONSTRAINT ALL
	DROP TABLE pet.AnimalPurchases
END
GO

IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'PurchasedAnimals')
BEGIN
	ALTER TABLE pet.PurchasedAnimals NOCHECK CONSTRAINT ALL
	DROP TABLE pet.PurchasedAnimals
END
GO

IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalInventory')
BEGIN
	ALTER TABLE  pet.AnimalInventory NOCHECK CONSTRAINT ALL
	DROP TABLE pet.AnimalInventory
END
GO

IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalBreed')
BEGIN
	ALTER TABLE  pet.AnimalBreed NOCHECK CONSTRAINT ALL
	DROP TABLE pet.AnimalBreed
END
GO

IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalType')
BEGIN
	ALTER TABLE  pet.AnimalType NOCHECK CONSTRAINT ALL
	DROP TABLE pet.AnimalType
END
GO

IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Customers')
BEGIN
	ALTER TABLE  pet.Customers NOCHECK CONSTRAINT ALL
	DROP TABLE pet.Customers
END
GO

-----------------------------
-----CREATE TABLES-----------
-----------------------------

--assume all animals of same type are stored in same container and location
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalType')
BEGIN
	CREATE TABLE pet.AnimalType(
		AnimalType varchar(50) PRIMARY KEY NOT NULL
		, StoreLocation varchar(50) NOT NULL
		, StorageContainer varchar(50) NOT NULL
	)
END
GO

--reasonable to know type (dog) from breed (poodle)
--discount determined by animal type and breed
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalBreed')
BEGIN
	CREATE TABLE pet.AnimalBreed(
		AnimalBreed varchar(50) PRIMARY KEY NOT NULL
		, AnimalType varchar(50) FOREIGN KEY REFERENCES pet.AnimalType NOT NULL
		, PossibleDiscount bit NOT NULL --TODO: normalize

	)
END
GO

--Assume AnimalID is a unique known/assigned number by the store
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalInventory')
BEGIN
	CREATE TABLE pet.AnimalInventory(
		AnimalID int PRIMARY KEY NOT NULL
		, AnimalName varchar(50) NOT NULL
		, DateOfBirth date NOT NULL
		, AnimalBreed varchar(50) FOREIGN KEY REFERENCES pet.AnimalBreed NOT NULL
		, ListPrice money NOT NULL
		, Fixed bit NOT NULL
		, Sex char(1) NOT NULL

	)
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'PurchasedAnimals')
BEGIN
	CREATE TABLE pet.PurchasedAnimals(
		AnimalID int PRIMARY KEY NOT NULL
		, AnimalName varchar(50) NOT NULL
		, DateOfBirth date NOT NULL
		, AnimalBreed varchar(50) FOREIGN KEY REFERENCES pet.AnimalBreed NOT NULL
		, ListPrice money NOT NULL
		, Fixed bit NOT NULL
		, Sex char(1) NOT NULL

	)
END
GO

--assume customers can purchase more than one animal per transaction?
--CustomerID is a unique customer number assigned by the store at checkout
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Customers')
BEGIN
	CREATE TABLE pet.Customers(
		CustomerID int PRIMARY KEY NOT NULL
		, FirstName varchar(30) NOT NULL
		, LastName varchar(40) NOT NULL
		, PhoneNumber varchar(20) NOT NULL
		, Email varchar(40) NOT NULL
		, Address varchar(50) NOT NULL
	)
END
GO

--for this store, each purchase represents the pruchase of one animal
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalPurchases')
BEGIN
	CREATE TABLE pet.AnimalPurchases(
		PurchaseID int PRIMARY KEY IDENTITY(1,1) NOT NULL
		, CustomerID int FOREIGN KEY REFERENCES pet.Customers NOT NULL
		, AnimalID int FOREIGN KEY REFERENCES pet.PurchasedAnimals NOT NULL
		, PurchaseDate date NOT NULL
		, PurchasePrice money NOT NULL
	)
END
GO

---------------------------------
----------STORE PROCS------------
---------------------------------

CREATE OR ALTER PROC pet.UpsertAnimal(
	@AnimalID int
	, @AnimalName varchar(50)
	, @DateOfBirth date
	, @AnimalBreed varchar(50)
	, @AnimalType varchar(50)
	, @StoreLocation varchar(50)
	, @StorageContainer varchar(50)
	, @PossibleDiscount bit
	, @ListPrice money
	, @Fixed bit 
	, @Sex char(1)
)
AS
BEGIN
	MERGE pet.AnimalType AS target
	USING(
		SELECT 
			@AnimalType as AnimalType
			, @StoreLocation as StoreLocation
			, @StorageContainer as StorageContainer
	) AS source
	ON target.AnimalType=source.AnimalType

	--do nothing when already matched (use UpsertAnimalType to edit locations/storage for animal type)

	WHEN NOT MATCHED BY TARGET
	THEN INSERT(
		AnimalType
		, StoreLocation
		, StorageContainer
	) VALUES(
		@AnimalType
		, @StoreLocation
		, @StorageContainer
	);

	MERGE pet.AnimalBreed AS target
	USING(
		SELECT 
			@AnimalBreed as AnimalBreed
			, @AnimalType as AnimalType
			, @PossibleDiscount as PossibleDiscount
	) AS source
	ON target.AnimalBreed=source.AnimalBreed

	--when matched leave animal breed table alone(use UpsertAnimalBreed to override discount info)
	
	WHEN NOT MATCHED BY TARGET
	THEN INSERT(
		AnimalBreed
		, AnimalType
		, PossibleDiscount
	) VALUES(
		@AnimalBreed
		, @AnimalType
		, @PossibleDiscount
	);

	MERGE pet.AnimalInventory AS target
	USING(
		SELECT
			@AnimalID as AnimalID
			, @AnimalName as AnimalName
			, @DateOfBirth as DateOfBirth
			, @AnimalBreed as AnimalBreed
			, @ListPrice as ListPrice
			, @Fixed as Fixed
			, @Sex as Sex
	) AS source
	ON target.AnimalID=source.AnimalID

	WHEN MATCHED
	THEN UPDATE SET
		AnimalName = @AnimalName
		, DateOfBirth = @DateOfBirth
		, AnimalBreed = @AnimalBreed
		, ListPrice = @ListPrice
		, Fixed = @Fixed
		, Sex = @Sex

	WHEN NOT MATCHED BY TARGET
	THEN INSERT(
		AnimalID
		, AnimalName
		, DateOfBirth
		, AnimalBreed
		, ListPrice
		, Fixed
		, Sex
	) VALUES(
		@AnimalID
		, @AnimalName
		, @DateOfBirth 
		, @AnimalBreed 
		, @ListPrice 
		, @Fixed  
		, @Sex
	);
END
GO

--only way to uniquely ID an animal is with the AnimalID number
CREATE OR ALTER PROC pet.DeleteAnimalByID(
	@AnimalID int
)
AS
BEGIN
	DELETE FROM pet.AnimalInventory WHERE AnimalID=@AnimalID
END
GO

CREATE OR ALTER PROC pet.UpsertCustomer(
	@CustomerID int
	, @FirstName varchar(30)
	, @LastName varchar(40)
	, @PhoneNumber varchar(20)
	, @Email varchar(40)
	, @Address varchar(50)
)
AS
BEGIN
	MERGE pet.Customers AS target
	USING(
		SELECT
			@CustomerID as CustomerID
			, @FirstName as FirstName
			, @LastName as LastName
			, @PhoneNumber as PhoneNumber
			, @Email as Email
			, @Address as Address
	)AS source
	ON target.CustomerID=source.CustomerID

	WHEN MATCHED
	THEN UPDATE SET
		FirstName = @FirstName
		, LastName = @LastName
		, PhoneNumber = @PhoneNumber
		, Email = @Email
		, Address = @Address

	WHEN NOT MATCHED BY TARGET
	THEN INSERT(
		CustomerID
		, FirstName
		, LastName
		, PhoneNumber
		, Email
		, Address
	) VALUES(
		@CustomerID
		, @FirstName
		, @LastName
		, @PhoneNumber
		, @Email	
		, @Address
	);
END
GO

--Likely won't ever want to delete a customer, better for the store to keep all records

--this proc inserts and can also override existing breed type and discount unlike upsert animal 
CREATE OR ALTER PROC pet.UpsertAnimalBreed(
	@AnimalBreed varchar(50)
	, @AnimalType varchar(50)
	, @PossibleDiscount varchar(50)
)
AS
BEGIN
	MERGE pet.AnimalBreed AS target
	USING(
		SELECT 
			@AnimalBreed as AnimalBreed
			, @AnimalType as AnimalType
			, @PossibleDiscount as PossibleDiscount
	) AS source
	ON target.AnimalBreed=source.AnimalBreed

	WHEN MATCHED 
	THEN UPDATE SET
		AnimalType = @AnimalType
		, PossibleDiscount = @PossibleDiscount

	WHEN NOT MATCHED BY TARGET
	THEN INSERT(
		AnimalBreed
		, AnimalType
		, PossibleDiscount
	) VALUES(
		@AnimalBreed
		, @AnimalType
		, @PossibleDiscount
	);
END
GO

CREATE OR ALTER PROC pet.UpsertAnimalType(
	@AnimalType varchar(50)
	, @StoreLocation varchar(50)
	, @StorageContainer varchar(50)
)
AS
BEGIN
	MERGE pet.AnimalType AS target
	USING(
		SELECT 
			@AnimalType as AnimalType
			, @StoreLocation as StoreLocation
			, @StorageContainer as StorageContainer
	) AS source
	ON target.AnimalType=source.AnimalType

	WHEN MATCHED
	THEN UPDATE SET
		StoreLocation = @StoreLocation
		, StorageContainer = @StorageContainer

	WHEN NOT MATCHED BY TARGET
	THEN INSERT(
		AnimalType
		, StoreLocation
		, StorageContainer
	) VALUES(
		@AnimalType
		, @StoreLocation
		, @StorageContainer
	);
END
GO

--no need to upsert because transactions could be identical theoretically
--only differ by purchase ID identity
--insert and delete by ID and update by ID will all be separate for this reason

CREATE OR ALTER PROC pet.AddTransaction(
	@AnimalID int
	, @PurchaseDate date
	, @CustomerID int
	, @FirstName varchar(30) = NULL
	, @LastName varchar(40) = NULL
	, @PhoneNumber varchar(20) = NULL
	, @Email varchar(40) = NULL
	, @Address varchar(50) = NULL

)
AS
BEGIN
	--should be entering all info if customer is new or none if already exists
	IF (@FirstName IS NOT NULL)
	BEGIN
		EXEC pet.UpsertCustomer 
			@CustomerID
			, @FirstName 
			, @LastName
			, @PhoneNumber
			, @Email
			, @Address
	END
	--calculate pruchase price based on discount
	DECLARE @PurchasePrice money

	SELECT @PurchasePrice = a.ListPrice
	FROM pet.AnimalInventory a
	WHERE a.AnimalID=@AnimalID

	--make sure customer is repeat (has bought before)
	IF EXISTS (SELECT 1 FROM pet.AnimalPurchases WHERE CustomerID=@CustomerID)
	BEGIN
		--make sure breed is eligbile for discount
		DECLARE @PossibleDiscount int

		SELECT @PossibleDiscount= b.PossibleDiscount 
		FROM pet.AnimalInventory a
		INNER JOIN pet.AnimalBreed b ON a.AnimalBreed=b.AnimalBreed
		WHERE a.AnimalID = @AnimalID 

		IF @PossibleDiscount = 1
		BEGIN
			SET @PurchasePrice = ROUND(@PurchasePrice * 0.9, 2)
			PRINT 'adjusted!'
		END


	END

	--update inventory
	INSERT INTO pet.PurchasedAnimals
	SELECT * FROM pet.AnimalInventory ai
	WHERE ai.AnimalID=@AnimalID

	DELETE FROM pet.AnimalInventory
	WHERE AnimalID=@AnimalID
	
	INSERT INTO pet.AnimalPurchases(
		CustomerID
		, AnimalID
		, PurchaseDate
		, PurchasePrice
	) VALUES(
		@CustomerID
		, @AnimalID
		, @PurchaseDate
		, @PurchasePrice
	)

END
GO

CREATE OR ALTER VIEW pet.vw_AnimalInventory AS
SELECT a.*, b.AnimalType, t.StoreLocation, t.StorageContainer
FROM pet.AnimalInventory a 
INNER JOIN pet.AnimalBreed b ON a.AnimalBreed=b.AnimalBreed
INNER JOIN pet.AnimalType t ON b.AnimalType=t.AnimalType
GO

CREATE OR ALTER VIEW pet.vw_PurchasedAnimals AS
SELECT a.*, b.AnimalType, t.StoreLocation, t.StorageContainer
FROM pet.PurchasedAnimals a 
INNER JOIN pet.AnimalBreed b ON a.AnimalBreed=b.AnimalBreed
INNER JOIN pet.AnimalType t ON b.AnimalType=t.AnimalType
GO

CREATE OR ALTER VIEW pet.vw_PurchaseDetails AS
SELECT ap.*, c.FirstName, c.LastName, c.PhoneNumber, c.Email, 
	pa.AnimalName, pa.AnimalType, pa.AnimalBreed, pa.DateOfBirth
FROM pet.AnimalPurchases ap
INNER JOIN pet.vw_PurchasedAnimals pa ON ap.AnimalID=pa.AnimalID
INNER JOIN pet.Customers c ON c.CustomerID=ap.CustomerID
GO


--TODO: report showing purchases by month for each type/breed of animal along with
--a summary showing total revenue overall by animal.
--TODO: test Deletes 

-----------------------------------------------
------DEAL WITH INDEXES-------------------------
-----------------------------------------------

--add some additional non-clustered indexes
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'idx_AnimalDateOfBirth')
BEGIN
	CREATE INDEX idx_AnimalDateOfBirth
	ON pet.AnimalInventory (DateOfBirth)
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'idx_PurchaseDate')
BEGIN
	CREATE INDEX idx_PurchaseDate
	ON pet.AnimalPurchases (PurchaseDate)
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE name = 'idx_AnimalBreedType')
BEGIN
	CREATE INDEX idx_AnimalBreedType
	ON pet.AnimalBreed (AnimalType)
END
GO

--fix fragmentation
DECLARE @tableName varchar(100)
DECLARE @idxName varchar(100)
DECLARE @avgFragmentation float

DECLARE idxCursor CURSOR FOR
SELECT 
    T.name [Table Name]
    , I.name [Index Name]
    , DDIPS.avg_fragmentation_in_percent  [Avg Fragmentation]
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) DDIPS
INNER JOIN sys.tables T on T.object_id = DDIPS.object_id
INNER JOIN sys.schemas S on T.schema_id = S.schema_id
INNER JOIN sys.indexes I ON I.object_id = DDIPS.object_id
WHERE S.name = 'pet'

OPEN idxCursor

FETCH NEXT FROM idxCursor
INTO @tableName, @idxName, @avgFragmentation

WHILE @@FETCH_STATUS = 0
BEGIN
	--use since alter index idx_name syntax neds string literal or constant not variable
	DECLARE @cmd nvarchar(max)

	IF @avgFragmentation >= 30
	BEGIN
		SET @cmd = 'ALTER INDEX ' + QUOTENAME(@idxName) + ' ON ' + QUOTENAME(@tableName) + ' REBUILD'
		EXEC sp_executesql @cmd
	END
	ELSE IF @avgFragmentation >= 5
	BEGIN
		SET @cmd = 'ALTER INDEX ' + QUOTENAME(@idxName) + ' ON ' + QUOTENAME(@tableName) + ' REORGANIZE'
		EXEC sp_executesql @cmd
	END

	FETCH NEXT FROM idxCursor
    INTO @tableName, @idxName, @avgFragmentation
END

CLOSE idxCursor
DEALLOCATE idxCursor


--------------------------------------------------------------------
------TESTS AND EXAMPLES--------------------------------------------
--------------------------------------------------------------------

EXEC pet.UpsertAnimal
	1
	, 'Freddie'
	, '2010-05-9'
	, 'Poodle'
	, 'Dog'
	, 'North'
	, 'Kennel'
	, 1
	, 700
	, 1
	, 'M'

EXEC pet.UpsertAnimal
	2
	, 'Pixie'
	, '2010-07-10'
	, 'Pyhton'
	, 'Snake'
	, 'South'
	, 'Glass Cage'
	, 1
	, 1500
	, 1
	, 'F'

EXEC pet.UpsertAnimal
	3
	, 'Damien'
	, '2012-09-11'
	, 'Beta'
	, 'Fish'
	, 'East'
	, 'Tank'
	, 0
	, 5
	, 0
	, 'M'

SELECT * FROM pet.vw_AnimalInventory;
SELECT * FROM pet.vw_PurchasedAnimals
EXEC pet.UpsertCustomer
	6811
	, 'John'
	, 'Doe'
	, '123-456-7890'
	, 'jdoe@gmail.com'
	, '100 Vanilla Drive Nampa, Idaho 83669'

EXEC pet.AddTransaction
	1
	, '2011-09-22'
	, 6811
	, 'Marcus'
	, 'Aurelius'
	, '503-444-6879'
	, 'maur@gmail.com'
	, '1800 Fair View Nampa, Idaho 83660'


EXEC pet.AddTransaction
	2
	, '2015-01-23'
	, 6811


SELECT * FROM pet.vw_AnimalInventory;
SELECT * FROM pet.vw_PurchasedAnimals;
SELECT * FROM pet.vw_PurchaseDetails;

--Oops! issue with the animal, needs be removed from inventory (not purchased)
EXEC pet.DeleteAnimalByID
	3

	SELECT * FROM pet.vw_AnimalInventory
--assume never necessary to delete customer, always good to have their info
--assume never necessary to delete a purchase as there are no refunds (purchases are final once they go through)