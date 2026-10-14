# HR Bulk Employee Import – Process API (`hr-emp-process-api`)

**2027 Nurture Partner Network (NPN) MuleSoft Hackathon Challenge – Cognizant**

---

## 📌 Overview
`hr-emp-process-api` is the core business orchestration API in an API-led MuleSoft 4 architecture. It automates high-volume ingestion of employee demographic data from multiple upstream formats (CSV and XML), validates and enriches records against corporate masters, resolves complex organizational hierarchies (forward manager references and circular loop detection), enforces a 50% rejection threshold abort guard, persists clean records via the System API in micro-batches, and produces audit trails, reject files, and executive notifications.

---

## 🚀 Key Features & Capabilities
1. **Multi-Format Ingestion**: Supports automated CSV file intake (`C:\hr-import\inbound\`) and XML ingestion with declared header count validation via HTTP (`POST /import/process`).
2. **Canonical Data Normalization**: Normalizes disparate inputs into a canonical schema via DataWeave 2.0.
3. **Multi-Rule Validation**:
   - Minimum Age $\ge 18$ years.
   - Date of Joining (DOJ) future tolerance $\le 30$ days.
   - Mandatory field completeness.
   - RFC-compliant email regex and international mobile formatting.
   - Allowed employment types (`PERMANENT`, `CONTRACT`, `INTERN`, `TRAINEE`).
4. **Master Data Enrichment**: Caches active reference data in-memory:
   - `departmentCode` $\rightarrow$ `department_key`
   - `locationCode` $\rightarrow$ `location_key`
   - `designation` $\rightarrow$ `grade`
5. **Forward Manager Reference & Cycle Detection**: Resolves reporting structures even when subordinates are defined *before* managers in the intake file, rejecting self-reporting and circular reporting loops.
6. **50% Rejection Threshold Guard**: Immediately halts persistence if $> 50\%$ of records fail validation (`ABORTED_THRESHOLD`), moves the file to `error/`, and sends an abort alert.
7. **Batched Persistence**: Dispatches clean records to the System API in configurable micro-batches (`batch.size=50`).
8. **Reject Files**: Produces reject files in the original schema (CSV/XML) containing exact `rejectReason` details in `C:\hr-import\reject\`.
9. **Executive Notifications**: Dispatches formatted summary emails matching the hackathon template to `C:\hr-import\notifications\`.
10. **Data Privacy**: Date of birth and mobile numbers are strictly protected and never leaked in log files or email bodies.

---

## 🧪 Automated Testing
Includes a comprehensive MUnit 3.7 test suite (`hr-emp-process-api-test-suite.xml`):
```powershell
mvn test
```
**Results**: 5/5 Unit Tests Passing (100% Green).

---

## 📖 Complete Documentation
- **[PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md)**: Full architecture, sequence diagrams, and canonical model.
- **[ERRORS_FACED_AND_RESOLUTIONS.md](ERRORS_FACED_AND_RESOLUTIONS.md)**: Detailed technical troubleshooting guide.
- **[STEP_BY_STEP_EXECUTION_GUIDE.md](STEP_BY_STEP_EXECUTION_GUIDE.md)**: End-to-end setup and test execution playbook.
- **[HLD_HR_Bulk_Employee_Import.md](HLD_HR_Bulk_Employee_Import.md)**: High-Level Design document.
