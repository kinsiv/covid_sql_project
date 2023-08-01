-- Removing the NULL values that persisted after a Power Query edit.
SELECT * FROM deaths WHERE continent IS NULL ORDER BY location;
UPDATE deaths SET continent='Africa' WHERE location='Africa' AND continent IS NULL;
UPDATE deaths SET continent='Asia' WHERE location='Asia' OR location='Oceania';
UPDATE deaths SET continent='Europe' WHERE location LIKE '%Europe%';
UPDATE deaths SET continent='North America' WHERE location='North America';
UPDATE deaths SET continent='South America' WHERE location='South America';

SELECT * FROM deaths WHERE location LIKE '%income' OR location='World';
UPDATE deaths SET continent='N/A' WHERE location LIKE '%income' OR location='World';

-- Removing timestamp from date attribute.
ALTER TABLE deaths ALTER COLUMN date DATE;

-- Creating a month digit column for queries.
ALTER TABLE deaths ADD month_digit TINYINT;
UPDATE deaths SET month_digit=MONTH(date);

-- Creating a year column for queries.
ALTER TABLE deaths ADD year TINYINT;
ALTER TABLE deaths ALTER COLUMN year SMALLINT;
UPDATE deaths SET year=YEAR(date);