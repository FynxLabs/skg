package skg

// MergeNodes overlays `overlay` on top of `base`, returning a new slice.
//
// Fields with the same key: overlay wins (last-wins).
// Blocks with the same name: children merged recursively.
// New keys/blocks from overlay are appended.
func MergeNodes(base, overlay []Node) []Node {
	if len(overlay) == 0 {
		return base
	}

	result := make([]Node, 0, len(base)+len(overlay))
	index := make(map[string]int, len(base)+len(overlay))

	for _, n := range base {
		key := nodeKey(n)
		index[key] = len(result)
		result = append(result, n)
	}

	for _, ov := range overlay {
		key := nodeKey(ov)
		if pos, ok := index[key]; ok {
			if ov.Block != nil && result[pos].Block != nil {
				merged := MergeNodes(result[pos].Block.Children, ov.Block.Children)
				result[pos] = Node{Block: &Block{
					Name:     result[pos].Block.Name,
					Children: merged,
					Line:     result[pos].Block.Line,
					Col:      result[pos].Block.Col,
				}}
			} else {
				result[pos] = ov
			}
		} else {
			index[key] = len(result)
			result = append(result, ov)
		}
	}

	return result
}

func nodeKey(n Node) string {
	if n.Field != nil {
		return n.Field.Key
	}
	return n.Block.Name
}
