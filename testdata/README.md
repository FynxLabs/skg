# SKG Conformance Test Fixtures

Shared test fixtures for validating SKG parser implementations across languages.
Every parser implementation must pass all fixtures.

## Structure

- `valid/` — Valid `.skg` files with paired `.expected.json` describing the expected AST
- `invalid/` — Invalid `.skg` files with paired `.expected.json` describing the expected error

## Expected JSON Format

### Valid fixtures

```json
{
  "skg_version": "1.0",
  "schema_version": "1.0.0",
  "imports": ["./other.skg"],
  "children": [
    {
      "type": "field",
      "key": "name",
      "value": { "type": "string", "data": "hello" }
    },
    {
      "type": "block",
      "name": "theme",
      "children": [...]
    }
  ]
}
```

Value types in JSON:
- `{"type": "string", "data": "hello"}` — string
- `{"type": "int", "data": 42}` — integer
- `{"type": "float", "data": 1.5}` — float
- `{"type": "bool", "data": true}` — boolean
- `{"type": "null"}` — null
- `{"type": "array", "element_type": "string", "data": [...]}` — array (items are value objects)

Null fields (`skg_version`, `schema_version`) are omitted or set to `null` in JSON.

### Invalid fixtures

```json
{
  "error": true,
  "message_contains": "unterminated string"
}
```
