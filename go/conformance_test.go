package skg

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Conformance tests: validate Go parser against shared testdata/ fixtures.

type expectedFile struct {
	SKGVersion    *string        `json:"skg_version"`
	SchemaVersion *string        `json:"schema_version"`
	Imports       []string       `json:"imports"`
	Children      []expectedNode `json:"children"`
}

type expectedNode struct {
	Type     string         `json:"type"`     // "field" or "block"
	Key      string         `json:"key"`      // field key
	Name     string         `json:"name"`     // block name
	Value    *expectedValue `json:"value"`    // field value
	Children []expectedNode `json:"children"` // block children
}

type expectedValue struct {
	Type        string          `json:"type"` // "string", "int", "float", "bool", "null", "array"
	Data        json.RawMessage `json:"data"`
	ElementType string          `json:"element_type"`
}

type expectedError struct {
	Error           bool   `json:"error"`
	MessageContains string `json:"message_contains"`
}

func testdataDir() string {
	// testdata/ is one level up from go/
	return filepath.Join("..", "testdata")
}

func TestConformanceValid(t *testing.T) {
	dir := filepath.Join(testdataDir(), "valid")
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("cannot read valid fixtures dir: %v", err)
	}

	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".skg") {
			continue
		}
		name := strings.TrimSuffix(e.Name(), ".skg")
		t.Run(name, func(t *testing.T) {
			skgPath := filepath.Join(dir, e.Name())
			jsonPath := filepath.Join(dir, name+".expected.json")

			skgData, err := os.ReadFile(skgPath)
			if err != nil {
				t.Fatal(err)
			}
			jsonData, err := os.ReadFile(jsonPath)
			if err != nil {
				t.Fatal(err)
			}

			var expected expectedFile
			if err := json.Unmarshal(jsonData, &expected); err != nil {
				t.Fatalf("bad expected JSON: %v", err)
			}

			file, err := Parse(skgData)
			if err != nil {
				t.Fatalf("parse failed: %v", err)
			}

			// Compare skg_version
			if expected.SKGVersion == nil {
				if file.SKGVersion != nil {
					t.Errorf("expected skg_version nil, got %q", *file.SKGVersion)
				}
			} else {
				if file.SKGVersion == nil || *file.SKGVersion != *expected.SKGVersion {
					t.Errorf("skg_version: expected %q, got %v", *expected.SKGVersion, file.SKGVersion)
				}
			}

			// Compare schema_version
			if expected.SchemaVersion == nil {
				if file.SchemaVersion != nil {
					t.Errorf("expected schema_version nil, got %q", *file.SchemaVersion)
				}
			} else {
				if file.SchemaVersion == nil || *file.SchemaVersion != *expected.SchemaVersion {
					t.Errorf("schema_version: expected %q, got %v", *expected.SchemaVersion, file.SchemaVersion)
				}
			}

			// Compare imports
			if len(expected.Imports) != len(file.ImportPaths) {
				t.Errorf("imports: expected %d, got %d", len(expected.Imports), len(file.ImportPaths))
			} else {
				for i, imp := range expected.Imports {
					if file.ImportPaths[i] != imp {
						t.Errorf("import[%d]: expected %q, got %q", i, imp, file.ImportPaths[i])
					}
				}
			}

			// Compare children
			compareNodes(t, "", expected.Children, file.Children)
		})
	}
}

func TestConformanceInvalid(t *testing.T) {
	dir := filepath.Join(testdataDir(), "invalid")
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatalf("cannot read invalid fixtures dir: %v", err)
	}

	for _, e := range entries {
		if !strings.HasSuffix(e.Name(), ".skg") {
			continue
		}
		name := strings.TrimSuffix(e.Name(), ".skg")
		t.Run(name, func(t *testing.T) {
			skgPath := filepath.Join(dir, e.Name())
			jsonPath := filepath.Join(dir, name+".expected.json")

			skgData, err := os.ReadFile(skgPath)
			if err != nil {
				t.Fatal(err)
			}
			jsonData, err := os.ReadFile(jsonPath)
			if err != nil {
				t.Fatal(err)
			}

			var expected expectedError
			if err := json.Unmarshal(jsonData, &expected); err != nil {
				t.Fatalf("bad expected JSON: %v", err)
			}

			_, parseErr := Parse(skgData)
			if parseErr == nil {
				t.Fatal("expected parse error, got success")
			}

			if expected.MessageContains != "" {
				if !strings.Contains(parseErr.Error(), expected.MessageContains) {
					t.Errorf("error %q does not contain %q", parseErr.Error(), expected.MessageContains)
				}
			}
		})
	}
}

func compareNodes(t *testing.T, path string, expected []expectedNode, actual []Node) {
	t.Helper()
	if len(expected) != len(actual) {
		t.Errorf("%schildren count: expected %d, got %d", path, len(expected), len(actual))
		return
	}
	for i, en := range expected {
		an := actual[i]
		prefix := fmt.Sprintf("%s[%d].", path, i)

		switch en.Type {
		case "field":
			if an.Field == nil {
				t.Errorf("%sexpected field, got block", prefix)
				continue
			}
			if an.Field.Key != en.Key {
				t.Errorf("%skey: expected %q, got %q", prefix, en.Key, an.Field.Key)
			}
			if en.Value != nil {
				compareValue(t, prefix+"value.", *en.Value, an.Field.Value)
			}

		case "block":
			if an.Block == nil {
				t.Errorf("%sexpected block, got field", prefix)
				continue
			}
			if an.Block.Name != en.Name {
				t.Errorf("%sname: expected %q, got %q", prefix, en.Name, an.Block.Name)
			}
			compareNodes(t, prefix, en.Children, an.Block.Children)
		}
	}
}

func compareValue(t *testing.T, path string, expected expectedValue, actual Value) {
	t.Helper()

	// Map expected type string to ValueType
	var expectedType ValueType
	switch expected.Type {
	case "string":
		expectedType = TypeString
	case "int":
		expectedType = TypeInt
	case "float":
		expectedType = TypeFloat
	case "bool":
		expectedType = TypeBool
	case "null":
		expectedType = TypeNull
	case "array":
		expectedType = TypeArray
	default:
		t.Errorf("%sunknown expected type %q", path, expected.Type)
		return
	}

	if actual.Type != expectedType {
		t.Errorf("%stype: expected %v, got %v", path, expectedType, actual.Type)
		return
	}

	switch expected.Type {
	case "string":
		var s string
		if err := json.Unmarshal(expected.Data, &s); err != nil {
			t.Errorf("%scannot parse expected string data: %v", path, err)
			return
		}
		if actual.Str != s {
			t.Errorf("%svalue: expected %q, got %q", path, s, actual.Str)
		}

	case "int":
		var n float64 // JSON numbers are float64
		if err := json.Unmarshal(expected.Data, &n); err != nil {
			t.Errorf("%scannot parse expected int data: %v", path, err)
			return
		}
		if actual.Int != int64(n) {
			t.Errorf("%svalue: expected %d, got %d", path, int64(n), actual.Int)
		}

	case "float":
		var f float64
		if err := json.Unmarshal(expected.Data, &f); err != nil {
			t.Errorf("%scannot parse expected float data: %v", path, err)
			return
		}
		if math.Abs(actual.Float-f) > 1e-9 {
			t.Errorf("%svalue: expected %g, got %g", path, f, actual.Float)
		}

	case "bool":
		var b bool
		if err := json.Unmarshal(expected.Data, &b); err != nil {
			t.Errorf("%scannot parse expected bool data: %v", path, err)
			return
		}
		if actual.Bool != b {
			t.Errorf("%svalue: expected %v, got %v", path, b, actual.Bool)
		}

	case "null":
		// Nothing to compare

	case "array":
		if actual.Array == nil {
			t.Errorf("%sexpected array data, got nil", path)
			return
		}
		// Check element type
		var expectedElemType ValueType
		switch expected.ElementType {
		case "string":
			expectedElemType = TypeString
		case "int":
			expectedElemType = TypeInt
		case "float":
			expectedElemType = TypeFloat
		case "bool":
			expectedElemType = TypeBool
		case "array":
			expectedElemType = TypeArray
		case "null":
			expectedElemType = TypeNull
		}
		if actual.Array.ElementType != expectedElemType {
			t.Errorf("%selement_type: expected %v, got %v", path, expectedElemType, actual.Array.ElementType)
		}

		var items []expectedValue
		if err := json.Unmarshal(expected.Data, &items); err != nil {
			t.Errorf("%scannot parse expected array data: %v", path, err)
			return
		}
		if len(items) != len(actual.Array.Items) {
			t.Errorf("%sarray length: expected %d, got %d", path, len(items), len(actual.Array.Items))
			return
		}
		for i, item := range items {
			compareValue(t, fmt.Sprintf("%s[%d].", path, i), item, actual.Array.Items[i])
		}
	}
}
