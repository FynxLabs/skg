; SKG highlight queries
; Maps tree-sitter node types to standard capture names.
; Works with Neovim (nvim-treesitter), Helix, and Zed.

; Comments
(comment) @comment.line

; Block names  (panel_000 { ... } -> "panel_000" is entity.name)
(block name: (identifier) @module)

; Keys  (key: value -> "key" is property)
(pair key: (identifier) @variable.member)

; Strings
(string) @string
(escape_sequence) @string.escape

; Numbers
(float) @number.float
(integer) @number

; Booleans
(boolean) @boolean

; Punctuation
":" @punctuation.delimiter
"{" @punctuation.bracket
"}" @punctuation.bracket
"[" @punctuation.bracket
"]" @punctuation.bracket
"," @punctuation.delimiter
