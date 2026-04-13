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

	// Map target: block children become map entries.
	// Field keys/block names are map keys, values decode into the map value type.
	if target.Kind() == reflect.Map {
		return decodeMap(nodes, target)
	}

	if target.Kind() != reflect.Struct {
		return fmt.Errorf("skg: unmarshal target must be a struct or map, got %s", target.Kind())
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
			// Handle pointer-to-struct fields: allocate if nil, then decode into the pointee.
			if fv.Kind() == reflect.Ptr {
				if fv.IsNil() {
					fv.Set(reflect.New(fv.Type().Elem()))
				}
				if err := decodeNodes(node.Block.Children, fv); err != nil {
					return fmt.Errorf("skg: block %q: %w", node.Block.Name, err)
				}
			} else {
				if err := decodeNodes(node.Block.Children, fv.Addr()); err != nil {
					return fmt.Errorf("skg: block %q: %w", node.Block.Name, err)
				}
			}
		} else if node.BlockArray != nil {
			idx, ok := fieldMap[node.BlockArray.Name]
			if !ok {
				continue
			}
			fv := target.Field(idx)
			if err := decodeBlockArray(node.BlockArray, fv); err != nil {
				return fmt.Errorf("skg: block array %q: %w", node.BlockArray.Name, err)
			}
		}
	}
	return nil
}

func decodeMap(nodes []Node, target reflect.Value) error {
	if target.Type().Key().Kind() != reflect.String {
		return fmt.Errorf("skg: map key must be string, got %s", target.Type().Key().Kind())
	}

	if target.IsNil() {
		target.Set(reflect.MakeMap(target.Type()))
	}

	valType := target.Type().Elem()
	isAny := valType.Kind() == reflect.Interface

	for _, node := range nodes {
		if node.Field != nil {
			if isAny {
				target.SetMapIndex(reflect.ValueOf(node.Field.Key), reflect.ValueOf(valueToAny(node.Field.Value)))
			} else {
				val := reflect.New(valType).Elem()
				if err := decodeValue(node.Field.Value, val); err != nil {
					return fmt.Errorf("skg: map key %q: %w", node.Field.Key, err)
				}
				target.SetMapIndex(reflect.ValueOf(node.Field.Key), val)
			}
		} else if node.Block != nil {
			if isAny {
				// Decode block children into map[string]interface{}
				inner := reflect.MakeMap(reflect.TypeOf(map[string]interface{}{}))
				if err := decodeMap(node.Block.Children, inner); err != nil {
					return fmt.Errorf("skg: map key %q: %w", node.Block.Name, err)
				}
				target.SetMapIndex(reflect.ValueOf(node.Block.Name), inner)
			} else {
				val := reflect.New(valType).Elem()
				if err := decodeNodes(node.Block.Children, val.Addr()); err != nil {
					return fmt.Errorf("skg: map key %q: %w", node.Block.Name, err)
				}
				target.SetMapIndex(reflect.ValueOf(node.Block.Name), val)
			}
		}
	}
	return nil
}

func decodeBlockArray(ba *BlockArray, target reflect.Value) error {
	if target.Kind() == reflect.Ptr {
		if target.IsNil() {
			target.Set(reflect.New(target.Type().Elem()))
		}
		target = target.Elem()
	}
	if target.Kind() != reflect.Slice {
		return fmt.Errorf("target must be a slice, got %s", target.Kind())
	}
	elemType := target.Type().Elem()
	slice := reflect.MakeSlice(target.Type(), len(ba.Items), len(ba.Items))
	for i, item := range ba.Items {
		elem := reflect.New(elemType)
		if err := decodeNodes(item, elem); err != nil {
			return fmt.Errorf("index %d: %w", i, err)
		}
		slice.Index(i).Set(elem.Elem())
	}
	target.Set(slice)
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

	// Handle interface{} / any - decode into native Go types
	if target.Kind() == reflect.Interface {
		target.Set(reflect.ValueOf(valueToAny(val)))
		return nil
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

// valueToAny converts an SKG Value into a native Go type for interface{} targets.
func valueToAny(val Value) interface{} {
	switch val.Type {
	case TypeString:
		return val.Str
	case TypeInt:
		return val.Int
	case TypeFloat:
		return val.Float
	case TypeBool:
		return val.Bool
	case TypeNull:
		return nil
	case TypeArray:
		if val.Array == nil {
			return []interface{}{}
		}
		items := make([]interface{}, len(val.Array.Items))
		for i, item := range val.Array.Items {
			items[i] = valueToAny(item)
		}
		return items
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
