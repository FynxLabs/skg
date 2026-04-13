// Package skg implements a parser for the SKG (Static Key Group) configuration language.
//
// SKG is a simple hierarchical key-value format with nested blocks, typed values,
// and import support. It fills the gap between JSON (no comments), YAML (whitespace-sensitive),
// TOML (flat), and CUE (bloated).
//
// Use Unmarshal to decode SKG into Go structs using struct tags:
//
//	type Config struct {
//	    Name  string `skg:"name"`
//	    Theme struct {
//	        Accent string `skg:"accent"`
//	    } `skg:"theme"`
//	}
//
//	var cfg Config
//	err := skg.Unmarshal(data, &cfg)
package skg

// ValueType identifies the kind of value in an SKG field.
type ValueType int

const (
	TypeString ValueType = iota
	TypeInt
	TypeFloat
	TypeBool
	TypeNull
	TypeArray
)

func (t ValueType) String() string {
	switch t {
	case TypeString:
		return "string"
	case TypeInt:
		return "int"
	case TypeFloat:
		return "float"
	case TypeBool:
		return "bool"
	case TypeNull:
		return "null"
	case TypeArray:
		return "array"
	default:
		return "unknown"
	}
}

// Value represents a scalar or array value from a field assignment.
type Value struct {
	Type ValueType

	// Exactly one of these is populated based on Type.
	Str   string  // TypeString
	Int   int64   // TypeInt
	Float float64 // TypeFloat
	Bool  bool    // TypeBool
	Array *Array  // TypeArray
	// TypeNull uses no fields.
}

// Array is a typed array. All elements must be the same type (enforced by parser).
type Array struct {
	ElementType ValueType
	Items       []Value
}

// Field is a key-value pair: `key: value`
type Field struct {
	Key   string
	Value Value
	Line  int
	Col   int
}

// Block is a named scope: `name { children... }`
type Block struct {
	Name     string
	Children []Node
	Line     int
	Col      int
}

// BlockArray is a named list of blocks: `name [ { ... } { ... } ]`
// Each item is a list of child nodes representing one block entry.
type BlockArray struct {
	Name  string
	Items [][]Node
	Line  int
	Col   int
}

// Node is either a field, a block, or a block array.
type Node struct {
	// Exactly one is non-nil.
	Field      *Field
	Block      *Block
	BlockArray *BlockArray
}

// File is the parsed representation of a single .skg file.
type File struct {
	SKGVersion    *string  // skg_version: "1.0" - nil if absent
	SchemaVersion *string  // schema_version: "1.0.0" - nil if absent
	ImportPaths   []string // Raw import path strings
	Children      []Node
}

// Diagnostic contains structured error information from a parse failure.
type Diagnostic struct {
	Path    string
	Line    int
	Col     int
	Message string
}

// ParseError is returned when parsing fails. It implements the error interface
// and contains structured diagnostic information.
type ParseError struct {
	Diag Diagnostic
}

func (e *ParseError) Error() string {
	return e.Diag.Path + ":" + itoa(e.Diag.Line) + ":" + itoa(e.Diag.Col) + ": " + e.Diag.Message
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	buf := [20]byte{}
	i := len(buf)
	neg := n < 0
	if neg {
		n = -n
	}
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}
