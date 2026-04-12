package skg

import (
	"fmt"
	"reflect"
)

// Unmarshal parses SKG source bytes and decodes into a Go struct.
// The target must be a pointer to a struct. Fields are matched via `skg:"name"` tags.
func Unmarshal(data []byte, v interface{}) error {
	file, err := Parse(data)
	if err != nil {
		return err
	}
	return decodeNodes(file.Children, reflect.ValueOf(v))
}

// UnmarshalFile reads an SKG file from disk and decodes into a Go struct.
func UnmarshalFile(path string, v interface{}) error {
	file, err := ParseFile(path)
	if err != nil {
		return err
	}
	return decodeNodes(file.Children, reflect.ValueOf(v))
}

func decodeNodes(nodes []Node, target reflect.Value) error {
	if target.Kind() == reflect.Ptr {
		if target.IsNil() {
			target.Set(reflect.New(target.Type().Elem()))
		}
		target = target.Elem()
	}
	if target.Kind() != reflect.Struct {
		return fmt.Errorf("skg: unmarshal target must be a struct, got %s", target.Kind())
	}

	fieldMap := buildFieldMap(target.Type())

	for _, node := range nodes {
		if node.Field != nil {
			idx, ok := fieldMap[node.Field.Key]
			if !ok {
				continue // extra fields ignored
			}
			fv := target.Field(idx)
			if err := decodeValue(node.Field.Value, fv); err != nil {
				return fmt.Errorf("skg: field %q: %w", node.Field.Key, err)
			}
		} else if node.Block != nil {
			idx, ok := fieldMap[node.Block.Name]
			if !ok {
				continue
			}
			fv := target.Field(idx)
			if err := decodeNodes(node.Block.Children, fv.Addr()); err != nil {
				return fmt.Errorf("skg: block %q: %w", node.Block.Name, err)
			}
		}
	}
	return nil
}

func decodeValue(val Value, target reflect.Value) error {
	// Handle pointer types (nullable)
	if target.Kind() == reflect.Ptr {
		if val.Type == TypeNull {
			target.Set(reflect.Zero(target.Type()))
			return nil
		}
		if target.IsNil() {
			target.Set(reflect.New(target.Type().Elem()))
		}
		target = target.Elem()
	}

	switch val.Type {
	case TypeString:
		if target.Kind() != reflect.String {
			return fmt.Errorf("cannot assign string to %s", target.Kind())
		}
		target.SetString(val.Str)

	case TypeInt:
		switch target.Kind() {
		case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
			target.SetInt(val.Int)
		case reflect.Float32, reflect.Float64:
			target.SetFloat(float64(val.Int))
		default:
			return fmt.Errorf("cannot assign int to %s", target.Kind())
		}

	case TypeFloat:
		switch target.Kind() {
		case reflect.Float32, reflect.Float64:
			target.SetFloat(val.Float)
		default:
			return fmt.Errorf("cannot assign float to %s", target.Kind())
		}

	case TypeBool:
		if target.Kind() != reflect.Bool {
			return fmt.Errorf("cannot assign bool to %s", target.Kind())
		}
		target.SetBool(val.Bool)

	case TypeNull:
		target.Set(reflect.Zero(target.Type()))

	case TypeArray:
		if target.Kind() != reflect.Slice {
			return fmt.Errorf("cannot assign array to %s", target.Kind())
		}
		if val.Array == nil {
			return nil
		}
		slice := reflect.MakeSlice(target.Type(), len(val.Array.Items), len(val.Array.Items))
		for i, item := range val.Array.Items {
			if err := decodeValue(item, slice.Index(i)); err != nil {
				return fmt.Errorf("index %d: %w", i, err)
			}
		}
		target.Set(slice)
	}
	return nil
}

func buildFieldMap(t reflect.Type) map[string]int {
	m := make(map[string]int, t.NumField())
	for i := 0; i < t.NumField(); i++ {
		f := t.Field(i)
		tag := f.Tag.Get("skg")
		if tag == "" || tag == "-" {
			continue
		}
		m[tag] = i
	}
	return m
}
