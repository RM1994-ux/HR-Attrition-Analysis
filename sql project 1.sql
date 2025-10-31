USE hr_database;

LOAD DATA LOCAL INFILE 'C:/Users/sumit/Downloads/HR_comma_sep.csv'
INTO TABLE hr_data
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM hr_data;   -- to see total rows
SELECT * FROM hr_data LIMIT 10; -- preview first 10 rows

-- Show specific columns
SELECT satisfaction_level, salary FROM hr_data;

-- Show more columns
SELECT number_project, time_spend_company, left_ FROM hr_data;

-- Combine WHERE condition
SELECT satisfaction_level, salary FROM hr_data
WHERE left_ = 1;

-- Sort results

SELECT satisfaction_level, salary FROM hr_data;

SELECT number_project, time_spend_company, left_ FROM hr_data;

SELECT satisfaction_level, salary FROM hr_data
ORDER BY satisfaction_level DESC
LIMIT 10;

SHOW TABLES;
-- Step 1: Enable local_infile globally
SET GLOBAL local_infile = 1;

-- Step 2: Verify
SELECT * FROM hr_data LIMIT 10;
DESCRIBE hr_data;

SELECT COUNT(*) AS total_rows FROM hr_data;

SELECT
  SUM(CASE WHEN TRIM(satisfaction_level) = '' OR satisfaction_level IS NULL THEN 1 ELSE 0 END) AS sat_null,
  SUM(CASE WHEN TRIM(last_evaluation) = '' OR last_evaluation IS NULL THEN 1 ELSE 0 END) AS eval_null,
  SUM(CASE WHEN TRIM(number_project) = '' OR number_project IS NULL THEN 1 ELSE 0 END) AS proj_null,
  SUM(CASE WHEN TRIM(average_montly_hours) = '' OR average_montly_hours IS NULL THEN 1 ELSE 0 END) AS hours_null,
  SUM(CASE WHEN TRIM(time_spend_company) = '' OR time_spend_company IS NULL THEN 1 ELSE 0 END) AS time_null,
  SUM(CASE WHEN TRIM(sales) = '' OR sales IS NULL THEN 1 ELSE 0 END) AS sales_null
FROM hr_data;

SELECT sales, salary, COUNT(*) AS cnt
FROM hr_data
GROUP BY sales, salary
ORDER BY cnt DESC
LIMIT 20;

DROP TABLE IF EXISTS hr_clean;

CREATE TABLE hr_clean (
  id INT AUTO_INCREMENT PRIMARY KEY,
  satisfaction_level DECIMAL(4,3),
  last_evaluation DECIMAL(4,3),
  number_project INT,
  average_monthly_hours INT,
  time_spend_company INT,
  work_accident TINYINT,
  left_flag TINYINT,
  promotion_last_5years TINYINT,
  department VARCHAR(100),
  salary_tier VARCHAR(20)
);

INSERT INTO hr_clean (
  satisfaction_level, last_evaluation, number_project, average_monthly_hours,
  time_spend_company, work_accident, left_flag, promotion_last_5years,
  department, salary_tier
)
SELECT
  NULLIF(TRIM(satisfaction_level),'') + 0.0 AS satisfaction_level,
  NULLIF(TRIM(last_evaluation),'') + 0.0 AS last_evaluation,
  CAST(NULLIF(TRIM(number_project),'') AS SIGNED) AS number_project,
  CAST(NULLIF(TRIM(average_montly_hours),'') AS SIGNED) AS average_monthly_hours,
  CAST(NULLIF(TRIM(time_spend_company),'') AS SIGNED) AS time_spend_company,
  CAST(NULLIF(TRIM(Work_accident),'') AS SIGNED) AS work_accident,
  CAST(NULLIF(TRIM(left_),'') AS SIGNED) AS left_flag,
  CAST(NULLIF(TRIM(promotion_last_5years),'') AS SIGNED) AS promotion_last_5years,
  TRIM(sales) AS department,
  LOWER(TRIM(salary)) AS salary_tier
FROM hr_data;


DROP TABLE IF EXISTS dept_lookup;

CREATE TABLE dept_lookup AS
SELECT DISTINCT department AS dept_name FROM hr_clean;

ALTER TABLE hr_clean ADD COLUMN dept_id INT NULL;
### Clean HR employee dataset with normalized fields


-- Create id mapping
ALTER TABLE dept_lookup ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY FIRST;
### Department lookup table 


-- Update hr_clean with dept_id
UPDATE hr_clean h
JOIN dept_lookup d ON h.department = d.dept_name
SET h.dept_id = d.id;

SET SQL_SAFE_UPDATES = 0;



UPDATE hr_clean h
JOIN dept_lookup d 
  ON h.department = d.dept_name
SET h.dept_id = d.id;

SELECT department, dept_id FROM hr_clean LIMIT 10;

CREATE INDEX idx_dept_id ON hr_clean(dept_id);
CREATE INDEX idx_left_flag ON hr_clean(left_flag);

DROP VIEW IF EXISTS v_hr_summary_by_dept;

CREATE VIEW v_hr_summary_by_dept AS
SELECT
  department,
  COUNT(*) AS total_employees,
  SUM(left_flag) AS total_left,
  ROUND(SUM(left_flag)/COUNT(*)*100, 2) AS attrition_pct,
  ROUND(AVG(satisfaction_level),3) AS avg_satisfaction,
  ROUND(AVG(last_evaluation),3) AS avg_evaluation,
  ROUND(AVG(average_monthly_hours),1) AS avg_hours
FROM hr_clean
GROUP BY department;

DROP VIEW IF EXISTS v_churn_by_salary;
CREATE VIEW v_churn_by_salary AS
SELECT
  salary_tier,
  COUNT(*) AS total,
  SUM(left_flag) AS left_count,
  ROUND(SUM(left_flag)/COUNT(*)*100, 2) AS attrition_pct
FROM hr_clean
GROUP BY salary_tier;

DROP TABLE IF EXISTS top_risk_employees;
CREATE TABLE top_risk_employees AS
SELECT id, satisfaction_level, last_evaluation, number_project, average_monthly_hours,
       time_spend_company, department, salary_tier, left_flag
FROM hr_clean
WHERE average_monthly_hours > 250 AND satisfaction_level < 0.4
ORDER BY satisfaction_level ASC
LIMIT 100;

SELECT (SELECT COUNT(*) FROM hr_data) AS raw_rows, (SELECT COUNT(*) FROM hr_clean) AS clean_rows;

SELECT * FROM v_hr_summary_by_dept ORDER BY attrition_pct DESC LIMIT 10;

SELECT COUNT(*) AS high_risk FROM top_risk_employees;

SELECT * FROM hr_clean;

SELECT COUNT(*) AS total_rows
FROM hr_clean;

SHOW COLUMNS FROM hr_clean;

SELECT
    SUM(CASE WHEN id IS NULL THEN 1 END) AS null_id,
    SUM(CASE WHEN satisfaction_level IS NULL THEN 1 END) AS null_satisfaction_level,
    SUM(CASE WHEN last_evaluation IS NULL THEN 1 END) AS null_last_evaluation,
    SUM(CASE WHEN number_project IS NULL THEN 1 END) AS null_number_project,
    SUM(CASE WHEN average_monthly_hours IS NULL THEN 1 END) AS null_avg_monthly_hours,
    SUM(CASE WHEN time_spend_company IS NULL THEN 1 END) AS null_time_spend_company,
    SUM(CASE WHEN work_accident IS NULL THEN 1 END) AS null_work_accident,
    SUM(CASE WHEN left_flag IS NULL THEN 1 END) AS null_left_flag,
    SUM(CASE WHEN promotion_last_5years IS NULL THEN 1 END) AS null_promotion_last_5years,
    SUM(CASE WHEN department IS NULL THEN 1 END) AS null_department,
    SUM(CASE WHEN salary_tier IS NULL THEN 1 END) AS null_salary_tier,
    SUM(CASE WHEN dept_id IS NULL THEN 1 END) AS null_dept_id
FROM hr_clean;

SELECT id, COUNT(*) AS count
FROM hr_clean
GROUP BY id
HAVING COUNT(*) > 1;

SELECT 
  COUNT(*) AS total,
  SUM(left_flag) AS total_left,
  ROUND(SUM(left_flag)/COUNT(*)*100,2) AS attrition_rate,
  COUNT(DISTINCT department) AS dept_count,
  COUNT(DISTINCT salary_tier) AS salary_levels
FROM hr_clean;
 
 ALTER TABLE hr_clean ADD UNIQUE (id);

 









 







