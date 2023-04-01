USE DataProject

-- Double check that data imported correctly
SELECT *
FROM CovidDeaths
ORDER BY location, date;

-- It appears we need to update the data type for the total_deaths and new_deaths field
-- Generally a good idea to hold transactions when updating tables (don't want to lose our data!)
--BEGIN TRANSACTION
--ALTER Table CovidDeaths
--Alter column total_deaths int
--Alter Table CovidDeaths
--Alter column new_deaths int
--COMMIT

SELECT *
FROM CovidDeaths
WHERE continent is NULL

-- Seems like the data is organized to have Continents as their own stats separate from Country, which I'm not a fan of.

-- Let's take a more specific look at important columns

SELECT location, 
	date, 
	total_cases, 
	new_cases, 
	total_deaths, 
	population
FROM CovidDeaths
ORDER BY location, date;

-- First let's look by country, and ID Total Cases vs Total Deaths
-- Shows chance of death based on time
SELECT location, 
	date, 
	total_cases, 
	total_deaths, 
	ROUND(((total_deaths/total_cases)*100),3) as 'Percent of Infection Deaths'
FROM CovidDeaths
WHERE location = 'United States'
ORDER BY location, date;

-- Total Cases vs Population Size
SELECT location, 
	date, 
	total_cases, 
	population, 
	ROUND(((total_cases/population)*100),3) as 'Percent of Population having COVID-19'
FROM CovidDeaths
WHERE location = 'United States'
ORDER by date;

-- Highest Infection Percentage Over the Course of the Pandemic (All Countries) & Highest Infection Count
SELECT location, 
	population,
	MAX(total_cases) as HighestInfectionCount,
	MAX(((total_cases)/population)*100) as PercentPopulationInfected
FROM CovidDeaths
GROUP BY location, population
ORDER BY PercentPopulationInfected desc

-- Country Death % based on population

SELECT location,
	MAX(cast(total_deaths as int)) as TotalDeathCount,
	population,
	(MAX(total_deaths)/population)*100 as DeathPercent
FROM CovidDeaths
GROUP BY location, population
ORDER by TotalDeathCount desc

-- Continent Death % based on population
SELECT continent, 
	SUM(TotalDeathCount) as TotalDeathCount, 
	SUM(LocationPopulation) as ContinentPopulation, 
	(SUM(TotalDeathCount)/SUM(LocationPopulation))*100 as DeathPercentage
FROM (
  SELECT continent, location, MAX(total_deaths) as TotalDeathCount, MAX(population) as LocationPopulation
  FROM CovidDeaths
  WHERE continent IS NOT NULL
  GROUP BY continent, location
) MaxDeathsPerCountry
GROUP BY continent
ORDER BY TotalDeathCount DESC

-- Verify our results are correct by comparing to independent continent data
-- There appears to be a European Union, and a Europe Entry, so we should exclude it from data, along with "international"

SELECT location, MAX(total_deaths) as TotalDeathCount
FROM CovidDeaths
WHERE continent IS NULL
GROUP BY location
HAVING location NOT IN ('World', 'European Union', 'International')
ORDER BY TotalDeathCount desc;


-- Global Total Numbers by Date
SELECT date, 
	SUM(new_cases) as TotalCasesToDate,
	SUM(new_deaths) as TotalDeathsToDate,
	(SUM(new_deaths)/SUM(new_cases))*100 AS FatalityPercentage
FROM CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY date

-- Now that we have some general ideas about what Death counts looked like by Country, by Continent, and throughout the world, let's look at if vaccinations had any effect on the deaths

-- First let's look at high vaccination countries so we can compare their death rates to vaccinations
SELECT d.continent, 
	d.location, 
	d.date, 
	d.population, 
	v.new_vaccinations,
	SUM(CAST(v.new_vaccinations AS int)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS TotalVaccinations,
	(TotalVaccinations/population)*100
FROM CovidDeaths d
JOIN CovidVaccinations v
ON d.location = v.location
AND d.date = v.date
WHERE d.continent IS NOT NULL
ORDER BY d.location, d.date

-- We can use a CTE for what we need above
WITH VaccToPopRatio (continent, location, date, population, new_vaccinations, TotalVaccinations)
as
(
SELECT d.continent, 
	d.location, 
	d.date, 
	d.population, 
	v.new_vaccinations,
	SUM(CAST(v.new_vaccinations AS int)) OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS TotalVaccinations
FROM CovidDeaths d
JOIN CovidVaccinations v
ON d.location = v.location
AND d.date = v.date
WHERE d.continent IS NOT NULL
)

SELECT *, ((TotalVaccinations/population)*100)/2 as PercentPopulationVaccinated FROM VaccToPopRatio
ORDER By [PercentPopulationVaccinated] DESC

-- Noticed a major issue, vaccinations is most likely referring to 2 doses of the vaccine, which will cause our total value to be over 100% for some countries. To find the percentage of
-- fully vaccinated we need to divice by two. 

-- Good Countries to investigate are: Gibraltar, Chile, Israel, the UAE, and the US
-- Unfortunately Gilbraltar has no death data for us to look at, so we will exclude it.


-- Identify relationships between population being vaccinated and mortality rates to see if there is any relationship.
SELECT d.date,
	d.location,
	((v.total_vaccinations/population)*100)/2 as 'Percent of Population Vaccinated',
	((d.total_deaths/d.total_cases)*100) AS 'Chance of Dying From COVID'
FROM CovidDeaths d
JOIN CovidVaccinations v
ON d.location = v.location
AND d.date = v.date
WHERE d.location IN ('United Arab Emirates', 'Chile', 'Israel', 'United States')
ORDER BY d.location, d.date