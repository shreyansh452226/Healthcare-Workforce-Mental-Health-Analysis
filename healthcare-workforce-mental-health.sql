-- Healthcare workforce mental health analysis

-- Setup: database + table ------------------------------------------
SET GLOBAL local_infile = 1;
USE healthcaredb;

DROP TABLE IF EXISTS healthcare_data;
CREATE TABLE healthcare_data (
    Employee_ID            VARCHAR(20) PRIMARY KEY,
    Employee_Type          VARCHAR(50),
    Department             VARCHAR(50),
    Workplace_Factor       VARCHAR(50),
    Stress_Level           INT,
    Burnout_Frequency      VARCHAR(20),
    Job_Satisfaction       INT,
    Access_to_EAPs         VARCHAR(5),
    Mental_Health_Absences INT,
    Turnover_Intention     VARCHAR(5)
);

-- Load the CSV (change the path if your file is elsewhere)
-- @t strips the hidden \r that Windows adds at the end of each line
LOAD DATA LOCAL INFILE 'C:/Users/Dell/Downloads/Healthcare_Workforce_Mental_Health_Dataset.csv'
INTO TABLE healthcare_data
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(Employee_ID, Employee_Type, Department, Workplace_Factor, Stress_Level,
 Burnout_Frequency, Job_Satisfaction, Access_to_EAPs, Mental_Health_Absences, @t)
SET Turnover_Intention = TRIM(TRAILING '\r' FROM @t);

SELECT COUNT(*) AS rows_loaded FROM healthcare_data;   -- should be 5000

-- Basic questions ---------------------------------------------------

-- 1-2. Total employees, employee types, departments
SELECT COUNT(*) AS employees FROM healthcare_data;
SELECT DISTINCT Employee_Type FROM healthcare_data ORDER BY 1;
SELECT DISTINCT Department FROM healthcare_data ORDER BY 1;

-- 3-5. Average stress, "Often" burnout count, EAP access split
SELECT ROUND(AVG(Stress_Level), 2) AS avg_stress FROM healthcare_data;
SELECT COUNT(*) AS often_burnout FROM healthcare_data WHERE Burnout_Frequency = 'Often';
SELECT Access_to_EAPs, COUNT(*) AS emp_count FROM healthcare_data GROUP BY Access_to_EAPs;

-- 6-8. Lowest satisfaction, absence range, employees planning to leave
SELECT * FROM healthcare_data WHERE Job_Satisfaction = 1;
SELECT MAX(Mental_Health_Absences) AS max_absences, MIN(Mental_Health_Absences) AS min_absences FROM healthcare_data;
SELECT COUNT(*) AS turnover_yes FROM healthcare_data WHERE Turnover_Intention = 'Yes';

-- Intermediate questions --------------------------------------------

-- 9. Average stress by department
SELECT Department, ROUND(AVG(Stress_Level), 2) AS avg_stress
FROM healthcare_data GROUP BY Department ORDER BY avg_stress DESC;

-- 10. Department with the highest job satisfaction
SELECT Department, ROUND(AVG(Job_Satisfaction), 2) AS avg_satisfaction
FROM healthcare_data GROUP BY Department ORDER BY avg_satisfaction DESC LIMIT 1;

-- 11. Top workplace factors among high-stress staff (stress >= 7)
SELECT Workplace_Factor, COUNT(*) AS occurrence
FROM healthcare_data WHERE Stress_Level >= 7
GROUP BY Workplace_Factor ORDER BY occurrence DESC LIMIT 5;

-- 12. Employee type with the most mental health absences
SELECT Employee_Type, ROUND(AVG(Mental_Health_Absences), 2) AS avg_absences
FROM healthcare_data GROUP BY Employee_Type ORDER BY avg_absences DESC LIMIT 1;

-- 13. % of "Often" burnout employees who want to leave
SELECT ROUND(100 * SUM(Turnover_Intention = 'Yes') / COUNT(*), 2) AS pct_intent_to_leave
FROM healthcare_data WHERE Burnout_Frequency = 'Often';

-- 14. Job satisfaction with vs. without EAP access
SELECT Access_to_EAPs, ROUND(AVG(Job_Satisfaction), 2) AS avg_satisfaction
FROM healthcare_data GROUP BY Access_to_EAPs;

-- 15. Departments where more than 20% want to leave
SELECT Department, ROUND(100 * SUM(Turnover_Intention = 'Yes') / COUNT(*), 2) AS pct_employee
FROM healthcare_data GROUP BY Department
HAVING pct_employee > 20 ORDER BY pct_employee DESC;

-- 16. Absences by burnout frequency
SELECT Burnout_Frequency, ROUND(AVG(Mental_Health_Absences), 2) AS avg_absences
FROM healthcare_data GROUP BY Burnout_Frequency ORDER BY avg_absences DESC;

-- Advanced questions ------------------------------------------------

-- 17. Rank departments by average stress
SELECT Department, ROUND(AVG(Stress_Level), 2) AS average_stress,
       RANK() OVER (ORDER BY AVG(Stress_Level) DESC) AS stress_rank
FROM healthcare_data GROUP BY Department;

-- 18. Risk category from stress + burnout
SELECT risk_category, COUNT(*) AS emp_count
FROM (SELECT CASE WHEN Stress_Level >= 8 AND Burnout_Frequency = 'Often' THEN 'High risk'
                  WHEN Stress_Level >= 6 AND Burnout_Frequency IN ('Often', 'Occasionally') THEN 'Moderate risk'
                  ELSE 'Low risk' END AS risk_category
      FROM healthcare_data) AS t
GROUP BY risk_category ORDER BY emp_count DESC;

-- 19. CTE: top 3 workplace factors linked to turnover
WITH factor_turnover AS (
    SELECT Workplace_Factor, COUNT(*) AS total_employees,
           SUM(Turnover_Intention = 'Yes') AS turnover_yes
    FROM healthcare_data GROUP BY Workplace_Factor
)
SELECT *, ROUND(100 * turnover_yes / total_employees, 2) AS pct_turnover
FROM factor_turnover ORDER BY pct_turnover DESC LIMIT 3;

-- 20. % per employee type with no EAP access and high stress
SELECT Employee_Type,
       ROUND(100 * SUM(Access_to_EAPs = 'No' AND Stress_Level >= 7) / COUNT(*), 2) AS pct
FROM healthcare_data GROUP BY Employee_Type ORDER BY pct DESC;

-- 21. Departments with satisfaction below the overall average
SELECT Department, ROUND(AVG(Job_Satisfaction), 2) AS avg_satisfaction
FROM healthcare_data GROUP BY Department
HAVING AVG(Job_Satisfaction) < (SELECT AVG(Job_Satisfaction) FROM healthcare_data)
ORDER BY avg_satisfaction;

-- 22. Absence rank of each employee within their department
SELECT Employee_ID, Department, Mental_Health_Absences,
       RANK() OVER (PARTITION BY Department ORDER BY Mental_Health_Absences DESC) AS absence_rank_dept
FROM healthcare_data;

-- 23. Absence quartiles vs. job satisfaction
WITH quartiles AS (
    SELECT Job_Satisfaction, Mental_Health_Absences,
           NTILE(4) OVER (ORDER BY Mental_Health_Absences) AS absence_quartile
    FROM healthcare_data
)
SELECT absence_quartile, ROUND(AVG(Job_Satisfaction), 2) AS avg_satisfaction,
       ROUND(AVG(Mental_Health_Absences), 2) AS avg_absences
FROM quartiles GROUP BY absence_quartile ORDER BY absence_quartile;

-- 24. At-risk employees by department (high stress, often burnt out, no EAP, wants to leave)
SELECT Department, COUNT(*) AS at_risk_count
FROM healthcare_data
WHERE Stress_Level >= 7 AND Burnout_Frequency = 'Often'
  AND Access_to_EAPs = 'No' AND Turnover_Intention = 'Yes'
GROUP BY Department ORDER BY at_risk_count DESC;

-- Business insights -------------------------------------------------

-- 25. Does missing EAP access link to burnout and turnover?
SELECT Access_to_EAPs, Burnout_Frequency,
       ROUND(100 * SUM(Turnover_Intention = 'Yes') / COUNT(*), 2) AS pct_turnover,
       COUNT(*) AS employee_count
FROM healthcare_data GROUP BY Access_to_EAPs, Burnout_Frequency
ORDER BY Access_to_EAPs, Burnout_Frequency;

-- 26. Which workplace factor best predicts turnover?
SELECT Workplace_Factor,
       ROUND(100 * SUM(Turnover_Intention = 'Yes') / COUNT(*), 2) AS pct_turnover,
       COUNT(*) AS sample_size
FROM healthcare_data GROUP BY Workplace_Factor ORDER BY pct_turnover DESC;

-- 27. Where to expand EAP first (high stress, high absences, no EAP)
SELECT Department, Employee_Type,
       ROUND(AVG(Stress_Level), 2) AS avg_stress,
       ROUND(AVG(Mental_Health_Absences), 2) AS avg_absences,
       ROUND(100 * SUM(Access_to_EAPs = 'No') / COUNT(*), 2) AS pct_no_eap,
       COUNT(*) AS employee_count
FROM healthcare_data GROUP BY Department, Employee_Type
HAVING pct_no_eap > 0
ORDER BY avg_stress DESC, pct_no_eap DESC LIMIT 10;

-- 28. Job satisfaction vs. mental health absences
SELECT Job_Satisfaction, ROUND(AVG(Mental_Health_Absences), 2) AS avg_absences, COUNT(*) AS employee_count
FROM healthcare_data GROUP BY Job_Satisfaction ORDER BY Job_Satisfaction;