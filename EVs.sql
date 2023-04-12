SELECT *
FROM EVs
WHERE VIN = '5YJRE11B08'

										--DATA CLEANSING
--Simplify the CAFV Eligibility
UPDATE EVs
SET CAFV_Eligibility = 
	CASE CAFV_Eligibility
		WHEN 'Eligibility unknown as battery range has not been researched' THEN 'Unknown'
		WHEN 'Not eligible due to low battery range' THEN 'Not Eligible'
		WHEN 'Clean Alternative Fuel Vehicle Eligible' THEN 'Eligible'
	END

--New longitudes and latitudes
	--Update the current coordinates
UPDATE EVs
SET Vehicle_Location = REPLACE(Vehicle_Location, 'POINT (', '') --Remove the preceding part of the longitude

UPDATE EVs
SET Vehicle_Location = REPLACE(Vehicle_Location, ')', '') --Removing the trailing closing bracket

	--Test the syntax to separate the current location into new coordinates
SELECT
	Vehicle_Location
	,CHARINDEX(' ', Vehicle_Location) as space_location
	,SUBSTRING(Vehicle_Location, 1, CHARINDEX(' ', Vehicle_Location)-1) as longitude
	,SUBSTRING(Vehicle_Location, CHARINDEX(' ', Vehicle_Location)+1, LEN(Vehicle_Location)) as latitude
FROM EVs

	--Add the new column longitude and input the data
ALTER TABLE EVs
ADD longitude float

UPDATE EVs
SET longitude = SUBSTRING(Vehicle_Location, 1, CHARINDEX(' ', Vehicle_Location)-1)

	--Add the new column latitude and input the data
ALTER TABLE EVs
ADD latitude float

UPDATE EVs
SET latitude = SUBSTRING(Vehicle_Location, CHARINDEX(' ', Vehicle_Location)+1, LEN(Vehicle_Location))

--Replace rows with null values
UPDATE EVs
SET [Legislative_District] = ISNULL([Legislative_District], 0) --[Legislative_District] column

UPDATE EVs
SET Electric_Utility = ISNULL(Electric_Utility, 'Not Available') --Electric_Utility column

DELETE FROM EVs --County column
WHERE [County] is null



										--DATA EXPLORATION
--***Create a temporary table with Unique VINs
	--DROP TABLE IF EXISTS #unique_VIN
	CREATE TABLE #unique_VIN
	(new_model_year float, unique_VIN nvarchar(255))

	INSERT INTO #unique_VIN
	SELECT DISTINCT [Model Year], VIN
	FROM EVs


--***Create a temporary table with Unique VINs
	--DROP TABLE IF EXISTS #unique_licenses
	CREATE TABLE #unique_licenses
	(new_model_year float, unique_licenses nvarchar(255))

	INSERT INTO #unique_licenses
	SELECT DISTINCT [Model Year], DOL_Vehicle_ID
	FROM EVs


--***Count of registered vehicles
		--Test for duplicate VINs
	SELECT VIN, COUNT(*)
	FROM EVs
	GROUP BY VIN

		--Count the number of unique vehicles
	SELECT COUNT(*)
	FROM #unique_VIN


--***Numbers of licenses that the Washing Department of Licensing have issued
		--Test for duplicate DOLs
	SELECT DOL_Vehicle_ID, COUNT(*)
	FROM EVs
	GROUP BY DOL_Vehicle_ID

		--Count the number of unique licenses
	SELECT COUNT(*)
	FROM #unique_licenses

	SELECT COUNT(*)
	FROM EVs --Conclusion: the total of unique licenses equals to the total number of rows of the EVs table

--***Model Year with the highest count of registered vehicles
	SELECT TOP 1 a.new_model_year, a.count_of_vehicles
	FROM (
		SELECT new_model_year, COUNT(*) as count_of_vehicles
		FROM #unique_VIN
		GROUP BY new_model_year) a


--***Percentage of CAFV Eligibility each model year to the current total
	SELECT 
		a.[Model Year],
		--Convert both the numerator and denominator, then round to 2 decimal digits
		ROUND(CONVERT(float, COUNT(*)) --Calculate the numerator
		/ --Take a division
		CONVERT(float, (SELECT COUNT(*) FROM #unique_VIN))*100, 2) --Calculate the denominator
	FROM
		(SELECT DISTINCT [Model Year], VIN, CAFV_Eligibility
		FROM EVs
		GROUP BY [Model Year], VIN, CAFV_Eligibility
		HAVING CAFV_Eligibility = 'Eligible') a
	GROUP BY a.[Model Year]


--***Vehicle model year/make/model with the highest electric range
	SELECT DISTINCT [Model Year], Make, Model, Electric_Range
	FROM EVs
	WHERE Electric_Range =
		(SELECT MAX(Electric_Range) FROM EVs)

--***Vehicle model year/make/model with the highest base MSRP
	SELECT DISTINCT [Model Year], Make, Model, Base_MSRP
	FROM EVs
	WHERE Base_MSRP =
		(SELECT MAX(Base_MSRP) FROM EVs)

--***Percentage of the most popular make/model for each model year
	--Create a temporary table to store the numerators
	--DROP TABLE IF EXISTS #numerator
	CREATE TABLE #numerator
	(Model_year float, Make nvarchar(255), numerator float, numerator_ranking int)

	INSERT INTO #numerator
	SELECT b.[Model Year], b.Make, b.numerator
	--Assign ranks to the count. Rank 1 means the highest count
	, RANK() OVER (PARTITION BY b.[Model Year] ORDER BY b.[Model Year], b.numerator desc) as numerator_ranking
	FROM (
		SELECT a.[Model Year], a.Make, COUNT(*) as numerator  --Calculate the make count for each model year
		FROM 
			(SELECT DISTINCT [Model Year], VIN, Make
			FROM EVs
			GROUP BY [Model Year], VIN, Make) a
		GROUP BY a.[Model Year], a.Make) b
	
	--Create a CTE with distinct model year, VIN, and Make. The total count serves as the denominator
	WITH CTE_total_count AS (
	SELECT a.[Model Year], COUNT(*) as denominator
	FROM (
		SELECT DISTINCT [Model Year], VIN, Make
		FROM EVs
		GROUP BY [Model Year], VIN, Make) a
	GROUP BY a.[Model Year])

	SELECT 
		den.[Model Year], num.Make, num.numerator, den.denominator
		,ROUND((num.numerator/CONVERT(float, den.denominator)*100), 2) as percentage_of_total_count
	FROM CTE_total_count den
		INNER JOIN #numerator num
		ON num.Model_year = den.[Model Year] WHERE num.numerator_ranking = 1
	ORDER BY den.[Model Year]
	

--***Which electric utility company has provided energy to the most EV owners in WA
SELECT TOP 1
	Electric_Utility, COUNT(*) as numbers_of_serviced_owners
FROM EVs
GROUP BY [Model Year], Electric_Utility
ORDER BY [Model Year] desc

