# Errors Faced & Technical Resolutions Guide
**HR Bulk Employee Import – MuleSoft 4 Solution**

During the end-to-end design, implementation, testing, and deployment of this solution, several complex challenges spanning Mule 4 runtime internals, DataWeave 2.0 nuances, MUnit 3.7 test harness mechanics, XML schema parsing, and Windows system-level file locking were encountered and systematically resolved.

---

## 1. Java Version Incompatibility (JDK 24 vs. JDK 17)

### Problem Description
When executing Maven builds (`mvn clean package`) or starting Mule runtime from PowerShell, the build failed immediately or threw bytecode verification errors:
```
[ERROR] Rule 0: org.apache.maven.enforcer.rules.version.RequireJavaVersion failed with message:
[ERROR] Detected JDK Version: 24 is not supported. Mule Runtime requires Java 17.
```

### Root Cause
The host machine’s global environment variables had `JAVA_HOME` set to Oracle JDK 24 (`C:\Program Files\Java\jdk-24`). Mule 4.12.0 and MUnit 3.7.3 strictly support Java 17 (specifically Eclipse Temurin 17 provided with Anypoint Studio tooling).

### Resolution
Scoped the command environment to use the Studio-bundled Temurin JDK 17 before invoking Maven:
```powershell
$env:JAVA_HOME = 'C:\AnypointStudio-7.28.0-win64\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
```

---

## 2. PowerShell Command Line Variable Pre-Expansion

### Problem Description
When executing composite commands via PowerShell (e.g., setting `$env:JAVA_HOME` and immediately using it in the same command line string), commands would fail or resolve `$env:JAVA_HOME` to an empty string.

### Root Cause
PowerShell string interpolation evaluates `$env:...` inside double-quoted blocks at parse time before subshell execution occurs. If not escaped or improperly chained, the child process receives a blank string.

### Resolution
Enclosed paths in single quotes or escaped PowerShell variable markers with backticks or semicolon-separated statements:
```powershell
$env:JAVA_HOME = 'C:\AnypointStudio-7.28.0-win64\AnypointStudio\plugins\org.mule.tooling.jdk.win32.x86_64_1.4.1'; $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"; mvn test ...
```

---

## 3. DataWeave `divideBy` Namespace Scoping Error

### Problem Description
During the batching flow in `hr-emp-process-api`, the transform message failed with:
```
Unable to resolve reference of: `divideBy`.
1| divideBy(vars.validRecords, p('batch.size') as Number)
   ^^^^^^^^
```

### Root Cause
In DataWeave 2.0, the `divideBy` array partitioning function is **not** available in the default core namespace. It resides inside the `dw::core::Arrays` module.

### Resolution
Added an explicit module import at the top of the DataWeave transformation header:
```dataweave
%dw 2.0
import dw::core::Arrays
output application/java
---
Arrays::divideBy(vars.validRecords default [], (p('batch.size') default 50 as Number))
```

---

## 4. DataWeave Mixed Data Type String Concatenation in Mule Loggers

### Problem Description
Mule logger components failed with DataWeave evaluation errors when concatenating strings with numbers or objects:
```
Cannot coerce Object ({runId: ...}) to String
```

### Root Cause
DataWeave expression loggers (`#[ ... ]`) without an explicit output directive default to `application/json` or coerce types strictly. Using the `++` operator on incompatible types (e.g., `String ++ Number`) triggers a runtime coercion exception.

### Resolution
Configured all complex log expressions with explicit `output text/plain` headers and String interpolation:
```xml
<logger level="INFO" doc:name="Log Batch" 
        message='#[output text/plain --- "[$(vars.runId)] Dispatched batch $(vars.batchIndex + 1) of $(sizeOf(vars.batches)) with $(sizeOf(payload)) records."]' />
```

---

## 5. Windows Text Encoding Artifacts in Notification Templates

### Problem Description
When generating the summary email file `C:\hr-import\notifications\<runId>_email.txt`, characters such as bullet points (`•`) and em-dashes (`–`) rendered as garbled characters (e.g., `â€¢` and `â€“`) on Windows.

### Root Cause
Windows text editors and PowerShell default to ANSI (Windows-1252) encoding when reading plain text files, corrupting multi-byte UTF-8 Unicode characters.

### Resolution
Replaced all Unicode bullets and special dashes in [`toSummaryEmail.dwl`](file:///C:/Users/shiva/AnypointStudio/studio-workspace/hr-emp-process-api/src/main/resources/dwl/toSummaryEmail.dwl) with standard ASCII characters (`- ` and `-`), ensuring pristine rendering across all operating systems.

---

## 6. Mule 4 `<file:listener>` Double Error Handler Triggering

### Problem Description
When processing a threshold-aborted file, the global error handler executed twice, attempting to move the file twice and causing:
```
org.mule.runtime.api.exception.MuleRuntimeException: Could not move file: file already exists or target directory locked.
```

### Root Cause
The `<file:listener>` inbound endpoint automatically triggers its own default error routing if an unhandled error bubbles up to the root flow. If the flow already executed `<file:move>` inside an internal error branch, the outer global handler attempted to move the now non-existent file again.

### Resolution
Configured an `<on-error-continue>` block within the `hr-emp-file-intake-flow` error handler to gracefully consume the event, finalize the run record, move the file to `error/`, and suppress secondary error propagation.

---

## 7. MUnit XML Schema Resolution (`mule-documentation.xsd`)

### Problem Description
MUnit test execution failed during application context deployment:
```
Caused by: org.xml.sax.SAXException: Can't resolve http://www.mulesoft.org/schema/mule/documentation/current/mule-documentation.xsd, A dependency or plugin might be missing
```

### Root Cause
In Mule 4, `xmlns:doc="http://www.mulesoft.org/schema/mule/documentation"` is an internal metadata/annotation namespace. It **does not have a physical XSD schema file** on the web. Including a schema location pair in `xsi:schemaLocation` causes the Xerces SAX parser to attempt to fetch a non-existent URL and fail the entire build.

### Resolution
Removed the documentation namespace URL pair from `xsi:schemaLocation` in [`hr-emp-process-api-test-suite.xml`](file:///C:/Users/shiva/AnypointStudio/studio-workspace/hr-emp-process-api/src/test/munit/hr-emp-process-api-test-suite.xml):
```xml
<!-- Corrected xsi:schemaLocation without documentation.xsd -->
xsi:schemaLocation="
    http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
    http://www.mulesoft.org/schema/mule/munit http://www.mulesoft.org/schema/mule/munit/current/mule-munit.xsd
    http://www.mulesoft.org/schema/mule/munit-tools http://www.mulesoft.org/schema/mule/munit-tools/current/mule-munit-tools.xsd
    http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">
```

---

## 8. MUnit Matcher DataWeave Namespace (`munit-tools:` vs `MunitTools::`)

### Problem Description
In MUnit assertions, test cases failed with:
```
Script 'munit-tools:containsString("...")' has errors:
    Unable to resolve reference of: `munit`. at 1 : 1
    Unable to resolve reference of: `containsString`. at 1 : 13
```

### Root Cause
`munit-tools` is an **XML tag prefix** (`<munit-tools:assert-that ... />`). Inside the `#[ ... ]` expression attribute, Mule executes DataWeave code. The DataWeave module provided by the MUnit Tools library is named **`MunitTools`** (PascalCase with `::`).

### Resolution
Updated all assertion expressions to use `MunitTools::`:
```xml
<!-- Before (Failed) -->
<munit-tools:assert-that expression="#[payload.body]" is='#[munit-tools:containsString("Dear HR Administrator,")]' />

<!-- After (Fixed & Passed) -->
<munit-tools:assert-that expression="#[payload.body]" is='#[MunitTools::containsString("Dear HR Administrator,")]' />
```

---

## 9. DataWeave XML Root Serialization Error in MUnit Assertions

### Problem Description
During MUnit testing of reject file generation, the test failed with:
```
org.mule.runtime.api.el.ExpressionExecutionException: Trying to output non-whitespace characters outside main element tree (in prolog or epilog), while writing Xml at .
```

### Root Cause
The variable `vars.xmlRejectPayload` contained an XML document. When evaluating:
`expression="#[vars.xmlRejectPayload.employeeImportRejects.employees.employee.rejectReason]"`
DataWeave extracted a plain text String (`"Employee age is below 18"`). Because the source context was XML, DataWeave attempted to serialize the resulting isolated string back as XML without enclosing root tags, violating XML grammar rules.

### Resolution
Enforced explicit `output application/java` serialization in the assertion expression so the result was returned as a standard Java String:
```xml
<munit-tools:assert-that doc:name="Assert XML has rejectReason" 
    expression="#[output application/java --- vars.xmlRejectPayload.employeeImportRejects.employees.employee.rejectReason as String]" 
    is="#[MunitTools::notNullValue()]" />
```

---

## 10. Windows File Locking During Standalone Hot Redeployment

### Problem Description
When copying newly packaged `.jar` files into `C:\mule-run\apps\`, PowerShell reported:
```
Remove-Item : Cannot remove item C:\mule-run\apps\hr-emp-process-api\repository\... The process cannot access the file because it is being used by another process.
```

### Root Cause
On Windows, active JVM processes hold strict mandatory OS locks on open `.jar` files and transaction logs (`queue-tx-log\tx1.log`). Attempting to recursively delete an exploded application folder while the Mule standalone runtime is running fails due to Windows file-locking semantics.

### Resolution
Leveraged Mule 4’s native hot-deployment mechanism:
* Do **not** manually delete internal exploded app directories.
* Instead, overwrite the root archive `.jar` directly in `C:\mule-run\apps\`.
* Mule’s file watcher detects the archive modification timestamp, safely triggers undeploy, cleans locks, explodes the new package, and re-initializes all flows automatically.
