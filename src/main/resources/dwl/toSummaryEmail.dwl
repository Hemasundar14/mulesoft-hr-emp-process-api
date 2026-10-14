%dw 2.0
output application/java

var sampleSize = (p('email.sampleSize') default "5") as Number
var invalid = vars.invalidRecords default []
var rejectSummary = (invalid groupBy ($.rejectCode default "UNKNOWN")) pluck ((items, code) -> {
    code: code,
    count: sizeOf(items)
})

var sampleCount = if (sizeOf(invalid) < sampleSize) sizeOf(invalid) else sampleSize
var sampleItems = if (sampleCount > 0) invalid[0 to (sampleCount - 1)] else []

var sampleRejects = sampleItems map ((item) -> 
    "- Row " ++ (item.recordIndex default 0 as String) ++ " - " ++ (item.employeeId default "N/A" as String) ++ " - " ++ (item.rejectReason default "" as String)
) joinBy "\n"

var summaryLines = rejectSummary map ((s) ->
    "- " ++ (s.code as String) ++ " - " ++ (s.count as String) ++ " record(s)"
) joinBy "\n"

var completedTime = now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"}
var startTime = vars.startedAt default completedTime
var currentStatus = vars.runStatus default "UNKNOWN"
var currentFileName = vars.fileName default "unknown"

var subject = "Employee Import " ++ currentStatus ++ " - " ++ currentFileName

var body = 
"Dear HR Administrator,\n\n" ++
"The employee import has completed with status " ++ currentStatus ++ ".\n\n" ++
"Run ID: " ++ (vars.runId default "N/A") ++ "\n" ++
"File Name: " ++ currentFileName ++ " (" ++ (vars.fileFormat default "CSV") ++ ")\n" ++
"Source System: " ++ (vars.sourceSystem default "HRMS") ++ "\n" ++
"Processing Window: " ++ startTime ++ " to " ++ completedTime ++ "\n\n" ++
"Record Summary\n" ++
"- Records declared : " ++ (if (vars.declaredCount != null) (vars.declaredCount as String) else "N/A") ++ "\n" ++
"- Records parsed   : " ++ ((vars.parsedCount default 0) as String) ++ "\n" ++
"- Records inserted : " ++ ((vars.insertedCount default 0) as String) ++ "\n" ++
"- Records updated  : " ++ ((vars.updatedCount default 0) as String) ++ "\n" ++
"- Records rejected : " ++ ((vars.rejectedCount default 0) as String) ++ " (" ++ (((vars.rejectPercent default 0.0) as Number) as String {format: "0.00"}) ++ "%)\n\n" ++
(if (sizeOf(rejectSummary) > 0)
    "Rejection Breakdown\n" ++ summaryLines ++ "\n\n"
else "") ++
(if (sizeOf(invalid) > 0)
    "Rejected Records (first " ++ (sampleSize as String) ++ ")\n" ++ sampleRejects ++ "\n\n"
else "") ++
(if (vars.rejectFilePath != null and !isEmpty(vars.rejectFilePath))
    "A reject file containing all failed records in the original format has been written to:\n" ++ vars.rejectFilePath ++ "\n\n" ++
    "Please correct the rejected records and resubmit only the reject file.\n" ++
    "The successfully loaded records do not need to be sent again.\n\n"
else "") ++
"Regards,\n" ++
"Employee Data Integration"

---
{
    subject: subject,
    body: body,
    completedAt: completedTime
}
