package skg

import (
	"fmt"
	"reflect"
)

// Marshal encodes a Go struct into SKG text using `skg:"name"` struct tags.
func Marshal(v interface{}) ([]byte, error) {
	rv := reflect.ValueOf(v)
	if rv.Kind() == reflect.Ptr {
		rv = rv.Elem()
	}
	if rv.Kind() != reflect.Struct {
		return nil, fmt.Errorf("skg: marshal source must be a struct, got %s", rv.Kind())
	}

	nodes, err := encodeStruct(rv)
	if err != nil {
		return nil, err
	}

	file := &File{Children: nodes}
	return Emit(file), nil
}

func encodeStruct(rv reflect.Value) ([]Node, error) {
	rt := rv.Type()
	var nodes []Node

	for i := 0; i < rt.NumField(); i++ {
		sf := rt.Field(i)
		tag := sf.Tag.Get("skg")
		if tag == "" || tag == "-" {
			continue
		}

		fv := rv.Field(i)

		// Handle pointer fields
		if fv.Kind() == reflect.Ptr {
			if fv.IsNil() {
				nodes = append(nodes, Node{Field: &Field{Key: tag, Value: Value{Type: TypeNull}}})
				continue
			}
			fv = fv.Elem()
		}

		if fv.Kind() == reflect.Struct {
			children, err := encodeStruct(fv)
			if err != nil {
				return nil, fmt.Errorf("skg: block %q: %w", tag, err)
			}
			nodes = append(nodes, Node{Block: &Block{Name: tag, Children: children}})
			continue
		}

		val, err := encodeValue(fv)
		if err != nil {
			return nil, fmt.Errorf("skg: field %q: %w", tag, err)
		}
		nodes = append(nodes, Node{Field: &Field{Key: tag, Value: val}})
	}

	return nodes, nil
}

func encodeValue(rv reflect.Value) (Value, error) {
	switch rv.Kind() {
	case reflect.String:
		return Value{Type: TypeString, Str: rv.String()}, nil
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return Value{Type: TypeInt, Int: rv.Int()}, nil
	case reflect.Float32, reflect.Float64:
		return Value{Type: TypeFloat, Float: rv.Float()}, nil
	case reflect.Bool:
		return Value{Type: TypeBool, Bool: rv.Bool()}, nil
	case reflect.Slice:
		if rv.Len() == 0 {
			return Value{Type: TypeArray, Array: &Array{ElementType: TypeString}}, nil
		}
		items := make([]Value, rv.Len())
		for i := 0; i < rv.Len(); i++ {
			v, err := encodeValue(rv.Index(i))
			if err != nil {
				return Value{}, fmt.Errorf("index %d: %w", i, err)
			}
			items[i] = v
		}
		return Value{Type: TypeArray, Array: &Array{ElementType: items[0].Type, Items: items}}, nil
	default:
		return Value{}, fmt.Errorf("unsupported type %s", rv.Kind())
	}
}
