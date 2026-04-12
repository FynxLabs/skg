/// Tree-sitter grammar for the SKG (Static Key Graph) config format.
///
/// Build:      npm install && npx tree-sitter generate
/// Test:       npx tree-sitter test
/// Install:    npx tree-sitter build --wasm   (for web/Zed)
///             npx tree-sitter build           (native, for Neovim/Helix)
///
/// Neovim:  add to nvim-treesitter as a custom parser.
/// Helix:   add to languages.toml under [[language]] with tree-sitter source.
/// Zed:     register in extensions/zed-skg (wasm build).

module.exports = grammar({
  name: 'skg',

  extras: $ => [
    /\s/,
    $.comment,
  ],

  rules: {
    // A document is zero or more top-level statements.
    document: $ => repeat($._statement),

    _statement: $ => choice(
      $.block,
      $.pair,
    ),

    // block:  name { ... }
    // Covers both named blocks (panel_000 { }) and anonymous blocks (panel { }).
    block: $ => seq(
      field('name', $.identifier),
      '{',
      repeat($._statement),
      '}',
    ),

    // pair:  key: value
    pair: $ => seq(
      field('key', $.identifier),
      ':',
      field('value', $._value),
    ),

    _value: $ => choice(
      $.string,
      $.float,
      $.integer,
      $.boolean,
      $.array,
    ),

    // array:  [ value, value, ... ]
    array: $ => seq(
      '[',
      optional(
        seq(
          $._value,
          repeat(seq(',', $._value)),
          optional(','),
        ),
      ),
      ']',
    ),

    // string:  "..." with escape sequences
    string: $ => seq(
      '"',
      repeat(choice(
        token.immediate(/[^"\\]+/),
        $.escape_sequence,
      )),
      '"',
    ),

    escape_sequence: $ => token.immediate(/\\./),

    // float must be tried before integer to avoid partial matches.
    float: $ => token(prec(1, /-?\d+\.\d+/)),

    integer: $ => /-?\d+/,

    boolean: $ => choice('true', 'false'),

    identifier: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,

    // # line comment
    comment: $ => /#.*/,
  },
});
