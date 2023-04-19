USE cmcgath
GO

IF NOT EXISTS(SELECT 1 FROM sys.schemas WHERE name = 'pet')
	EXEC sp_executesql N'CREATE SCHEMA pet'
GO

USE cmcgath
GO
--TODO: consider temp tables for dropping
IF EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Purchases')
BEGIN
	ALTER TABLE  pet.Purchases NOCHECK CONSTRAINT ALL
	DROP TABLE pet.Purchases
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
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalBreed')
BEGIN
	CREATE TABLE pet.AnimalBreed(
		AnimalBreed varchar(50) PRIMARY KEY NOT NULL
		, AnimalType varchar(50) FOREIGN KEY REFERENCES pet.AnimalType NOT NULL
	)
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Animals')
BEGIN
	CREATE TABLE pet.Animals(
		AnimalID int PRIMARY KEY IDENTITY(1,1) NOT NULL
		, AnimalName varchar(50) NULL
		, DateOfBirth date NULL
		, AnimalBreed varchar(50) FOREIGN KEY REFERENCES pet.AnimalBreed NULL
		, ListPrice money NULL
		, Discount bit NULL --TODO: normalize
		, Fixed bit NULL --TODO: Enum?
		, Sex char(1) NULL --TODO: check datatype

	)
END
GO

--Q: assume customers can purchase more than one animal per transaction?

IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'Customers')
BEGIN
	CREATE TABLE pet.Customers(
		CustomerID int PRIMARY KEY IDENTITY(1,1) NOT NULL
		, FirstName varchar(30)
		, LastName varchar(40)
		, PhoneNumber varchar(20)
		, Email varchar(40)
		, Address varchar(50)
	)
END
GO

IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'AnimalPurchases')
BEGIN
	CREATE TABLE pet.AnimalPurchases(
		PurchaseID int FOREIGN KEY REFERENCES pet.Purchases NOT NULL
		, AnimalID int FOREIGN KEY REFERENCES pet.Animals NOT NULL
		, Qty int NOT NULL
		, CONSTRAINT AnimalPurchaseKey PRIMARY KEY(
			PurchaseID ASC
			, AnimalID ASC
		)

	)
END
GO
IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE name = 'CustomerPurchases')
BEGIN
	CREATE TABLE pet.CustomerPurchases(
		PurchaseID int PRIMARY KEY IDENTITY(1,1) NOT NULL
		, CustomerID int FOREIGN KEY REFERENCES pet.Customers NOT NULL
		, PurchaseDate date NOT NULL
		, ListPrice int NOT NULL
		, Discount bit NOT NULL
	)
END
GO