# vscode-skg

VS Code extension for `.skg` files. Provides syntax highlighting via a
TextMate grammar plus bracket matching, comment toggling, and
auto-closing pairs.

Source: [tools/vscode-skg/](../tools/vscode-skg/)

## What it covers

The TextMate grammar matches the full language spec in
[spec.md](spec.md):

- `import` keyword (single and array forms)
- Named blocks and block arrays
- Fields, colonless scalar array shorthand
- Scalars: `int`, `float`, `bool`, `string`, `null`
- Single-line strings with valid escapes (`\"`, `\\`, `\n`, `\t`);
  illegal escapes are flagged with `invalid.illegal`
- Triple-quoted multiline strings
- Nested arrays and nested block-array items
- Line comments

Extension features from `language-configuration.json`:

- `#` as line comment token
- Auto-closing `{}`, `[]`, `""`
- Indent/dedent on brace lines

## Build and install

Requires Node.js.

```sh
cd tools/vscode-skg
npm install
npx vsce package          # produces skg-<version>.vsix
code --install-extension skg-0.1.0.vsix
```

Reload the VS Code window. Any `.skg` file will activate the
extension.

## Develop

Open `tools/vscode-skg/` in VS Code, press `F5` to launch an
Extension Development Host, then open a `.skg` file. Edits to
`syntaxes/skg.tmLanguage.json` take effect on window reload
(`Ctrl+R`) in the dev host.

To verify the grammar against the shared fixtures, open files from
[testdata/valid/](../testdata/valid/) and confirm colors match
expectations (strings, keywords, numbers, identifiers all distinctly
scoped).

## Scope names

Standard TextMate scopes - themes pick them up automatically:

- `keyword.control.import.skg`
- `entity.name.section.skg` (block and block-array names)
- `variable.other.property.skg` (field keys)
- `string.quoted.double.skg`, `string.quoted.triple.skg`
- `constant.numeric.integer.skg`, `constant.numeric.float.skg`
- `constant.language.boolean.skg`, `constant.language.null.skg`
- `constant.character.escape.skg`, `invalid.illegal.escape.skg`
- `comment.line.number-sign.skg`

## Publishing

Not published to the marketplace yet. Distribute the `.vsix` directly
or point users at this repo.
