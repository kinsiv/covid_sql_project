

/* FIRST SECTION: Creating 2 running total update triggers for World location. MS SQL Server Management Studio is limited in code funcitonality, 
thus these are created using syntax of MySQL. All other code obliges by Studio syntax.

There are two running total attributes, total_cases and total_deaths. If a use was to be in a situation where they were required to update a record on an old date,
say a year ago due to updated information - the totals in this scenario needs to adapt. To accomadate this or a delete scenario, the 2 triggers below are running.
How they work: 2 session variable counters are created, @@total_days for how many records need to be updated and @@date_counter which rotates from the changed date
until the current date.These counters enable the statement to update each record until today. First IF is to start the sequence if the new record date isn't today's date. 
Also, determines if activiation is required by checking if attributes affecting running totals are updated to maintain optimal server performance.
Second IF keeps the update happening until the trigger reaches today. REGEXP = 'World' location result. */
BEGIN TRANSACTION;
CREATE TRIGGER CS.world_record_updates
AFTER INSERT, UPDATE ON death_samples
FOR EACH ROW
BEGIN
	SET @@total_days SMALLINT = DATEDIFF(CURDATE(),NEW.date)
	SET @@date_counter date = NEW.date
	WHILE @@total_days>0
		IF CURDATE()!=NEW.date AND @@date_counter=NEW.date AND death_samples.new_cases!=NEW.new_cases OR death_samples.new_deaths!=NEW.new_deaths THEN
			UPDATE death_samples SET date=NEW.date, location=NEW.location, population=MAX(population), total_cases=SUM(new_cases), total_deaths=SUM(new_deaths)
			WHERE location REGEXP '^[W][o-q][l-r]{2}[d]$' AND date BETWEEN NEW.date AND CURDATE()
			SET @@total_days = @@total_days - 1
			SET @@date_counter = DATEADD(day, 1, @@date_counter);
		ELSE
				UPDATE death_samples SET date=@@date_counter, location=NEW.location, population=MAX(population), total_cases=SUM(new_cases), total_deaths=SUM(new_deaths)
				WHERE location REGEXP '^[^A-VX-Z]%*[l-r]{2}*' AND date BETWEEN NEW.date AND CURDATE()
				SET @@total_days = @@total_days - 1
				SET @@date_counter = DATEADD(day, 1, @@date_counter);
END IF;
COMMIT TRANSACTION;

BEGIN TRANSACTION;
CREATE TRIGGER CS.world_record_updates
AFTER DELETE ON death_samples
FOR EACH ROW
BEGIN
	SET @@total_days SMALLINT = DATEDIFF(CURDATE(),OLD.date)
	SET @@date_counter date = OLD.date
	WHILE @@total_days>0
		IF CURDATE()!=OLD.date AND @@date_counter=OLD.date AND death_samples.new_cases!=OLD.new_cases OR death_samples.new_deaths!=OLD.new_deaths THEN
			UPDATE death_samples SET date=OLD.date, location=OLD.location, population=MAX(population), total_cases=SUM(new_cases), total_deaths=SUM(new_deaths)
			WHERE location REGEXP '^[W][o-q][l-r]{2}[d]$' AND date BETWEEN OLD.date AND CURDATE()
			SET @@total_days = @@total_days - 1
			SET @@date_counter = DATEADD(day, 1, @@date_counter);
		ELSE
				UPDATE death_samples SET date=@@date_counter, location=OLD.location, population=MAX(population), total_cases=SUM(new_cases), total_deaths=SUM(new_deaths)
				WHERE location REGEXP '^[^A-VX-Z]%*[l-r]{2}*' AND date BETWEEN OLD.date AND CURDATE()
				SET @@total_days = @@total_days - 1
				SET @@date_counter = DATEADD(day, 1, @@date_counter);
END IF;
COMMIT TRANSACTION;


/* SECOND SECTION: Employing data mining tactics to gather evidence for drawing conclusions about the impact of COVID worldwide.

Monthly totals and grand total. Calculates total days and years COVID has been afflicting the population. Smooth attributes used to include a minorly inaccurate 
(<2%), yet precise totals & grand total - doubles as a method of reducing randomness and error in gathered evidence. */
BEGIN TRANSACTION;
SELECT month_digit, CONVERT(BIGINT,SUM(new_cases_smoothed)) AS totalCases, CONVERT(BIGINT,SUM(new_deaths_smoothed)) AS totalDead, (SELECT COUNT(DAY(date)) 
FROM death_samples WHERE total_cases!=0 AND location LIKE 'Wor%') AS totalDaysWithCOVID,(SELECT COUNT(DISTINCT YEAR) FROM death_samples 
WHERE total_cases!=0 AND location LIKE '_orl_') AS totalYearsWithCOVID
FROM death_samples WHERE location LIKE 'W___d' GROUP BY month_digit WITH ROLLUP ORDER BY month_digit;
COMMIT TRANSACTION;

-- Total vaccinations and people vaccinated. Percentage of vaccinations utlized, population fully vaccinated, and boosters.
BEGIN TRANSACTION;
SELECT ds.location, MAX(total_vaccinations) AS totalVaccinations, MAX(people_vaccinated) AS totalPeopleVaccinated, 
	ROUND(MAX(people_vaccinated)/NULLIF(MAX(total_vaccinations)-MAX(total_boosters),0)*100, 2) AS percentVaccinationsUtilized,
	CAST(MAX(people_fully_vaccinated)/NULLIF(MAX(people_vaccinated),0)*100 AS DECIMAL(4,2)) AS percentFullyVaccinated,
	CAST(MAX(total_boosters)/NULLIF(MAX(total_vaccinations),0)*100 AS DECIMAL(4,2)) AS percentBoostersOfVaccinations
FROM vaccination_samples vs RIGHT OUTER JOIN death_samples ds ON ds.location = vs.location WHERE ds.location LIKE '%rld'
GROUP BY ds.location;
COMMIT TRANSACTION;

-- Monthly, yearly, and overall totals for infections & deaths.
BEGIN TRANSACTION;
SELECT location, FLOOR(SUM(new_deaths_smoothed)) AS totalDeaths, CAST(SUM(new_cases_smoothed) AS INT) AS totalInfected, 
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyDeaths,
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT year),0) AS yearlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT year),0) AS yearlyDeaths
FROM death_samples WHERE location LIKE '__rld' GROUP BY location 
COMMIT TRANSACTION;

-- Population impact statistics. Percentages are included to determine death and infection toll. Mortality rate of those who experience death after infection.
BEGIN TRANSACTION;
SELECT location, population, CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/MAX(population)*100) AS percentOfPopulationDead, 
	CONVERT(DECIMAL(4,2),SUM(new_cases_smoothed)/MAX(population)*100) AS percentOfPopulationInfected, 
	CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/NULLIF(SUM(new_cases_smoothed),0)*10) AS mortalityRate
FROM death_samples WHERE location='World' GROUP BY location, population;
COMMIT TRANSACTION;
GO



/* THIRD SECTION: Employing data mining tactics to gather evidence for drawing conclusions about the impact of COVID in relation to income tiers.
Included are 3 tiers: High, Upper Middle, Lower Middle, Low. The corresponding data is more limited compared to other categories.

Total vaccinations & boosters, people vaccinated, and people fully vaccinated. 
Percentage of vaccinations utlized, population fully vaccinated, and boosters. */
BEGIN TRANSACTION;
SELECT ds.location, MAX(total_vaccinations) AS totalVaccinations, MAX(people_vaccinated) AS totalPeopleVaccinated, MAX(people_fully_vaccinated) AS totalPeopleFullyVaccinated,
	MAX(total_boosters) AS totalBoosters, ROUND(MAX(people_vaccinated)/NULLIF(MAX(total_vaccinations)-MAX(total_boosters),0)*100, 2) AS percentVaccinationsUtilized,
	CAST(MAX(people_fully_vaccinated)/NULLIF(MAX(people_vaccinated),0)*100 AS DECIMAL(4,2)) AS percentFullyVaccinated,
	CAST(MAX(total_boosters)/NULLIF(MAX(total_vaccinations),0)*100 AS DECIMAL(4,2)) AS percentBoostersOfVaccinations
FROM vaccination_samples vs RIGHT OUTER JOIN death_samples ds ON ds.location = vs.location WHERE ds.location LIKE '%income%'
GROUP BY ds.location ORDER BY totalPeopleVaccinated DESC;
COMMIT TRANSACTION;

-- Monthly, yearly, and overall totals. Population attribute doesn't have grand total, which is dissimlar to the others. Total dead & total infected measured.
BEGIN TRANSACTION;
SELECT location, MAX(population) AS population_no_grandtotal, FLOOR(SUM(new_deaths_smoothed)) AS totalDeaths, CAST(SUM(new_cases_smoothed) AS INT) AS totalInfected, 
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT month_digit),0) AS monthlyDeaths,
	ROUND(SUM(new_cases_smoothed)/COUNT(DISTINCT year),0) AS yearlyInfections, ROUND(SUM(new_deaths_smoothed)/COUNT(DISTINCT year),0) AS yearlyDeaths
FROM death_samples WHERE location LIKE '%income%' GROUP BY location WITH ROLLUP ORDER BY totalInfected DESC;
COMMIT TRANSACTION;


-- Population impact statistics. Percentages are included to determine an income tiers's death and infection toll. Mortality rate of those who experience death after infection.
BEGIN TRANSACTION;
SELECT location, MAX(population) AS population, CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/MAX(population)*100) AS percentOfPopulationDead, 
	CONVERT(DECIMAL(4,2),SUM(new_cases_smoothed)/MAX(population)*100) AS percentOfPopulationInfected, 
	CONVERT(DECIMAL(4,2),SUM(new_deaths_smoothed)/NULLIF(SUM(new_cases_smoothed),0)*10) AS mortalityRate
FROM death_samples WHERE location LIKE '%income%' GROUP BY location, population ORDER BY mortalityRate DESC;
COMMIT TRANSACTION;
GO
