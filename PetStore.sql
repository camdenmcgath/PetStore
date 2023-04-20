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

IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Animals')
BEGIN
	ALTER TABLE  pet.Animals NOCHECK CONSTRAINT ALL
	DROP TABLE pet.Animals
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
		, PossibleDiscount bit NULL --TODO: normalize

	)
END
GO

--Assume AnimalID is a unique known/assigned number by the store
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Animals')
BEGIN
	CREATE TABLE pet.Animals(
		AnimalID int PRIMARY KEY NOT NULL
		, AnimalName varchar(50) NULL
		, DateOfBirth date NULL
		, AnimalBreed varchar(50) FOREIGN KEY REFERENCES pet.AnimalBreed NULL
		, ListPrice money NULL
		, Fixed bit NULL --TODO: Enum?
		, Sex char(1) NULL --TODO: check datatype

	)
END
GO

--assume customers can purchase more than one animal per transaction?
--CustomerID is a unique customer number assigned by the store at checkout
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Customers')
BEGIN
	CREATE TABLE pet.Customers(
		CustomerID int PRIMARY KEY NOT NULL
		, FirstName varchar(30)
		, LastName varchar(40)
		, PhoneNumber varchar(20)
		, Email varchar(40)
		, Address varchar(50)
	)
END
GO

--for this store, each purchase represents the pruchase of one animal
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalPurchases')
BEGIN
	CREATE TABLE pet.AnimalPurchases(
		PurchaseID int PRIMARY KEY IDENTITY(1,1) NOT NULL
		, CustomerID int FOREIGN KEY REFERENCES pet.Customers NOT NULL
		, AnimalID int FOREIGN KEY REFERENCES pet.Animals NOT NULL
		, PurchaseDate date NOT NULL
		, ListPrice int NOT NULL
		, DiscountApplied bit NOT NULL
	)
END
GO

---------------------------------
----------STORE PROCS------------
---------------------------------

CREATE OR ALTER PROC pet.InsertAnimal(
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

	MERGE pet.Animals AS target
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
		AnimalName
		, DateOfBirth
		, AnimalBreed
		, ListPrice
		, Fixed
		, Sex
	) VALUES(
		@AnimalName
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
	DELETE FROM pet.Animals WHERE AnimalID=@AnimalID
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
	@CustomerID int
	, @FirstName varchar(30) = NULL
	, @LastName varchar(40) = NULL
	, @PhoneNumber varchar(20) = NULL
	, @Email varchar(40) = NULL
	, @Address varchar(50) = NULL
	, @AnimalID int
	, @PurchaseDate date
	, @ListPrice int
	, @DiscountApplied bit
)
AS
BEGIN
	--should be entering all info if customer is new or none if already exists
	IF (@FirstName IS NOT NULL)
	BEGIN
		EXEC UpsertCustomer 
			@CustomerID
			, @FirstName 
			, @LastName
			, @PhoneNumber
			, @Email
			, @Address
	END
	INSERT INTO pet.AnimalPurchases(
		CustomerID
		, AnimalID
		, PurchaseDate
		, ListPrice
		, DiscountApplied
	) VALUES(
		@CustomerID
		, @AnimalID
		, @PurchaseDate
		, @ListPrice
		, @DiscountApplied
	)
	--update inventory (remove purchased animal)
	EXEC DeleteAnimalByID
		@AnimalID

END
GO

--TODO: view to show purchase list and inventory of animals
--TODO: report showing purchases by month for each type/breed of animal along with
--a summary showing total revenue overall by animal.
--TODO: create tests of procs 
--TODO: code to rebuild indexes
--TODO: Track discount somehow?