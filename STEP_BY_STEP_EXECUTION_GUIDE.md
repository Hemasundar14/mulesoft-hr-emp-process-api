# Step-by-Step Execution Guide
**HR Bulk Employee Import – API-Led Solution**

This guide provides exhaustive, reproducible instructions to configure, build, run, test, and verify the entire API-Led MuleSoft 4 solution from scratch.

---

## 1. Prerequisites & Environment Setup

Ensure the following system components are installed and operational:

| Dependency | Minimum Version | Verified Path / Port |
| :--- | :--- | :--- |
| **Java Development Kit** | Eclipse Temurin JDK 17 | `C:\AnypointStudio-7.28.0-win64\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1` |
| **Apache Maven** | 3.8+ / 3.9+ | Included in PATH / Studio plugin |
| **MySQL Database** | 8.0+ | Port `3306`, Credentials: `root / root` |
| **Mule Standalone** | 4.12.0 EE | `C:\mule-run` |
| **Work Directory** | Windows OS | `C:\hr-import\` |

### 1.1. Directory Structure Creation
Execute in PowerShell to ensure all operational intake directories exist:
```powershell
$dirs = @(
    "C:\hr-import\inbound",
    "C:\hr-import\archive",
    "C:\hr-import\reject",
    "C:\hr-import\error",
    "C:\hr-import\notifications",
    "C:\hr-import\test_files"
)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force }
}
```

---

## 2. Database Initialization (MySQL)

Connect to your local MySQL instance (`localhost:3306`) and execute the DDL script to create the schema, tables, and reference data:

```sql
CREATE DATABASE IF NOT EXISTS hr_import;
USE hr_import;

-- 1. Department Master
CREATE TABLE IF NOT EXISTS department_master (
    department_key INT AUTO_INCREMENT PRIMARY KEY,
    department_code VARCHAR(20) NOT NULL UNIQUE,
    department_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Location Master
CREATE TABLE IF NOT EXISTS location_master (
    location_key INT AUTO_INCREMENT PRIMARY KEY,
    location_code VARCHAR(20) NOT NULL UNIQUE,
    location_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Designation Master
CREATE TABLE IF NOT EXISTS designation_master (
    designation VARCHAR(100) PRIMARY KEY,
    grade VARCHAR(10) NOT NULL
);

-- 4. Import Runs Audit Table
CREATE TABLE IF NOT EXISTS employee_import_runs (
    run_id VARCHAR(50) PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_format VARCHAR(10) NOT NULL,
    file_checksum VARCHAR(64) NOT NULL,
    declared_count INT NULL,
    parsed_count INT NOT NULL DEFAULT 0,
    inserted_count INT NOT NULL DEFAULT 0,
    updated_count INT NOT NULL DEFAULT 0,
    rejected_count INT NOT NULL DEFAULT 0,
    reject_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    run_status ENUM('IN_PROGRESS','SUCCESS','PARTIAL_SUCCESS','ABORTED_THRESHOLD','FAILED','DUPLICATE_FILE','SUCCESS_EMPTY') NOT NULL,
    reject_file_path VARCHAR(500) NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL
);

-- 5. Operational Employees Table
CREATE TABLE IF NOT EXISTS employees (
    employee_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    date_of_joining DATE NOT NULL,
    official_email VARCHAR(150) NOT NULL UNIQUE,
    mobile VARCHAR(20) NOT NULL,
    department_key INT NOT NULL,
    designation VARCHAR(100) NOT NULL,
    grade VARCHAR(10) NOT NULL,
    location_key INT NOT NULL,
    employment_type ENUM('PERMANENT','CONTRACT','INTERN','TRAINEE') NOT NULL,
    manager_key VARCHAR(20) NULL,
    employee_status ENUM('ACTIVE','INACTIVE','PROBATION') DEFAULT 'ACTIVE',
    source_run_id VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_emp_dept FOREIGN KEY (department_key) REFERENCES department_master(department_key),
    CONSTRAINT fk_emp_loc FOREIGN KEY (location_key) REFERENCES location_master(location_key)
);

-- Seed Reference Masters
INSERT IGNORE INTO department_master (department_code, department_name, is_active) VALUES
('DEPT-ENG', 'Engineering', TRUE),
('DEPT-HR', 'Human Resources', TRUE),
('DEPT-FIN', 'Finance', TRUE);

INSERT IGNORE INTO location_master (location_code, location_name, is_active) VALUES
('LOC-CHN-01', 'Chennai OMR Campus', TRUE),
('LOC-BLR-02', 'Bangalore Manyata Tech Park', TRUE);

INSERT IGNORE INTO designation_master (designation, grade) VALUES
('HR Executive', 'G3'),
('Engineer', 'G4'),
('Finance Analyst', 'G4'),
('Senior Engineer', 'G5'),
('Manager', 'G6');
```

---

## 3. Building the Mule Applications

Open PowerShell and set `JAVA_HOME` to JDK 17 before triggering the Maven builds:

```powershell
$env:JAVA_HOME = 'C:\AnypointStudio-7.28.0-win64\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

# Build System API
mvn clean package -DskipTests -f "C:\Users\shiva\AnypointStudio\studio-workspace\hr-emp-db-sys-api\pom.xml"

# Build Process API
mvn clean package -DskipTests -f "C:\Users\shiva\AnypointStudio\studio-workspace\hr-emp-process-api\pom.xml"
```

---

## 4. Running the MUnit Test Suite

To run all automated unit tests and verify DataWeave mappings, validations, reject formats, and email generation:

```powershell
$env:JAVA_HOME = 'C:\AnypointStudio-7.28.0-win64\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

mvn test -f "C:\Users\shiva\AnypointStudio\studio-workspace\hr-emp-process-api\pom.xml"
```
**Expected Output**:
`[INFO] >> hr-emp-process-api-test-suite.xml test result: Tests: 5, Errors: 0, Failures: 0, Skipped: 0`  
`[INFO] BUILD SUCCESS`

---

## 5. Deploying and Running in Standalone Mule Runtime

### 5.1. Copy Application Packages to Runtime Apps Folder
```powershell
Copy-Item "C:\Users\shiva\AnypointStudio\studio-workspace\hr-emp-db-sys-api\target\hr-emp-db-sys-api-1.0.0-SNAPSHOT-mule-application.jar" -Destination "C:\mule-run\apps\hr-emp-db-sys-api.jar"
Copy-Item "C:\Users\shiva\AnypointStudio\studio-workspace\hr-emp-process-api\target\hr-emp-process-api-1.0.0-SNAPSHOT-mule-application.jar" -Destination "C:\mule-run\apps\hr-emp-process-api.jar"
```

### 5.2. Start Mule Runtime
If Mule is not running, launch it in console mode:
```powershell
$env:JAVA_HOME = 'C:\AnypointStudio-7.28.0-win64\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
C:\mule-run\bin\mule.bat console
```

### 5.3. Confirm Deployment in Logs
View the tail of the Mule log:
```powershell
Get-Content "C:\mule-run\logs\mule_ee.log" -Tail 30
```
Verify the success banners:
* `* Started app 'hr-emp-db-sys-api'`
* `* Started app 'hr-emp-process-api'`

---

## 6. System Health Check & Endpoint Verification

Run the following commands to confirm that both APIs respond correctly:

```powershell
# 1. Check System API Reference Data Endpoints
Invoke-RestMethod -Uri "http://localhost:8081/api/departments" -Method Get
Invoke-RestMethod -Uri "http://localhost:8081/api/locations" -Method Get
Invoke-RestMethod -Uri "http://localhost:8081/api/designations" -Method Get

# 2. Check Process API Status
Invoke-RestMethod -Uri "http://localhost:8082/import/process" -Method Get -ErrorAction SilentlyContinue
```

---

## 7. Step-by-Step Scenario Execution

### Scenario A: Automated CSV File Ingestion via Inbound Folder
Place a CSV file into `C:\hr-import\inbound\`:
```powershell
$csvData = @"
employeeId,firstName,lastName,dateOfBirth,dateOfJoining,officialEmail,mobile,departmentCode,designation,locationCode,employmentType,managerId
EMP40001,Rajesh,Kumar,1985-05-15,2026-10-01,rajesh.kumar@company.com,+91-9884011111,DEPT-ENG,Manager,LOC-CHN-01,PERMANENT,
EMP40002,Pooja,Iyer,1992-08-20,2026-10-05,pooja.iyer@company.com,+91-9884022222,DEPT-ENG,Engineer,LOC-CHN-01,PERMANENT,EMP40001
EMP40003,Child,User,2018-01-01,2026-10-05,child.user@company.com,+91-9884033333,DEPT-ENG,Engineer,LOC-CHN-01,PERMANENT,EMP40001
"@
Set-Content -Path "C:\hr-import\inbound\EMP_TEST_BATCH_A.csv" -Value $csvData -Encoding utf8
```
* **Observed Action**: Inbound listener picks up file within 10 seconds.
* **Outputs Generated**:
  * Input file archived to `C:\hr-import\archive\EMP_TEST_BATCH_A.csv`.
  * Rejects written to `C:\hr-import\reject\rejects_EMP_TEST_BATCH_A.csv` containing `EMP40003` with reason `Employee age (8) is below minimum required age of 18`.
  * Summary email written to `C:\hr-import\notifications\<runId>_email.txt`.
  * Valid records `EMP40001` and `EMP40002` inserted into MySQL `employees` table.

---

### Scenario B: XML Ingestion with Header Declaration
Submit an XML payload with a declared `<recordCount>`:
```powershell
$xmlData = @"
<?xml version="1.0" encoding="UTF-8"?>
<employeeImport>
    <header>
        <sourceSystem>HRMS-XML</sourceSystem>
        <recordCount>2</recordCount>
    </header>
    <employees>
        <employee>
            <employeeId>EMP50001</employeeId>
            <firstName>Siddharth</firstName>
            <lastName>Nair</lastName>
            <dateOfBirth>1991-03-10</dateOfBirth>
            <dateOfJoining>2026-10-01</dateOfJoining>
            <officialEmail>siddharth.nair@company.com</officialEmail>
            <mobile>+91-9884044444</mobile>
            <departmentCode>DEPT-FIN</departmentCode>
            <designation>Finance Analyst</designation>
            <locationCode>LOC-BLR-02</locationCode>
            <employmentType>PERMANENT</employmentType>
            <managerId></managerId>
        </employee>
        <employee>
            <employeeId>EMP50002</employeeId>
            <firstName>Kavita</firstName>
            <lastName>Rao</lastName>
            <dateOfBirth>1994-11-25</dateOfBirth>
            <dateOfJoining>2026-10-05</dateOfJoining>
            <officialEmail>kavita.rao@company.com</officialEmail>
            <mobile>+91-9884055555</mobile>
            <departmentCode>DEPT-XXX</departmentCode>
            <designation>Finance Analyst</designation>
            <locationCode>LOC-BLR-02</locationCode>
            <employmentType>PERMANENT</employmentType>
            <managerId>EMP50001</managerId>
        </employee>
    </employees>
</employeeImport>
"@
Set-Content -Path "C:\hr-import\inbound\EMP_TEST_BATCH_B.xml" -Value $xmlData -Encoding utf8
```
* **Observed Action**: Parsed 2 records; validated header count; `EMP50001` inserted; `EMP50002` rejected (`ERR_REF_DEPARTMENT_NOT_FOUND`).
* **Outputs Generated**:
  * XML Reject file generated in `C:\hr-import\reject\rejects_EMP_TEST_BATCH_B.xml` with `<rejectReason>`.
  * Summary email generated in `C:\hr-import\notifications\`.

---

### Scenario C: Forward Manager Reference Resolution
Test where a subordinate appears *before* their manager in the file:
```powershell
Copy-Item "C:\hr-import\test_files\test_forward_manager.csv" -Destination "C:\hr-import\inbound\test_forward_manager.csv"
```
* **Observed Action**: Subordinate (`EMP30002`) and Manager (`EMP30001`) both valid. Subordinate’s `manager_key` in the database is correctly populated with `EMP30001`. Status: `SUCCESS`.

---

### Scenario D: Rejection Threshold Abort Test (> 50% Invalid)
Test a batch with 75% invalid records:
```powershell
Copy-Item "C:\hr-import\test_files\test_threshold_abort.csv" -Destination "C:\hr-import\inbound\test_threshold_abort.csv"
```
* **Observed Action**:
  * Evaluates rejection rate = 75% ($> 50\%$).
  * Persistence is aborted; **zero** records written to `employees`.
  * Input file moved to `C:\hr-import\error\test_threshold_abort.csv`.
  * Reject file written to `C:\hr-import\reject\rejects_test_threshold_abort.csv`.
  * Run status marked `ABORTED_THRESHOLD` in `employee_import_runs`.
  * Abort email dispatched to `C:\hr-import\notifications\`.

---

### Scenario E: Duplicate File Detection
Re-submit the exact same file processed previously:
```powershell
Copy-Item "C:\hr-import\test_files\EMP_IMPORT_20260911.csv" -Destination "C:\hr-import\inbound\EMP_IMPORT_20260911.csv"
```
* **Observed Action**: Computes SHA-256; matches existing entry in `employee_import_runs`. Skips DB insert; archives file; marks run `DUPLICATE_FILE`.

---

## 8. Verifying Results & Output Data

### 8.1. Check Database Records via System API
```powershell
# Get single employee
Invoke-RestMethod -Uri "http://localhost:8081/api/employees/EMP40001" -Method Get

# Check run audit entry
Invoke-RestMethod -Uri "http://localhost:8081/api/import-runs?fileName=EMP_TEST_BATCH_A.csv" -Method Get
```

### 8.2. View Generated Reject File
```powershell
Get-Content "C:\hr-import\reject\rejects_EMP_TEST_BATCH_A.csv"
```

### 8.3. View Generated Notification Email
```powershell
Get-ChildItem "C:\hr-import\notifications" | Select-Object -Last 1 | Get-Content
```
