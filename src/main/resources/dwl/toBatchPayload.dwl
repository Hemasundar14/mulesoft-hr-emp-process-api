%dw 2.0
output application/json
---
payload map ((item) -> {
    employee_id: item.employeeId,
    first_name: item.firstName,
    last_name: item.lastName,
    date_of_birth: item.dateOfBirth,
    date_of_joining: item.dateOfJoining,
    official_email: item.officialEmail,
    mobile: item.mobile,
    department_key: item.departmentKey,
    designation: item.designation,
    grade: item.grade,
    location_key: item.locationKey,
    employment_type: upper(item.employmentType),
    manager_key: if (isEmpty(item.managerId)) null else item.managerId,
    employee_status: "ACTIVE",
    source_run_id: vars.runId
})
