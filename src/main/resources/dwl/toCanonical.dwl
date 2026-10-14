%dw 2.0
output application/json

var raw = payload
var isXml = vars.fileFormat == "XML"
var records = if (isXml) (
    if (raw.employeeImport != null and raw.employeeImport.employees != null) (
        (raw.employeeImport.employees.*employee default [])
    ) else []
) else (
    (raw default [])
)

var declaredCount = if (isXml) (
    if (raw.employeeImport != null and raw.employeeImport.header != null and raw.employeeImport.header.recordCount != null) (
        raw.employeeImport.header.recordCount as Number default null
    ) else null
) else null

var sourceSystem = if (isXml) (
    if (raw.employeeImport != null and raw.employeeImport.header != null and raw.employeeImport.header.sourceSystem != null) (
        raw.employeeImport.header.sourceSystem
    ) else "HRMS-XML"
) else "HRMS-CSV"

var generatedAt = if (isXml) (
    if (raw.employeeImport != null and raw.employeeImport.header != null and raw.employeeImport.header.generatedAt != null) (
        raw.employeeImport.header.generatedAt
    ) else (now() as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"})
) else (now() as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"})

---
{
    sourceSystem: sourceSystem,
    declaredCount: declaredCount,
    generatedAt: generatedAt,
    recordCount: sizeOf(records),
    records: records map ((emp, idx) -> {
        recordIndex: idx + 1,
        employeeId: trim(emp.employeeId default ""),
        firstName: trim(emp.firstName default ""),
        lastName: trim(emp.lastName default ""),
        dateOfBirth: trim(emp.dateOfBirth default ""),
        dateOfJoining: trim(emp.dateOfJoining default ""),
        officialEmail: trim(emp.officialEmail default ""),
        mobile: trim(emp.mobile default ""),
        departmentCode: trim(emp.departmentCode default ""),
        designation: trim(emp.designation default ""),
        locationCode: trim(emp.locationCode default ""),
        employmentType: trim(emp.employmentType default ""),
        managerId: trim(emp.managerId default "")
    })
}
