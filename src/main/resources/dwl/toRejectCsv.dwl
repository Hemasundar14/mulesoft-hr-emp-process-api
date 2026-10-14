%dw 2.0
output application/csv
---
(vars.invalidRecords default []) map ((item) -> {
    employeeId: item.employeeId,
    firstName: item.firstName,
    lastName: item.lastName,
    dateOfBirth: item.dateOfBirth,
    dateOfJoining: item.dateOfJoining,
    officialEmail: item.officialEmail,
    mobile: item.mobile,
    departmentCode: item.departmentCode,
    designation: item.designation,
    locationCode: item.locationCode,
    employmentType: item.employmentType,
    managerId: item.managerId,
    rejectReason: item.rejectReason
})
