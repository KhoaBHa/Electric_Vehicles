SELECT *
FROM Electric_Vehicle

										--DATA CLEANSING
--Simplify the CAFV Eligibility
UPDATE Electric_Vehicle
SET CAFV_Eligibility = 
	CASE CAFV_Eligibility
		WHEN 'Eligibility unknown as battery range has not been researched' THEN 'Unknown'
		WHEN 'Not eligible due to low battery range' THEN 'Not Eligible'
		WHEN 'Clean Alternative Fuel Vehicle Eligible' THEN 'Eligible'
	END

--New longitudes and latitudes
	--Update the current coordinates
UPDATE Electric_Vehicle
SET Vehicle_Location = REPLACE(Vehicle_Location, 'POINT (', '') --Remove the preceding part of the longitude

UPDATE Electric_Vehicle
SET Vehicle_Location = REPLACE(Vehicle_Location, ')', '') --Removing the trailing closing bracket

	--Test the syntax to separate the current location into new coordinates
SELECT
	Vehicle_Location
	,CHARINDEX(' ', Vehicle_Location) as space_location
	,SUBSTRING(Vehicle_Location, 1, CHARINDEX(' ', Vehicle_Location)-1) as longitude
	,SUBSTRING(Vehicle_Location, CHARINDEX(' ', Vehicle_Location)+1, LEN(Vehicle_Location)) as latitude
FROM Electric_Vehicle

	--Add the new column longitude and input the data
ALTER TABLE Electric_Vehicle
ADD longitude float

UPDATE Electric_Vehicle
SET longitude = SUBSTRING(Vehicle_Location, 1, CHARINDEX(' ', Vehicle_Location)-1)

	--Add the new column latitude and input the data
ALTER TABLE Electric_Vehicle
ADD latitude float

UPDATE Electric_Vehicle
SET latitude = SUBSTRING(Vehicle_Location, CHARINDEX(' ', Vehicle_Location)+1, LEN(Vehicle_Location))

--Replace/delete rows with null values
DELETE FROM Electric_Vehicle --County column
WHERE [County] is null

UPDATE Electric_Vehicle
SET [Legislative_District] = ISNULL([Legislative_District], 0) --[Legislative_District] column

DELETE FROM Electric_Vehicle
WHERE [Vehicle_Location] is null --[Vehicle_Location] column

DELETE FROM Electric_Vehicle
WHERE [Electric_Utility] is null --[Electric_Utility] column

										--DATA EXPLORATION
--Count of registered vehicles each year (assume the model years correspond with the years the vehicles were bought)
SELECT [Model Year], count(*) as number_of_vehicles
FROM Electric_Vehicle
GROUP BY [Model Year]
ORDER BY [Model Year]

--Year with the highest count of registered vehicles
SELECT TOP 1 a.[Model Year], a.number_of_vehicles
FROM
	(
	SELECT [Model Year], count(*) as number_of_vehicles
	FROM Electric_Vehicle
	GROUP BY [Model Year]) a
ORDER BY a.number_of_vehicles desc

--Percentage of CAFV Eligibility each year/current
SELECT 
	[Model Year], CAFV_Eligibility, COUNT(*) as count_eligibility --Count numbers of eligible vehicles each year
FROM Electric_Vehicle
GROUP BY [Model Year], CAFV_Eligibility
HAVING CAFV_Eligibility = 'Eligible'
ORDER BY [Model Year]

SELECT 
	a.[Model Year] as year_number
	, ROUND((CONVERT(float, a.count_eligibility)/CONVERT(float, b.number_of_vehicles)*100), 2) as percentage_of_eligibility --Convert to perform division, then round to 2 decimal digits.
FROM 
	(SELECT 
		[Model Year], CAFV_Eligibility, COUNT(*) as count_eligibility --Count numbers of eligible vehicles each year
	FROM Electric_Vehicle
	GROUP BY [Model Year], CAFV_Eligibility
	HAVING CAFV_Eligibility = 'Eligible') a --the COUNT serves as the numerator

LEFT JOIN

	(SELECT [Model Year], count(*) as number_of_vehicles --Count numbers of total registered vehicles
	FROM Electric_Vehicle
	GROUP BY [Model Year]) b --the COUNT serves as the denominator
ON a.[Model Year] = b.[Model Year]
ORDER BY a.[Model Year]

--First year WA got their first vehicle CAFV Eligible
SELECT TOP 1
	[Model Year]
FROM Electric_Vehicle
GROUP BY [Model Year], CAFV_Eligibility
HAVING CAFV_Eligibility = 'Eligible'
ORDER BY [Model Year]

--Vehicle model year/make/model with the highest electric range
SELECT DISTINCT [Model Year], Make, Model, Electric_Range
FROM Electric_Vehicle
WHERE Electric_Range =
	(SELECT MAX(Electric_Range) FROM Electric_Vehicle)

--Vehicle model year/make/model with the highest base MSRP
SELECT DISTINCT [Model Year], Make, Model, Base_MSRP
FROM Electric_Vehicle
WHERE Base_MSRP =
	(SELECT MAX(Base_MSRP) FROM Electric_Vehicle)

--Percentage of the most popular make/model in WA each year
SELECT [Model Year], Make,  COUNT(*) as vehicles_count --Test: Count numbers of vehicle makes each year
FROM Electric_Vehicle
GROUP BY [Model Year], Make
		
	--Calculate the Numerator
WITH Numerator AS
	(SELECT
		b.[Model Year], b.Make, b.vehicles_count
	FROM
		(SELECT *
			, RANK() OVER (PARTITION BY a.[Model Year] ORDER BY a.[Model Year], a.vehicles_count desc) as ranking --Set ranking for makes each year (rank 1 means highest counts)
		FROM 
			(SELECT [Model Year], Make,  COUNT(*) as vehicles_count --Count numbers of vehicle makes each year
			FROM Electric_Vehicle
			GROUP BY [Model Year], Make
			) a
		) b
	WHERE b.ranking = 1) --Select the highest vehicle counts

SELECT num.*, den.total_vehicles_count
	,ROUND((CONVERT(float, num.vehicles_count)/CONVERT(float, den.total_vehicles_count)*100), 2) as Percentage_of_the_most_popular_make --Convert data types and round the result to 2 decimal digits
FROM Numerator num
	
	LEFT JOIN

(SELECT 
	[Model Year],  COUNT(*) as total_vehicles_count --Calculate the denominator
FROM Electric_Vehicle
GROUP BY [Model Year]) den
	ON num.[Model Year] = den.[Model Year]

--Which electric utility company provides energy to the most EV owners in WA each year
SELECT Electric_Utility, [Model Year], COUNT(*) as numbers_of_owners --Test: Count numbers of vehicle makes each year
FROM Electric_Vehicle
GROUP BY [Model Year], Electric_Utility
ORDER BY [Model Year]

SELECT
	b.[Model Year], b.Electric_Utility, b.owners_count
FROM
	(SELECT *
		, RANK() OVER (PARTITION BY a.[Model Year] ORDER BY a.[Model Year], a.owners_count desc) as ranking --Set ranking for numbers of owners each year (rank 1 means highest counts)
	FROM 
		(SELECT [Model Year], Electric_Utility,  COUNT(*) as owners_count --Count numbers of vehicle makes each year
		FROM Electric_Vehicle
		GROUP BY [Model Year], Electric_Utility
		) a
	) b
WHERE b.ranking = 1 --Select the highest vehicle makes
ORDER BY b.[Model Year]