USE master
GO

IF DB_ID('Cinema') IS NOT NULL
    DROP DATABASE Cinema
GO
CREATE DATABASE Cinema
GO

USE Cinema
GO

-- Movies table
CREATE TABLE Movies (
    Id INT NOT NULL PRIMARY KEY IDENTITY(1,1),
    Title NVARCHAR(100) NOT NULL,
    Genre NVARCHAR(50) NOT NULL,
    Director NVARCHAR(100) NOT NULL,
    ReleaseYear INT NOT NULL,

    CONSTRAINT CHK_Movies_Title CHECK (Title <> ''),
    CONSTRAINT CHK_Movies_Genre CHECK (Genre <> ''),
    CONSTRAINT CHK_Movies_Director CHECK (Director <> ''),
    CONSTRAINT CHK_Movies_ReleaseYear CHECK (ReleaseYear > 1888 AND ReleaseYear <= YEAR(GETDATE()) + 1)
);

-- Halls table
CREATE TABLE Halls (
    Id INT NOT NULL PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(50) NOT NULL,
    Capacity INT NOT NULL DEFAULT 100,

    CONSTRAINT CHK_Halls_Name CHECK (Name <> ''),
    CONSTRAINT CHK_Halls_Capacity CHECK (Capacity > 0)
);

-- Clients table
CREATE TABLE Clients (
    Id INT NOT NULL PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL,

    CONSTRAINT CHK_Clients_Name CHECK (Name <> ''),
    CONSTRAINT CHK_Clients_Email CHECK (Email LIKE '%_@__%.__%')
);

-- Showtimes table
CREATE TABLE Showtimes (
    Id INT PRIMARY KEY IDENTITY(1,1),
    MovieId INT NOT NULL,
    HallId INT NOT NULL,
    Showtime DATETIME NOT NULL,
    AvailableSeats INT NOT NULL,

    CONSTRAINT FK_Showtimes_Movies FOREIGN KEY (MovieId) REFERENCES Movies(Id),
    CONSTRAINT FK_Showtimes_Halls FOREIGN KEY (HallId) REFERENCES Halls(Id)
);

-- Tickets table
CREATE TABLE Tickets (
    Id INT NOT NULL PRIMARY KEY IDENTITY(1,1),
    ClientId INT NOT NULL,
    ShowtimeId INT NOT NULL,
    SeatNumber INT NOT NULL,
    Price DECIMAL(10,2) NOT NULL DEFAULT 300.00,
    PurchaseDate DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Tickets_Clients FOREIGN KEY (ClientId) REFERENCES Clients(Id),
    CONSTRAINT FK_Tickets_Showtimes FOREIGN KEY (ShowtimeId) REFERENCES Showtimes(Id),
    CONSTRAINT CHK_Tickets_SeatNumber CHECK (SeatNumber > 0),
    CONSTRAINT CHK_Tickets_Price CHECK (Price > 0)
);

-- Insert test data
INSERT INTO Movies (Title, Genre, Director, ReleaseYear)
VALUES
('Inception', 'Sci-Fi', 'Christopher Nolan', 2010),
('The Godfather', 'Crime', 'Francis Ford Coppola', 1972),
('Interstellar', 'Sci-Fi', 'Christopher Nolan', 2014),
('Pulp Fiction', 'Crime', 'Quentin Tarantino', 1994),
('The Matrix', 'Sci-Fi', 'Wachowskis', 1999),
('Titanic', 'Romance', 'James Cameron', 1997),
('Avatar', 'Sci-Fi', 'James Cameron', 2009),
('Parasite', 'Thriller', 'Bong Joon-ho', 2019),
('Dune', 'Sci-Fi', 'Denis Villeneuve', 2021),
('Joker', 'Drama', 'Todd Phillips', 2019);

INSERT INTO Halls (Name, Capacity)
VALUES
('Red Hall', 100),
('Blue Hall', 150),
('VIP Hall', 50),
('IMAX Hall', 200),
('Gold Hall', 80);

INSERT INTO Clients (Name, Email)
VALUES
('John Doe', 'john@example.com'),
('Alice Smith', 'alice@example.com'),
('Bob Johnson', 'bob@example.com'),
('Eve Adams', 'eve@example.com'),
('Charlie Brown', 'charlie@example.com'),
('Diana Prince', 'diana@example.com');

-- Insert showtimes
INSERT INTO Showtimes (MovieId, HallId, Showtime, AvailableSeats)
VALUES
(1, 1, DATEADD(DAY, 1, GETDATE()), 100),
(2, 2, DATEADD(DAY, 2, GETDATE()), 150),
(3, 3, DATEADD(DAY, 3, GETDATE()), 50),
(1, 4, DATEADD(DAY, 1, DATEADD(HOUR, 3, GETDATE())), 200),
(4, 1, DATEADD(DAY, 4, GETDATE()), 100),
(5, 2, DATEADD(DAY, 5, GETDATE()), 150),
(6, 3, DATEADD(DAY, 6, GETDATE()), 50),
(7, 4, DATEADD(DAY, 7, GETDATE()), 200),
(8, 5, DATEADD(DAY, 8, GETDATE()), 80),
(9, 1, DATEADD(DAY, 9, GETDATE()), 100);

-- Insert test tickets
INSERT INTO Tickets (ClientId, ShowtimeId, SeatNumber, Price)
VALUES
(1, 1, 1, 350.00),
(2, 1, 2, 350.00),
(3, 2, 1, 400.00),
(4, 3, 1, 500.00),
(1, 4, 1, 450.00),
(2, 5, 1, 320.00),
(5, 2, 2, 400.00),
(6, 3, 2, 500.00),
(3, 4, 2, 450.00),
(4, 5, 2, 320.00),
(1, 6, 1, 480.00),
(2, 7, 1, 420.00);
GO



-- ===== TRIGGERS =====
CREATE TRIGGER SeatTrigger
ON Tickets
AFTER INSERT, UPDATE, DELETE AS
UPDATE S
SET AvailableSeats = AvailableSeats -
(SELECT COUNT(*) FROM inserted I WHERE I.ShowtimeId = S.Id) +
(SELECT COUNT(*) FROM deleted D WHERE D.ShowtimeId = S.Id) FROM Showtimes S
WHERE S.Id IN (SELECT ShowtimeId FROM inserted UNION SELECT ShowtimeId FROM deleted)
GO

CREATE TRIGGER BlockMovies
ON Tickets
INSTEAD OF INSERT
AS
INSERT INTO Tickets (ClientId, ShowtimeId, SeatNumber, Price, PurchaseDate)
SELECT  I.ClientId,  I.ShowtimeId,   I.SeatNumber,  I.Price,  GETDATE() FROM inserted I
WHERE I.ShowtimeId IN ( SELECT S.Id FROM Showtimes S
JOIN (SELECT S.MovieId, COUNT(T.Id) as TicketsSold FROM Showtimes S
LEFT JOIN Tickets T ON S.Id = T.ShowtimeId
WHERE S.Showtime >= DATEADD(DAY, -7, GETDATE())
GROUP BY S.MovieId
HAVING COUNT(T.Id) >= 3 ) AS PopularMovies ON S.MovieId = PopularMovies.MovieId
)
GO


CREATE TRIGGER UpgradeToVip
ON Tickets
AFTER INSERT
AS
UPDATE Tickets
SET Price = Price * 2.0
WHERE Id IN (SELECT T.Id FROM Tickets T
JOIN Showtimes S ON T.ShowtimeId = S.Id
JOIN Halls H ON S.HallId = H.Id
WHERE S.Id IN (SELECT S.Id FROM Showtimes S
JOIN Halls H ON S.HallId = H.Id
WHERE S.AvailableSeats < (H.Capacity * 0.1)) AND T.Price < 500.0)
GO



-- ===== PROCEDURES =====

-- Procedure to buy a ticket (automatically assigns next available seat)
CREATE PROCEDURE BuyTicket AS
INSERT INTO Tickets (ClientId, ShowtimeId, SeatNumber, Price)
SELECT TOP 1 C.Id, S.Id, (SELECT ISNULL(MAX(T.SeatNumber), 0) + 1 FROM Tickets T WHERE T.ShowtimeId = S.Id), 350.00
FROM Showtimes S
CROSS JOIN (SELECT TOP 1 * FROM Clients ORDER BY NEWID()) C
WHERE S.AvailableSeats > 0 AND S.Showtime > GETDATE()
ORDER BY S.Showtime
GO

-- Procedure to refund a ticket (marks ticket as refunded by deleting it)
CREATE PROCEDURE RefundTicket AS
DELETE FROM Tickets
WHERE Id = (SELECT TOP 1 Id FROM Tickets ORDER BY Id DESC)
GO

-- Procedure to show all tickets with detailed information
CREATE PROCEDURE ShowAllTickets AS
SELECT T.Id AS TicketID, C.Name AS ClientName,  M.Title AS MovieTitle,  H.Name AS HallName,  S.Showtime AS ShowTime,  T.SeatNumber AS SeatNumber,  T.Price AS Price,  T.PurchaseDate AS PurchaseDate FROM Tickets T
JOIN Clients C ON T.ClientId = C.Id
JOIN Showtimes S ON T.ShowtimeId = S.Id
JOIN Movies M ON S.MovieId = M.Id
JOIN Halls H ON S.HallId = H.Id
ORDER BY T.Id
GO

--Procedure to get movie statistics
CREATE PROCEDURE GetMovieStats AS
SELECT M.Title AS MovieTitle,  M.Genre AS Genre, COUNT(T.Id) AS TicketsSold, SUM(T.Price) AS TotalRevenue FROM Movies M
LEFT JOIN Showtimes S ON M.Id = S.MovieId
LEFT JOIN Tickets T ON S.Id = T.ShowtimeId
GROUP BY M.Id, M.Title, M.Genre
ORDER BY COUNT(T.Id) DESC
GO




-- ===== VIEWS =====

-- View showing current cinema schedule with availability
CREATE VIEW CinemaSchedule AS
SELECT M.Title AS MovieTitle, M.Genre AS Genre, H.Name AS HallName, S.Showtime AS ShowTime, S.AvailableSeats AS AvailableSeats, H.Capacity AS TotalSeats FROM Showtimes S
JOIN Movies M ON S.MovieId = M.Id
JOIN Halls H ON S.HallId = H.Id
WHERE S.Showtime > GETDATE()
GO

-- View showing ticket sales by hall

CREATE VIEW HallSales AS
SELECT H.Name AS HallName, COUNT(T.Id) AS TicketsSold,  SUM(T.Price) AS Revenue FROM Halls H
LEFT JOIN Showtimes S ON H.Id = S.HallId
LEFT JOIN Tickets T ON S.Id = T.ShowtimeId
GROUP BY H.Id, H.Name
GO



-- ===== QUERIES =====
-- Simple query to show all movies
SELECT Title, Genre, Director, ReleaseYear FROM Movies
ORDER BY Title

-- Query to show movies and their showtimes
SELECT M.Title, M.Genre, S.Showtime, H.Name AS HallName
FROM Movies M
JOIN Showtimes S ON M.Id = S.MovieId
JOIN Halls H ON S.HallId = H.Id
WHERE S.Showtime > GETDATE()
ORDER BY S.Showtime

-- Query to find clients who bought tickets for specific movie
SELECT C.Name, C.Email FROM Clients C
WHERE C.Id IN (SELECT T.ClientId FROM Tickets T JOIN Showtimes S ON T.ShowtimeId = S.Id WHERE S.MovieId = 1
)

-- Query to show genres with more than 2 movies
SELECT Genre, COUNT(*) AS MovieCount FROM Movies
GROUP BY Genre
HAVING COUNT(*) > 2
ORDER BY MovieCount DESC

-- Complex query to show ticket details
SELECT T.Id AS TicketID, C.Name AS ClientName, M.Title AS MovieTitle, H.Name AS HallName, S.Showtime, T.Price FROM Tickets T
JOIN Clients C ON T.ClientId = C.Id
JOIN Showtimes S ON T.ShowtimeId = S.Id
JOIN Movies M ON S.MovieId = M.Id
JOIN Halls H ON S.HallId = H.Id
ORDER BY T.PurchaseDate DESC

-- Query to combine movie and hall information
SELECT 'Movie' AS Type, Title AS Name, Genre AS Category FROM Movies
UNION ALL
SELECT 'Hall' AS Type, Name AS Name, 'Cinema Hall' AS Category FROM Halls
ORDER BY Type, Name

--  Query to find most expensive tickets
SELECT T.Id, T.Price, C.Name AS ClientName, M.Title AS MovieTitle FROM Tickets T
JOIN Clients C ON T.ClientId = C.Id
JOIN Showtimes S ON T.ShowtimeId = S.Id
JOIN Movies M ON S.MovieId = M.Id
WHERE T.Price > (SELECT AVG(Price) FROM Tickets)
ORDER BY T.Price DESC

-- Query to show halls with their occupancy rate

SELECT H.Name AS HallName,  H.Capacity, COUNT(T.Id) AS TicketsSold,  (H.Capacity - AVG(S.AvailableSeats)) AS AverageOccupied FROM Halls H
LEFT JOIN Showtimes S ON H.Id = S.HallId
LEFT JOIN Tickets T ON S.Id = T.ShowtimeId
GROUP BY H.Id, H.Name, H.Capacity

-- Query to find movies with no tickets sold
SELECT M.Title, M.Genre FROM Movies M
WHERE M.Id NOT IN (SELECT DISTINCT S.MovieId FROM Showtimes S
JOIN Tickets T ON S.Id = T.ShowtimeId
)

--Query to show revenue by genre
SELECT   M.Genre,  COUNT(T.Id) AS TicketsSold,  SUM(T.Price) AS TotalRevenue,  AVG(T.Price) AS AveragePrice
FROM Movies M
JOIN Showtimes S ON M.Id = S.MovieId
JOIN Tickets T ON S.Id = T.ShowtimeId
GROUP BY M.Genre
ORDER BY TotalRevenue DESC


-- Sessions for the next week (7 days)
SELECT M.Title AS MovieTitle,  M.Genre AS Genre, H.Name AS HallName, S.Showtime AS ShowTime,  S.AvailableSeats AS AvailableSeats,  H.Capacity AS TotalSeats FROM Showtimes S
JOIN Movies M ON S.MovieId = M.Id
JOIN Halls H ON S.HallId = H.Id
WHERE S.Showtime >= GETDATE() AND S.Showtime <= DATEADD(DAY, 7, GETDATE())
ORDER BY S.Showtime, M.Title


--The most popular movies (by number of tickets sold
SELECT  M.Title AS MovieTitle, M.Genre AS Genre, M.Director AS Director, COUNT(T.Id) AS TicketsSold, SUM(T.Price) AS TotalRevenue FROM Movies M
LEFT JOIN Showtimes S ON M.Id = S.MovieId
LEFT JOIN Tickets T ON S.Id = T.ShowtimeId
GROUP BY M.Id, M.Title, M.Genre, M.Director
ORDER BY COUNT(T.Id) DESC, SUM(T.Price) DESC


--Sessions for tomorrow
SELECT M.Title AS MovieTitle, M.Genre AS Genre, H.Name AS HallName, S.Showtime AS ShowTime, S.AvailableSeats AS AvailableSeats FROM Showtimes S
JOIN Movies M ON S.MovieId = M.Id
JOIN Halls H ON S.HallId = H.Id
WHERE S.Showtime >= DATEADD(DAY, 1, GETDATE()) AND S.Showtime < DATEADD(DAY, 2, GETDATE())
ORDER BY S.Showtime

-- Movies with an average ticket price of more than 400 UAH
SELECT  M.Title AS MovieTitle, M.Genre AS Genre, COUNT(T.Id) AS TicketsSold, AVG(T.Price) AS AveragePrice, SUM(T.Price) AS TotalRevenue FROM Movies M
LEFT JOIN Showtimes S ON M.Id = S.MovieId
LEFT JOIN Tickets T ON S.Id = T.ShowtimeId
GROUP BY M.Id, M.Title, M.Genre
HAVING AVG(T.Price) > 400.00
ORDER BY AVG(T.Price) DESC






--provikra
EXEC BuyTicket

EXEC ShowAllTickets

EXEC RefundTicket

EXEC GetMovieStats

SELECT * FROM CinemaSchedule ORDER BY ShowTime
SELECT * FROM HallSales ORDER BY Revenue DESC
GO