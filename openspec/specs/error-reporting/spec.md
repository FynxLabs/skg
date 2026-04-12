# error-reporting Specification

## Purpose
TBD - created by archiving change parser-v02-improvements. Update Purpose after archive.
## Requirements
### Requirement: Structured parse error diagnostics
The parser SHALL return structured error information including file path, line number, column number, and a human-readable message for every parse failure.

#### Scenario: Error on malformed field
- **WHEN** input `key "value"` is parsed (missing colon)
- **THEN** the error includes path `"test.skg"`, line `1`, column `5`, and message containing `"expected ':'"` or equivalent

#### Scenario: Error on unclosed block
- **WHEN** input `theme {\n  accent: "green"\n` is parsed (missing closing brace)
- **THEN** the error includes the line/column of the opening brace or the EOF position, and a message mentioning the unclosed block

#### Scenario: Error on unterminated string
- **WHEN** input `key: "unterminated` is parsed
- **THEN** the error includes the line/column where the string began and a message about the missing closing quote

#### Scenario: Circular import error
- **WHEN** file A imports file B which imports file A
- **THEN** the error includes the file path and line of the import statement that created the cycle, and names both files in the message

