%dw 2.0
output application/json

var minAge = (p('validation.minAge') default "18") as Number
var toleranceDays = (p('validation.joiningToleranceDays') default "30") as Number
var allowedEmploymentTypes = ["PERMANENT", "CONTRACT", "FULL-TIME", "PART-TIME", "INTERN"]

var deptMap = (vars.departments default []) reduce ((d, acc={}) -> acc ++ { (d.department_code): d.department_key })
var locMap = (vars.locations default []) reduce ((l, acc={}) -> acc ++ { (l.location_code): l.location_key })
var desigMap = (vars.designations default []) reduce ((g, acc={}) -> acc ++ { (lower(trim(g.designation))): g.grade })

var dbEmployees = vars.existingEmployees default []
var dbEmpIds = dbEmployees map ($.employee_id)
var dbEmailMap = dbEmployees reduce ((e, acc={}) -> acc ++ { (lower(trim(e.official_email))): e.employee_id })

var records = vars.canonicalRecords default []
var fileEmpIds = records map ($.employeeId)
var allKnownEmpIds = (dbEmpIds ++ fileEmpIds) distinctBy $

var fileManagerMap = records reduce ((r, acc={}) -> acc ++ { (r.employeeId): r.managerId })
var idGroups = records groupBy ($.employeeId)
var emailGroups = records groupBy (lower($.officialEmail))

fun isValidEmail(email) = (email default "") matches /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
fun isValidMobile(mobile) = isEmpty(mobile) or ((mobile default "") matches /^\+?[0-9\s\-()]{7,20}$/)
fun isValidDate(dateStr) = (dateStr default "") matches /^\d{4}-\d{2}-\d{2}$/

fun getAge(dobStr) = do {
    var dob = dobStr as Date
    var cur = now() as Date
    var yDiff = cur.year - dob.year
    var hadBday = (cur.month > dob.month) or (cur.month == dob.month and cur.day >= dob.day)
    ---
    if (hadBday) yDiff else (yDiff - 1)
}

fun isFutureExceeded(dojStr) = do {
    var doj = dojStr as Date
    var cur = now() as Date
    var periodStr = "P" ++ (toleranceDays as String) ++ "D"
    var maxDate = cur + (periodStr as Period)
    ---
    doj > maxDate
}

var checkedRecords = records map ((emp, idx) -> do {
    var isDuplicateFileId = !isEmpty(emp.employeeId) and 
                            (sizeOf(idGroups[emp.employeeId] default []) > 1) and 
                            (emp.recordIndex != idGroups[emp.employeeId][0].recordIndex)
    
    var isDuplicateFileEmail = !isEmpty(emp.officialEmail) and 
                              (sizeOf(emailGroups[lower(emp.officialEmail)] default []) > 1) and 
                              (emp.recordIndex != emailGroups[lower(emp.officialEmail)][0].recordIndex)

    var missingField = if (isEmpty(emp.employeeId)) "employeeId"
                       else if (isEmpty(emp.firstName)) "firstName"
                       else if (isEmpty(emp.lastName)) "lastName"
                       else if (isEmpty(emp.dateOfBirth)) "dateOfBirth"
                       else if (isEmpty(emp.dateOfJoining)) "dateOfJoining"
                       else if (isEmpty(emp.officialEmail)) "officialEmail"
                       else if (isEmpty(emp.departmentCode)) "departmentCode"
                       else if (isEmpty(emp.locationCode)) "locationCode"
                       else if (isEmpty(emp.employmentType)) "employmentType"
                       else null

    var reject = if (missingField != null) {
        code: "ERR_REQ_MANDATORY_FIELD_MISSING",
        reason: "Missing mandatory field: " ++ missingField
    }
    else if (!isValidEmail(emp.officialEmail)) {
        code: "ERR_FMT_INVALID_EMAIL",
        reason: "Invalid email format: " ++ emp.officialEmail
    }
    else if (isDuplicateFileEmail or (dbEmailMap[lower(emp.officialEmail)] != null and dbEmailMap[lower(emp.officialEmail)] != emp.employeeId)) {
        code: "ERR_DUP_OFFICIAL_EMAIL",
        reason: "Official email '" ++ emp.officialEmail ++ "' is already assigned to another employee"
    }
    else if (!isValidMobile(emp.mobile)) {
        code: "ERR_FMT_INVALID_MOBILE",
        reason: "Invalid mobile number format: " ++ emp.mobile
    }
    else if (!isValidDate(emp.dateOfBirth)) {
        code: "ERR_FMT_INVALID_DOB",
        reason: "Unparseable date of birth: " ++ emp.dateOfBirth
    }
    else if (getAge(emp.dateOfBirth) < minAge) {
        code: "ERR_VAL_UNDERAGE",
        reason: "Employee age (" ++ (getAge(emp.dateOfBirth) as String) ++ ") is below minimum required age of " ++ (minAge as String)
    }
    else if (!isValidDate(emp.dateOfJoining)) {
        code: "ERR_FMT_INVALID_DOJ",
        reason: "Unparseable date of joining: " ++ emp.dateOfJoining
    }
    else if (isFutureExceeded(emp.dateOfJoining)) {
        code: "ERR_VAL_FUTURE_JOINING_DATE",
        reason: "Joining date '" ++ emp.dateOfJoining ++ "' exceeds allowed future tolerance of " ++ (toleranceDays as String) ++ " days"
    }
    else if (!(allowedEmploymentTypes contains upper(emp.employmentType))) {
        code: "ERR_VAL_INVALID_EMPLOYMENT_TYPE",
        reason: "Unsupported employment type: " ++ emp.employmentType
    }
    else if (deptMap[emp.departmentCode] == null) {
        code: "ERR_REF_DEPARTMENT_NOT_FOUND",
        reason: "Department '" ++ emp.departmentCode ++ "' does not exist in the department master"
    }
    else if (locMap[emp.locationCode] == null) {
        code: "ERR_REF_LOCATION_NOT_FOUND",
        reason: "Location '" ++ emp.locationCode ++ "' does not exist in the location master"
    }
    else if (desigMap[lower(trim(emp.designation))] == null) {
        code: "ERR_REF_DESIGNATION_NOT_FOUND",
        reason: "Designation '" ++ emp.designation ++ "' does not exist in the designation master"
    }
    else if (isDuplicateFileId) {
        code: "ERR_DUP_EMPLOYEE_ID_FILE",
        reason: "Duplicate employee identifier within file: " ++ emp.employeeId
    }
    else if (!isEmpty(emp.managerId)) (
        if (emp.managerId == emp.employeeId) {
            code: "ERR_REL_SELF_REPORTING",
            reason: "Employee cannot be their own manager: " ++ emp.employeeId
        }
        else if (fileManagerMap[emp.managerId] == emp.employeeId) {
            code: "ERR_REL_CIRCULAR_REPORTING",
            reason: "Circular reporting relationship detected between " ++ emp.employeeId ++ " and " ++ emp.managerId
        }
        else if (!(allKnownEmpIds contains emp.managerId)) {
            code: "ERR_REF_MANAGER_NOT_FOUND",
            reason: "Manager '" ++ emp.managerId ++ "' not found in existing employees or current file"
        }
        else null
    )
    else null

    ---
    emp ++ {
        departmentKey: deptMap[emp.departmentCode],
        locationKey: locMap[emp.locationCode],
        grade: desigMap[lower(trim(emp.designation))],
        isExistingInDb: dbEmpIds contains emp.employeeId,
        rejectCode: reject.code default null,
        rejectReason: reject.reason default null,
        isValid: (reject == null)
    }
})

---
{
    valid: checkedRecords filter ($.isValid == true),
    invalid: checkedRecords filter ($.isValid == false)
}
