SELECT * FROM cbsa;
SELECT * FROM drug;
SELECT * FROM fips_county; --47065
SELECT * FROM overdose_deaths;
SELECT * FROM population;
SELECT * FROM zip_fips LIMIT 500;
SELECT * FROM prescriber LIMIT 10000;
SELECT * FROM prescription LIMIT 10000;

-- 1. 
--      a. Which prescriber had the highest total number of claims (totaled over all drugs)? Report the npi and the total number of claims.		1881634483 (bruce pendley suspect)

SELECT npi, SUM(total_claim_count) AS total_claims
FROM prescription
GROUP BY npi
ORDER BY total_claims DESC
LIMIT 2;

--      b. Repeat the above, but this time report the nppes_provider_first_name, nppes_provider_last_org_name,  specialty_description, and the total number of claims.

SELECT SUM(total_claim_count) AS total_claims, nppes_provider_first_name, nppes_provider_last_org_name, specialty_description
FROM prescriber
JOIN prescription USING (npi)
GROUP BY nppes_provider_first_name, nppes_provider_last_org_name, specialty_description
ORDER BY total_claims DESC;

-- 2. 
--     a. Which specialty had the most total number of claims (totaled over all drugs)?		famiy practice

SELECT SUM(total_claim_count) AS total_claims, specialty_description
FROM prescription JOIN drug USING (drug_name)
	JOIN prescriber ON prescriber.npi = prescription.npi
GROUP BY specialty_description
ORDER BY total_claims DESC;

--     b. Which specialty had the most total number of claims for opioids?

SELECT SUM(total_claim_count) AS opioid_claim_count, specialty_description
FROM prescription JOIN drug USING (drug_name)
	JOIN prescriber ON prescriber.npi = prescription.npi
	WHERE drug.opioid_drug_flag = 'Y'
GROUP BY specialty_description
ORDER BY opioid_claim_count DESC;

--drugs not listed in prescription table
(SELECT drug_name FROM drug WHERE opioid_drug_flag = 'Y')
EXCEPT
(SELECT  drug_name FROM prescription);

--     c. **Challenge Question:** Are there any specialties that appear in the prescriber table that have no associated prescriptions in the prescription table?

(SELECT specialty_description FROM prescriber)
EXCEPT
(SELECT specialty_description FROM prescriber JOIN prescription USING (npi));

--     d. **Difficult Bonus:** *Do not attempt until you have solved all other problems!* For each specialty, report the percentage of total claims by that specialty which are for opioids. Which specialties have a high 	percentage of opioids?

SELECT SUM(total_claim_count) AS opioid_claims, specialty_description, ROUND((SUM(total_claim_count) / (SELECT SUM(total_claim_count) FROM prescription) * 100), 4) AS percent_claim  
FROM prescription
JOIN prescriber USING (npi)
WHERE drug_name IN (SELECt drug_name FROM drug WHERE opioid_drug_flag = 'Y')
GROUP BY specialty_description
ORDER BY opioid_claims DESC;

-- 3. 
--     a. Which drug (generic_name) had the highest total drug cost?

SELECT SUM(total_drug_cost) AS total_cost, generic_name
FROM drug JOIN prescription ON drug.drug_name = prescription.drug_name
WHERE drug.generic_name = prescription.drug_name
GROUP BY generic_name
ORDER BY total_cost DESC;

--     b. Which drug (generic_name) has the hightest total cost per day? **Bonus: Round your cost per day column to 2 decimal places. Google ROUND to see how this works.**

SELECT SUM(total_drug_cost) AS total_cost, 
	SUM(total_day_supply) AS total_supply, 
	ROUND(SUM(total_drug_cost) / SUM(total_day_supply), 2) AS cost_per_day, 
	generic_name
FROM drug JOIN prescription ON drug.drug_name = prescription.drug_name
WHERE drug.generic_name = prescription.drug_name
GROUP BY generic_name
ORDER BY cost_per_day DESC;

-- 4. 
--     a. For each drug in the drug table, return the drug name and then a column named 'drug_type' which says 'opioid' for drugs which have opioid_drug_flag = 'Y', says 'antibiotic' for those drugs which have antibiotic_drug_flag = 'Y', and says 'neither' for all other drugs.

SELECT drug_name,
	CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
		WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
		ELSE 'neither'
	END AS drug_type
FROM drug
ORDER BY drug_type DESC;

--     b. Building off of the query you wrote for part a, determine whether more was spent (total_drug_cost) on opioids or on antibiotics. Hint: Format the total costs as MONEY for easier comparision.

SELECT SUM(total_drug_cost::money) FROM prescription;

SELECT SUM(total_drug_cost::money) AS total_cost,
	CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
		WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
		ELSE 'neither'
	END AS drug_type
FROM drug
INNER JOIN prescription USING (drug_name)
GROUP BY drug_type
ORDER BY total_cost DESC;

--correct answer filtering on distinct drugs only
SELECT SUM(total_drug_cost::money) AS total_cost,
	CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
		WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
		ELSE 'neither'
	END AS drug_type
FROM (SELECT distinct drug_name, opioid_drug_flag, antibiotic_drug_flag FROM drug) AS distinct_drugs
	INNER JOIN prescription USING (drug_name)
GROUP BY drug_type
ORDER BY total_cost DESC;

-- 5. 
--     a. How many CBSAs are in Tennessee? **Warning:** The cbsa table contains information for all states, not just Tennessee.

SELECT *
FROM cbsa INNER JOIN fips_county ON fips_county.fipscounty = cbsa.fipscounty
WHERE fips_county.state = 'TN';


--     b. Which cbsa has the largest combined population? Which has the smallest? Report the CBSA name and total population. nashville/morristown

select SUM(population) AS total_population, c.cbsaname
FROM population AS p INNER JOIN cbsa AS c ON c.fipscounty = p.fipscounty
GROUP BY c.cbsaname
ORDER BY total_population DESC;

--     c. What is the largest (in terms of population) county which is not included in a CBSA? Report the county name and population.

SELECT SUM(population) AS total_pop, county
FROM fips_county INNER JOIN population ON population.fipscounty = fips_county.fipscounty
WHERE fips_county.fipscounty NOT IN (SELECT fipscounty FROM cbsa)
GROUP BY county
ORDER BY total_pop DESC;

-- 6. 
--     a. Find all rows in the prescription table where total_claims is at least 3000. Report the drug_name and the total_claim_count.

SELECT drug_name, total_claim_count
FROM prescription
WHERE total_claim_count >= 3000;

--     b. For each instance that you found in part a, add a column that indicates whether the drug is an opioid.

SELECT prescription.drug_name, total_claim_count, 
	CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
	ELSE 'non-opioid'
	END AS drug_type
FROM prescription
INNER JOIN drug ON drug.drug_name = prescription.drug_name
WHERE total_claim_count >= 3000
ORDER BY drug_type DESC;

--     c. Add another column to you answer from the previous part which gives the prescriber first and last name associated with each row.

SELECT prescription.drug_name, 
	total_claim_count, 
	nppes_provider_last_org_name, 
	nppes_provider_first_name,
		CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
		ELSE 'non-opioid'
		END AS drug_type
FROM prescription 
	INNER JOIN drug ON drug.drug_name = prescription.drug_name
	INNER JOIN prescriber ON prescriber.npi = prescription.npi
	WHERE total_claim_count >= 3000
ORDER BY drug_type DESC;

-- 7. The goal of this exercise is to generate a full list of all pain management specialists in Nashville and the number of claims they had for each opioid. **Hint:** The results from all 3 parts will have 637 rows.

--     a. First, create a list of all npi/drug_name combinations for pain management specialists (specialty_description = 'Pain Managment') in the city of Nashville (nppes_provider_city = 'NASHVILLE'), where the drug is an opioid (opiod_drug_flag = 'Y'). **Warning:** Double-check your query before running it. You will only need to use the prescriber and drug tables since you don't need the claims numbers yet.

SELECT drug.drug_name, npi
FROM prescriber
CROSS JOIN drug
WHERE drug.opioid_drug_flag = 'Y' AND specialty_description = 'Pain Management' AND nppes_provider_city = 'NASHVILLE';

--     b. Next, report the number of claims per drug per prescriber. Be sure to include all combinations, whether or not the prescriber had any claims. You should report the npi, the drug name, and the number of claims (total_claim_count).

SELECT drug.drug_name, npi, total_claim_count AS total_claims
FROM prescriber
	CROSS JOIN drug
	LEFT JOIN prescription USING (npi, drug_name)
WHERE drug.opioid_drug_flag = 'Y' 
	AND specialty_description = 'Pain Management' 
	AND nppes_provider_city = 'NASHVILLE'
ORDER BY total_claims DESC;
  
--     c. Finally, if you have not done so already, fill in any missing values for total_claim_count with 0. Hint - Google the COALESCE function.

SELECT drug.drug_name, npi, COALESCE(total_claim_count, 0) AS total_claims
FROM prescriber
	CROSS JOIN drug
	LEFT JOIN prescription USING (npi, drug_name)
WHERE drug.opioid_drug_flag = 'Y' 
	AND specialty_description = 'Pain Management' 
	AND nppes_provider_city = 'NASHVILLE'
ORDER BY total_claims DESC;



--BONUS--------------------------------------------------------------------------------------------

-- 1. How many npi numbers appear in the prescriber table but not in the prescription table? 4458

(SELECT npi FROM prescriber)
EXCEPT
(SELECT npi FROM prescription);


-- 2.
--     a. Find the top five drugs (generic_name) prescribed by prescribers with the specialty of Family Practice.

SELECT COUNT(drug_name) as number_prescribed, generic_name 
FROM prescription 
	INNER JOIN prescriber USING(npi) 
	INNER JOIN drug USING (drug_name) 
WHERE specialty_description = 'Family Practice' 
GROUP BY generic_name
ORDER BY number_prescribed DESC
LIMIT 5;


--     b. Find the top five drugs (generic_name) prescribed by prescribers with the specialty of Cardiology.

SELECT COUNT(drug_name) as number_prescribed, generic_name 
FROM prescription 
	INNER JOIN prescriber USING(npi) 
	INNER JOIN drug USING (drug_name) 
WHERE specialty_description = 'Cardiology' 
GROUP BY generic_name
ORDER BY number_prescribed DESC
LIMIT 5;

--     c. Which drugs are in the top five prescribed by Family Practice prescribers and Cardiologists? Combine what you did for parts a and b into a single query to answer this question.

SELECT COUNT(drug_name) as number_prescribed, generic_name 
FROM prescription 
	INNER JOIN prescriber USING(npi) 
	INNER JOIN drug USING (drug_name) 
WHERE specialty_description = 'Cardiology' OR specialty_description = 'Family Practice'
GROUP BY generic_name
ORDER BY number_prescribed DESC
LIMIT 5;

-- 3. 
-- Your goal in this question is to generate a list of the top prescribers in each of the major metropolitan areas of Tennessee.
--     a. First, write a query that finds the top 5 prescribers in Nashville in terms of the total number of claims (total_claim_count) across all drugs. Report the npi, the total number of claims, and include a column showing the city.
    
SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
FROM prescription
	INNER JOIN prescriber USING (npi)
	WHERE nppes_provider_city ILIKE '%NASHVILLE%'
GROUP BY nppes_provider_city, npi
ORDER BY total_claims DESC
LIMIT 5;
	
--     b. Now, report the same for Memphis.

SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
FROM prescription
	INNER JOIN prescriber USING (npi)
	WHERE nppes_provider_city ILIKE '%MEMPHIS%'
GROUP BY nppes_provider_city, npi
ORDER BY total_claims DESC
LIMIT 5;

--     c. Combine your results from a and b, along with the results for Knoxville and Chattanooga.

(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
	FROM prescription
	INNER JOIN prescriber USING (npi)
	WHERE nppes_provider_city ILIKE '%NASHVILLE%'
	GROUP BY nppes_provider_city, npi
	ORDER BY total_claims DESC
	LIMIT 5)
UNION
	(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
	FROM prescription
	INNER JOIN prescriber USING (npi)
	WHERE nppes_provider_city ILIKE '%MEMPHIS%'
	GROUP BY nppes_provider_city, npi
	ORDER BY total_claims DESC
	LIMIT 5)
UNION
	(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
	FROM prescription
	INNER JOIN prescriber USING (npi)
	WHERE nppes_provider_city ILIKE '%knoxville%'
	GROUP BY nppes_provider_city, npi
	ORDER BY total_claims DESC
	LIMIT 5)
UNION
	(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
	FROM prescription
	INNER JOIN prescriber USING (npi)
	WHERE nppes_provider_city ILIKE '%chattanooga%'
	GROUP BY nppes_provider_city, npi
	ORDER BY total_claims DESC
	LIMIT 5)
ORDER BY total_claims DESC;

-- 4. 
--Find all counties which had an above-average number of overdose deaths. Report the county name and number of overdose deaths.

SELECT ROUND(AVG(overdose_deaths), 2) AS average_od, county
FROM overdose_deaths AS od
	INNER JOIN fips_county AS fc ON fc.fipscounty::integer = od.fipscounty
	WHERE overdose_deaths > (SELECT AVG(overdose_deaths) FROM overdose_deaths)
GROUP BY county
ORDER BY average_od DESC;

-- 5.
--     a. Write a query that finds the total population of Tennessee.
    
SELECT SUM(population) AS total_TN_pop
FROM population
	INNER JOIN fips_county USING (fipscounty)
	WHERE fips_county.state = 'TN';
	
--add commas
SELECT TO_CHAR(SUM(population), '9,999,999,999') AS total_TN_pop
FROM population
	INNER JOIN fips_county USING (fipscounty)
	WHERE fips_county.state = 'TN';
	

--     b. Build off of the query that you wrote in part a to write a query that returns for each county that county's name, its population, and the percentage of the total population of Tennessee that is contained in that county.

--WITH percentpop AS 
SELECT county, 
	population, 
	ROUND((population / (SELECT SUM(population) FROM population) * 100), 3) AS percent_pop
FROM population
	INNER JOIN fips_county USING (fipscounty) 
	WHERE fips_county.state = 'TN' 
ORDER BY percent_pop DESC;

--sum all percentages together
--SELECT SUM(percentpop.percent_pop) FROM percentpop




--loops through all cities and get the top 5 prescribers
WITH ranked_prescribers AS (
  SELECT nppes_provider_city, npi, SUM(total_claim_count) AS total_count,
         ROW_NUMBER() OVER (PARTITION BY nppes_provider_city) AS rank
  FROM prescription
	INNER JOIN prescriber USING (npi)
	GROUP BY nppes_provider_city, npi
)
SELECT nppes_provider_city, npi, total_count
FROM ranked_prescribers
WHERE rank <= 5;
