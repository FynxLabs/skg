# SKG - Static Key Graph

## Config Language Specification

Version: 1.0
Extension: `.skg`
Status: Draft

---

## Overview

SKG (Static Key Graph) is a simple, hierarchical configuration language. It is designed to be human-readable, easy to extend, and unambiguous. There is one way to write each construct - no alternatives, no shortcuts, no implicit behavior.

SKG is not a general-purpose language. It has no variables, no templates, no expressions, no computation. It is structured data. The application consuming the config defines and validates the schema.

SKG was created for [dusk](https://github.com/fynxlabs/dusk) but is designed as a standalone library - nothing in the parser depends on dusk.

---

## File Structure

A `.skg` file consists of, in order:

1. An optional `skg_version` declaration
2. Zero or more `import` statements
3. An optional `schema_version` declaration
4. Zero or more blocks and fields

```go
skg_version: "1.0"

import [
  "./theme.skg",
  "./keybinds.skg",
]

schema_version: "1.0.0"

theme {
  accent: "green"
}
```

---

## Comments

Comments begin with `#` and run to the end of the line.

```go
# This is a comment
accent: "green"  # This is also a comment
```

---

## Whitespace

Whitespace (spaces, tabs, newlines) is not significant except as a separator between tokens. Indentation is conventional, not required.

---

## Load Order

Files are loaded top to bottom. Later values overwrite earlier values.

Imports are processed where they appear. The main config file always loads after all its imports, so it always wins.

```go
import "./theme.skg"    # loaded first
import "./keybinds.skg" # loaded second

theme {
  accent: "purple"  # overwrites whatever theme.skg set
}
```

If a block or field appears twice in the same file, the second occurrence overwrites the first. This is not an error - it is the user's responsibility.

---

## Imports

Imports load and merge one or more `.skg` files before continuing to parse the current file.

Single import:

```go
import "./theme.skg"
```

Multiple imports (ordered, top to bottom):

```go
import [
  "./theme.skg",
  "./keybinds.skg",
]
```

Import paths are relative to the file containing the import statement.

Circular imports are an error. The parser detects and rejects them.

---

## Value Types

There are five scalar value types and one collection type. The type is determined by syntax - no type annotations.

### Int

A whole number, positive or negative. No quotes.

```go
timeout: 5000
max_crashes: 3
weight: 400
```

### Float

A number with a decimal point. No quotes.

```go
opacity: 0.92
size_base: 13.0
fade_in_step: 0.03
```

A trailing zero after the decimal is required. `13` is an int. `13.0` is a float.

### Bool

Exactly `true` or `false`. No quotes.

```go
managed: true
vsync: false
```

### Null

The literal `null` represents an absent value. No quotes.

```go
background: null
```

Null is useful for explicitly unsetting an inherited value from an import.

### String

Any value that is not an int, float, bool, or null must be quoted with double quotes `"`.

```go
accent: "green"
position: "top"
family: "JetBrains Mono"
background: "#0d0d0d"
schema_version: "1.0.0"
```

Single quotes are not valid. Escape sequences within strings:

| Sequence | Meaning              |
| -------- | -------------------- |
| `\"`     | Literal double quote |
| `\\`     | Literal backslash    |
| `\n`     | Newline              |
| `\t`     | Tab                  |

### Multiline Strings

Triple-quoted strings (`"""..."""`) span multiple lines. No escape processing is performed inside triple-quoted strings — the content between the delimiters is taken literally.

```go
description: """This is a
multiline string that preserves
newlines exactly as written."""
```

### Array

An ordered list of values enclosed in `[ ]`, comma-separated. All elements must be the same type. Trailing comma is allowed.

```go
workspace_go: ["super+1", "super+2", "super+3"]

sizes: [8.0, 12.0, 16.0]
```

Arrays may be nested. All inner arrays must have the same element type:

```go
matrix: [[1, 2], [3, 4]]
```

Arrays may span multiple lines:

```go
import [
  "./theme.skg",
  "./keybinds.skg",
]
```

---

## Blocks

A block is a named scope containing fields and/or nested blocks. Blocks use `{ }`.

```go
theme {
  accent: "green"

  colors {
    background: "#0d0d0d"
  }
}
```

### Singleton Blocks

A singleton block has a fixed name defined by the schema. There is one of them.

```go
theme { }
keybinds { }
compositor { }
session { }
```

### Named Instance Blocks

A named instance block represents one item in a collection. The block name is the instance identifier. Instance names must be unique within their parent block.

Naming convention for ordered collections: `name_000`, `name_001`, `name_002`, etc. `_000` is always the primary instance.

```go
panel {
  panel_000 {
    position: "top"
  }
  panel_001 {
    position: "bottom"
  }
}
```

Named instance blocks are always wrapped in a parent container block:

```go
panel { ... }   # container
zone { ... }    # container
modules { ... } # container
```

### Module Blocks

Modules are named instance blocks where the block name is the module identifier - it references a built-in module or external plugin by name.

```go
modules {
  workspaces {}
  windowlist {}
  clock {
    format: "%a %b %d  %H:%M"
  }
}
```

Module blocks with no config may use `{}` on the same line.

### Block Arrays

A block array is an ordered list of anonymous blocks. The syntax is `name [ { ... } { ... } ]`.

```go
users [
  {
    name: "admin"
    sudo: true
    groups: ["wheel", "video"]
  }
  {
    name: "guest"
    sudo: false
    groups: ["users"]
  }
]
```

Each `{ }` entry in the array is an independent block with its own fields and nested blocks. Entries are ordered — position is significant. Commas between entries are optional.

Block arrays are distinct from scalar arrays (`[1, 2, 3]`). Scalar arrays appear as field values after a colon. Block arrays appear after an identifier without a colon, just like blocks.

When merging (via imports), a block array replaces the entire previous value — items are not merged individually.

Block arrays may also be written without a colon when the contents are scalar values. `tags ["alpha", "beta"]` is equivalent to `tags: ["alpha", "beta"]`.

---

## Fields

A field is a key-value pair. The key is an unquoted identifier. The value is one of the scalar types or an array.

```go
key: value
```

Keys may contain letters, digits, and underscores. Keys may not start with a digit.

```go
accent: "green"   # valid
size_base: 13.0   # valid
max-crashes: 3    # invalid - hyphens not allowed in keys
```

---

## SKG Version

`skg_version` declares which version of the SKG language spec this file uses. It is a quoted string.

```go
skg_version: "1.0"
```

If omitted, the latest version supported by the parser is assumed.

---

## Schema Version

`schema_version` declares which version of the consuming application's config schema this file targets. It is a string.

```go
schema_version: "1.0.0"
```

The consuming application is responsible for validating this value. SKG itself does not interpret it.

---

## Validation

SKG performs **syntactic validation** only:

- Correct token types
- Balanced braces
- Valid import paths
- No circular imports
- Arrays contain uniform types

**Semantic validation** - unknown fields, wrong types for a schema, missing required fields - is the responsibility of the consuming application. The application maps the parsed AST onto its own types and produces schema errors.

---

## AST

The parser produces a tree of nodes. Each node is one of:

| Node    | Contents                                       |
| ------- | ---------------------------------------------- |
| `File`       | skg_version, imports, schema_version, children |
| `Block`      | name, children                                 |
| `BlockArray` | name, items (each item is a list of children)  |
| `Field`      | key, value                                     |
| `Value`      | type (Int/Float/Bool/String/Null/Array), data  |

The consuming application walks this tree against its own type definitions to populate its config struct.

---

## Error Messages

Errors include the file path, line number, column, and a clear description.

```text
theme.skg:4:3 - expected value, found end of file
dusk.skg:12:1 - circular import: dusk.skg → theme.skg → dusk.skg
dusk.skg:7:12 - string value must be quoted: use "top" not top
```

---

## Full Example

```go
# dusk.skg - main config

skg_version: "1.0"

import [
  "./theme.skg",
  "./keybinds.skg",
]

schema_version: "1.0.0"

theme {
  accent: "green"

  colors {
    background:    "#0d0d0d"
    surface:       "#161616"
    border:        "#2a2a2a"
    border_active: "#3a3a3a"
    text:          "#e5e5e5"
    text_dim:      "#6b6b6b"
  }
}

panel {
  panel_000 {
    position: "top"
    opacity:  0.92
    height:   32.0

    zone {
      zone_000 {
        alignment: "start"
        grow:      false
        modules {
          workspaces {}
          windowlist {}
        }
      }
      zone_001 {
        alignment: "center"
        grow:      true
        modules {}
      }
      zone_002 {
        alignment: "end"
        grow:      false
        modules {
          tray {}
          audio {}
          clock {
            format: "%a %b %d  %H:%M"
          }
        }
      }
    }
  }
}

keybinds {
  launcher: "alt+space"
  terminal: "ctrl+t"
}

session {
  wm:             "openbox"
  startup_method: "systemd"
}

logging {
  level:          "info"
  max_size_mb:    5
  keep_rotations: 3
}
```
