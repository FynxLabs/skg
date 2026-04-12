package skg

import (
	"testing"
)

func TestParseSimple(t *testing.T) {
	src := []byte(`name: "hello"`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(f.Children) != 1 {
		t.Fatalf("expected 1 child, got %d", len(f.Children))
	}
	if f.Children[0].Field == nil {
		t.Fatal("expected field node")
	}
	if f.Children[0].Field.Key != "name" {
		t.Errorf("expected key 'name', got %q", f.Children[0].Field.Key)
	}
	if f.Children[0].Field.Value.Str != "hello" {
		t.Errorf("expected value 'hello', got %q", f.Children[0].Field.Value.Str)
	}
}

func TestParseAllTypes(t *testing.T) {
	src := []byte(`
str: "hello"
num: 42
neg: -7
pi: 3.14
yes: true
no: false
empty: null
`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(f.Children) != 7 {
		t.Fatalf("expected 7 children, got %d", len(f.Children))
	}

	check := func(idx int, key string, typ ValueType) {
		t.Helper()
		n := f.Children[idx]
		if n.Field == nil {
			t.Fatalf("child %d: expected field", idx)
		}
		if n.Field.Key != key {
			t.Errorf("child %d: expected key %q, got %q", idx, key, n.Field.Key)
		}
		if n.Field.Value.Type != typ {
			t.Errorf("child %d: expected type %v, got %v", idx, typ, n.Field.Value.Type)
		}
	}

	check(0, "str", TypeString)
	check(1, "num", TypeInt)
	check(2, "neg", TypeInt)
	check(3, "pi", TypeFloat)
	check(4, "yes", TypeBool)
	check(5, "no", TypeBool)
	check(6, "empty", TypeNull)
}

func TestParseBlock(t *testing.T) {
	src := []byte(`theme { accent: "green" }`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(f.Children) != 1 || f.Children[0].Block == nil {
		t.Fatal("expected block node")
	}
	b := f.Children[0].Block
	if b.Name != "theme" {
		t.Errorf("expected block name 'theme', got %q", b.Name)
	}
	if len(b.Children) != 1 || b.Children[0].Field == nil {
		t.Fatal("expected one field child")
	}
}

func TestParseArray(t *testing.T) {
	src := []byte(`tags: ["a", "b", "c"]`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	v := f.Children[0].Field.Value
	if v.Type != TypeArray {
		t.Fatalf("expected array, got %v", v.Type)
	}
	if len(v.Array.Items) != 3 {
		t.Fatalf("expected 3 items, got %d", len(v.Array.Items))
	}
	if v.Array.ElementType != TypeString {
		t.Errorf("expected string element type, got %v", v.Array.ElementType)
	}
}

func TestParseMixedArrayError(t *testing.T) {
	src := []byte(`bad: [1, "two"]`)
	_, err := Parse(src)
	if err == nil {
		t.Fatal("expected error for mixed array")
	}
	pe, ok := err.(*ParseError)
	if !ok {
		t.Fatalf("expected ParseError, got %T", err)
	}
	if pe.Diag.Message != "mixed types in array" {
		t.Errorf("unexpected message: %s", pe.Diag.Message)
	}
}

func TestParseVersions(t *testing.T) {
	src := []byte(`skg_version: "1.0"
schema_version: "2.0"
name: "test"
`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if f.SKGVersion == nil || *f.SKGVersion != "1.0" {
		t.Errorf("expected skg_version 1.0")
	}
	if f.SchemaVersion == nil || *f.SchemaVersion != "2.0" {
		t.Errorf("expected schema_version 2.0")
	}
}

func TestParseImports(t *testing.T) {
	src := []byte(`import ["./a.skg", "./b.skg"]
name: "test"
`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(f.ImportPaths) != 2 {
		t.Fatalf("expected 2 imports, got %d", len(f.ImportPaths))
	}
	if f.ImportPaths[0] != "./a.skg" || f.ImportPaths[1] != "./b.skg" {
		t.Errorf("unexpected imports: %v", f.ImportPaths)
	}
}

func TestParseSingleImport(t *testing.T) {
	src := []byte(`import "./base.skg"`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(f.ImportPaths) != 1 || f.ImportPaths[0] != "./base.skg" {
		t.Errorf("unexpected imports: %v", f.ImportPaths)
	}
}

func TestParseMultilineString(t *testing.T) {
	src := []byte(`desc: """hello
world"""`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if f.Children[0].Field.Value.Str != "hello\nworld" {
		t.Errorf("unexpected value: %q", f.Children[0].Field.Value.Str)
	}
}

func TestParseEscapedString(t *testing.T) {
	src := []byte(`msg: "hello\nworld"`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if f.Children[0].Field.Value.Str != "hello\nworld" {
		t.Errorf("unexpected value: %q", f.Children[0].Field.Value.Str)
	}
}

func TestParseComments(t *testing.T) {
	src := []byte(`# this is a comment
name: "test"
# another comment
`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(f.Children) != 1 {
		t.Fatalf("expected 1 child, got %d", len(f.Children))
	}
}

func TestParseDuplicateLastWins(t *testing.T) {
	src := []byte(`name: "first"
name: "second"
`)
	f, err := Parse(src)
	if err != nil {
		t.Fatal(err)
	}
	if len(f.Children) != 1 {
		t.Fatalf("expected 1 child after dedup, got %d", len(f.Children))
	}
	if f.Children[0].Field.Value.Str != "second" {
		t.Errorf("expected last-wins 'second', got %q", f.Children[0].Field.Value.Str)
	}
}

func TestMergeNodes(t *testing.T) {
	base := []Node{
		{Field: &Field{Key: "a", Value: Value{Type: TypeString, Str: "1"}}},
		{Field: &Field{Key: "b", Value: Value{Type: TypeString, Str: "2"}}},
	}
	overlay := []Node{
		{Field: &Field{Key: "b", Value: Value{Type: TypeString, Str: "3"}}},
		{Field: &Field{Key: "c", Value: Value{Type: TypeString, Str: "4"}}},
	}
	result := MergeNodes(base, overlay)
	if len(result) != 3 {
		t.Fatalf("expected 3 nodes, got %d", len(result))
	}
	if result[0].Field.Value.Str != "1" {
		t.Error("a should be unchanged")
	}
	if result[1].Field.Value.Str != "3" {
		t.Error("b should be overwritten to 3")
	}
	if result[2].Field.Value.Str != "4" {
		t.Error("c should be appended")
	}
}

func TestMergeBlocksRecursive(t *testing.T) {
	base := []Node{
		{Block: &Block{Name: "theme", Children: []Node{
			{Field: &Field{Key: "a", Value: Value{Type: TypeString, Str: "1"}}},
		}}},
	}
	overlay := []Node{
		{Block: &Block{Name: "theme", Children: []Node{
			{Field: &Field{Key: "b", Value: Value{Type: TypeString, Str: "2"}}},
		}}},
	}
	result := MergeNodes(base, overlay)
	if len(result) != 1 || result[0].Block == nil {
		t.Fatal("expected 1 block")
	}
	if len(result[0].Block.Children) != 2 {
		t.Fatalf("expected 2 children, got %d", len(result[0].Block.Children))
	}
}

func TestEmitRoundTrip(t *testing.T) {
	src := `name: "hello"
count: 42
pi: 3.14
flag: true
empty: null
tags: ["a", "b"]
`
	f, err := Parse([]byte(src))
	if err != nil {
		t.Fatal(err)
	}
	out := string(Emit(f))
	f2, err := Parse([]byte(out))
	if err != nil {
		t.Fatalf("re-parse failed: %v", err)
	}
	if len(f2.Children) != len(f.Children) {
		t.Errorf("round-trip changed child count: %d → %d", len(f.Children), len(f2.Children))
	}
}

func TestEmitBlockIndent(t *testing.T) {
	src := `theme {
  accent: "green"
}
`
	f, err := Parse([]byte(src))
	if err != nil {
		t.Fatal(err)
	}
	out := string(Emit(f))
	if out != src {
		t.Errorf("expected:\n%s\ngot:\n%s", src, out)
	}
}

func TestUnmarshal(t *testing.T) {
	type Theme struct {
		Accent string `skg:"accent"`
		Size   int64  `skg:"size"`
	}
	type Config struct {
		Name  string  `skg:"name"`
		Theme Theme   `skg:"theme"`
		Tags  []string `skg:"tags"`
	}

	src := []byte(`
name: "test"
theme {
  accent: "blue"
  size: 14
}
tags: ["a", "b"]
`)
	var cfg Config
	if err := Unmarshal(src, &cfg); err != nil {
		t.Fatal(err)
	}
	if cfg.Name != "test" {
		t.Errorf("expected name 'test', got %q", cfg.Name)
	}
	if cfg.Theme.Accent != "blue" {
		t.Errorf("expected accent 'blue', got %q", cfg.Theme.Accent)
	}
	if cfg.Theme.Size != 14 {
		t.Errorf("expected size 14, got %d", cfg.Theme.Size)
	}
	if len(cfg.Tags) != 2 || cfg.Tags[0] != "a" {
		t.Errorf("unexpected tags: %v", cfg.Tags)
	}
}

func TestUnmarshalNullable(t *testing.T) {
	type Config struct {
		Name  *string `skg:"name"`
		Value *string `skg:"value"`
	}
	src := []byte(`name: "test"
value: null
`)
	var cfg Config
	if err := Unmarshal(src, &cfg); err != nil {
		t.Fatal(err)
	}
	if cfg.Name == nil || *cfg.Name != "test" {
		t.Errorf("expected name 'test'")
	}
	if cfg.Value != nil {
		t.Errorf("expected value nil, got %v", *cfg.Value)
	}
}

func TestMarshalRoundTrip(t *testing.T) {
	type Config struct {
		Name  string   `skg:"name"`
		Count int64    `skg:"count"`
		Tags  []string `skg:"tags"`
	}

	orig := Config{Name: "test", Count: 42, Tags: []string{"a", "b"}}
	data, err := Marshal(orig)
	if err != nil {
		t.Fatal(err)
	}

	var got Config
	if err := Unmarshal(data, &got); err != nil {
		t.Fatal(err)
	}
	if got.Name != orig.Name || got.Count != orig.Count {
		t.Errorf("round-trip mismatch: %+v vs %+v", orig, got)
	}
	if len(got.Tags) != 2 || got.Tags[0] != "a" || got.Tags[1] != "b" {
		t.Errorf("tags mismatch: %v", got.Tags)
	}
}

func TestMarshalNested(t *testing.T) {
	type Inner struct {
		Color string `skg:"color"`
	}
	type Config struct {
		Theme Inner `skg:"theme"`
	}
	data, err := Marshal(Config{Theme: Inner{Color: "red"}})
	if err != nil {
		t.Fatal(err)
	}
	out := string(data)
	expected := "theme {\n  color: \"red\"\n}\n"
	if out != expected {
		t.Errorf("expected:\n%s\ngot:\n%s", expected, out)
	}
}

func TestParseErrorDiagnostic(t *testing.T) {
	src := []byte(`name`)
	_, err := Parse(src)
	if err == nil {
		t.Fatal("expected error")
	}
	pe, ok := err.(*ParseError)
	if !ok {
		t.Fatalf("expected ParseError, got %T", err)
	}
	if pe.Diag.Line == 0 {
		t.Error("expected non-zero line in diagnostic")
	}
	if pe.Diag.Message == "" {
		t.Error("expected non-empty message")
	}
}
