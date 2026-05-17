# roo-smarter_csv

`roo-smarter_csv` replaces Roo's CSV backend with [SmarterCSV](https://github.com/tilo/smarter_csv) while keeping the Roo spreadsheet API.

## What it does

- Keeps Roo's spreadsheet-style API:
  - `cell`
  - `celltype`
  - `row`
  - `column`
  - `each`
  - `parse`
  - `first_row` / `last_row`
  - `first_column` / `last_column`
- Uses SmarterCSV for parsing CSV input
- Preserves Roo's single-sheet CSV behavior
- Supports Roo's `Roo::Spreadsheet.open(...)` entry point
- Supports CSV export through Roo's existing `to_csv`
- Uses SmarterCSV defaults unless you override them

## Installation

Add to your Gemfile:

```ruby
gem "roo-smarter_csv"
```

Then run:

```bash
bundle install
```

## Activation

Load Roo first, then load this gem:

```ruby
require "roo"
require "roo-smarter_csv"

spreadsheet = Roo::Spreadsheet.open("data.csv")
```

After `require "roo-smarter_csv"`, Roo will use `Roo::SmarterCSV` for `.csv` files.

## Supported behavior

`roo-smarter_csv` reads the full CSV input and exposes it through Roo's spreadsheet abstraction.

It supports:

- local files
- `StringIO` / stream input
- Roo's `Roo::Spreadsheet.open(...)`
- CSV files with a UTF-8 BOM
- tab-delimited input via `col_sep: "\t"`
- SmarterCSV type conversion
- warnings emitted by SmarterCSV
- Roo's `to_csv` export for the in-memory spreadsheet representation

## Architecture note

SmarterCSV is used as the parser, but Roo remains the public model.

That means:

- SmarterCSV row hashes are an internal parsing representation
- Roo still stores data in its coordinate-based cell grid
- Roo's public API remains spreadsheet-like
- hash-based rows are only an intermediate step for parser-to-grid conversion

## Option precedence

`roo-smarter_csv` understands two option namespaces:

### 1. SmarterCSV options
Primary namespace:

```ruby
smarter_csv: {
  col_sep: ";",
  row_sep: "\n",
  quote_char: '"',
  encoding: "utf-8"
}
```

### 2. Roo compatibility options
Roo already uses:

```ruby
csv_options: {
  col_sep: ";",
  row_sep: "\n",
  quote_char: '"',
  encoding: "utf-8"
}
```

Only these four keys are copied from `csv_options` into the effective SmarterCSV options:

- `col_sep`
- `row_sep`
- `quote_char`
- `encoding`

### Precedence rules

1. Start with SmarterCSV defaults.
2. Copy supported keys from `csv_options` into the SmarterCSV options.
3. Apply `smarter_csv` on top.
4. If the same key exists in both places, `smarter_csv` wins.
5. Conflicts emit a warning.

Only the following Roo-compatible CSV keys are bridged from `csv_options`:

- `col_sep`
- `row_sep`
- `quote_char`
- `encoding`

No other Roo options are treated as CSV parser settings.

### Examples

#### Only Roo options

```ruby
Roo::Spreadsheet.open("data.tsv", csv_options: { col_sep: "\t" })
```

#### Only SmarterCSV options

```ruby
Roo::Spreadsheet.open("data.csv", smarter_csv: { col_sep: ";" })
```

#### Both, with conflict

```ruby
Roo::Spreadsheet.open(
  "data.csv",
  csv_options: { col_sep: ";" },
  smarter_csv: { col_sep: "\t" }
)
```

In this case, `smarter_csv[:col_sep]` wins and a warning is emitted.

## SmarterCSV defaults

When you do not pass any options, SmarterCSV defaults are used.

Some important defaults are:

- `col_sep: :auto` — auto-detects the separator
- `row_sep: :auto` — auto-detects line endings
- `quote_char: '"'`
- `downcase_header: true`
- `strings_as_keys: false`
- `convert_values_to_numeric: true`
- `remove_empty_hashes: true`
- `headers_in_file: true`

This means common CSV files work without extra configuration, and SmarterCSV can infer separators and convert numeric values automatically.

### Default behavior examples

#### Auto-detected separator

```ruby
spreadsheet = Roo::Spreadsheet.open("data.csv")
```

No `col_sep` is needed for normal comma-separated CSV files.

#### Automatic numeric conversion

```ruby
spreadsheet.cell(2, 2)   # => 30
spreadsheet.cell(2, 4)   # => 1.5
```

#### Headers and keys

SmarterCSV downcases headers by default and returns symbol keys:

```ruby
SmarterCSV.process(StringIO.new("Name,Email\nJohn,john@example.com\n")).first
# => { name: "John", email: "john@example.com" }
```

If you want string keys instead, SmarterCSV supports:

```ruby
SmarterCSV.process(
  StringIO.new("Name,Email\nJohn,john@example.com\n"),
  strings_as_keys: true
).first
# => { "name" => "John", "email" => "john@example.com" }
```

In `roo-smarter_csv`, those row hashes are used internally to populate Roo's spreadsheet grid. The public Roo methods still behave like spreadsheet methods.

## Examples

### Basic Roo usage

```ruby
require "roo"
require "roo-smarter_csv"

csv = Roo::Spreadsheet.open("people.csv")

csv.cell(2, 1)      # => "John"
csv.cell(2, 2)      # => 30
csv.row(2)          # => ["John", 30, "john@example.com", 50000]
csv.first_row       # => 1
csv.last_row        # => 4
```

### TSV example

```ruby
csv = Roo::Spreadsheet.open(
  "people.tsv",
  extension: :csv,
  csv_options: { col_sep: "\t" }
)
```

### Explicit SmarterCSV options

```ruby
csv = Roo::Spreadsheet.open(
  "data.csv",
  smarter_csv: {
    remove_empty_hashes: true,
    skip_empty_lines: true
  }
)
```

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT
