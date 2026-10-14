%dw 2.0
output application/xml
---
employeeImportRejects: {
    header: {
        runId: vars.runId,
        sourceSystem: vars.sourceSystem default "HRMS-XML",
        generatedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
        rejectedCount: sizeOf(vars.invalidRecords default [])
    },
    employees: {
        ((vars.invalidRecords default []) map ((item) -> {
            employee: {
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
            }
        }))
    }
}
