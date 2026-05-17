# roo-smarter_csv

![Gem Version](https://img.shields.io/gem/v/roo-smarter_csv) [![codecov](https://codecov.io/gh/tilo/roo-smarter_csv/branch/main/graph/badge.svg)](https://codecov.io/gh/tilo/roo-smarter_csv) [![RubyGems](https://img.shields.io/badge/RubyGems-roo__smarter__csv-brightgreen?logo=rubygems&logoColor=white)](https://rubygems.org/gems/roo-smarter_csv) [![Ruby Toolbox](https://img.shields.io/badge/Ruby%20Toolbox-roo__smarter__csv-brightgreen)](https://www.ruby-toolbox.com/projects/roo-smarter_csv)

`roo-smarter_csv` replaces Roo's CSV backend with [SmarterCSV](https://github.com/tilo/smarter_csv) while keeping the Roo spreadsheet API.

## What it does

- Uses [SmarterCSV](https://github.com/tilo/smarter_csv) for parsing CSV input
- Uses SmarterCSV defaults unless overridden by Roo compatibility behavior or explicit options

### SmarterCSV Benefits
- **SmarterCSV is 3-4.6x faster than Roo::CSV**
- SmarterCSV automatically detects `col_sep`, `row_sep`
- SmarterCSV is more robust against real-world data
- See [Ruby CSV Pitfalls](https://github.com/tilo/smarter_csv/blob/main/docs/ruby_csv_pitfalls.md) for examples of silent data loss and corruption cases in Ruby CSV
- See [Migrating from Ruby CSV](https://github.com/tilo/smarter_csv/blob/main/docs/migrating_from_csv.md) for behavior differences and migration guidance
- See [SmarterCSV 1.15.2: Faster Than Raw CSV Arrays](https://tilo-sloboda.medium.com/smartercsv-1-15-2-faster-than-raw-csv-arrays-benchmarks-zsv-and-the-full-pipeline-2c12a798032e) for benchmark background

## Performance

Speedup vs Roo::CSV with SmarterCSV 1.17.1

| File                           | Speedup |
| ------------------------------ | ------: |
| PEOPLE_IMPORT_B.csv            |   2.98x |
| uscities.csv                   |   4.22x |
| uszips.csv                     |   4.45x |
| worldcities.csv                |   4.58x |
| embedded_newlines_60k.csv      |   3.84x |
| heavy_quoting_60k.csv          |   3.42x |
| many_empty_fields_60k.csv      |   3.36x |
| sample_100k.csv                |   3.17x |
| sensor_data_50krows_50cols.csv |   3.23x |
| tab_separated_60k.tsv          |   3.14x |
| utf8_multibyte_60k.csv         |   3.17x |

### Roo API
- Keeps Roo's spreadsheet-style API:
  - `cell`
  - `celltype`
  - `row`
  - `column`
  - `each`
  - `parse`
  - `first_row` / `last_row`
  - `first_column` / `last_column`
- Preserves Roo's single-sheet CSV behavior
- Supports Roo's `Roo::Spreadsheet.open(...)` entry point
- Supports CSV export through Roo's existing `to_csv`

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

```ruby
require "roo-smarter_csv"

spreadsheet = Roo::Spreadsheet.open("data.csv")
```

`require "roo-smarter_csv"` automatically loads both `roo` and `smarter_csv` and registers `Roo::SmarterCSV` as Roo's CSV handler.

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

## Options

- SmarterCSV options are handled as nested options, e.g. `options = { smarter_csv: {} }`
- `roo-smarter_csv` defaults the SmarterCSV option `remove_empty_hashes` to `false`, so that it is compatible with Roo.
- `roo-smarter_csv` honors some of the `csv_options` from Roo, but we encourage that you pass those under `smarter_csv` options.

### Option precedence

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
2. Apply `roo-smarter_csv` compatibility overrides.
3. Copy supported keys from `csv_options` into the SmarterCSV options.
4. Apply `smarter_csv` on top.
5. If the same key exists in both places, `smarter_csv` wins.
6. Conflicts emit a warning.

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

When you do not pass any options, `roo-smarter_csv` starts from SmarterCSV defaults and then applies one compatibility override for Roo:

- `remove_empty_hashes: false`

That override is intentional. Roo expects blank rows to remain addressable in the spreadsheet model, so `roo-smarter_csv` disables SmarterCSV's default behavior of dropping fully empty row hashes.

Some important effective defaults are therefore:

- `col_sep: :auto` — auto-detects the separator
- `row_sep: :auto` — auto-detects line endings
- `quote_char: '"'`
- `downcase_header: true`
- `strings_as_keys: false`
- `convert_values_to_numeric: true`
- `remove_empty_hashes: false` — `roo-smarter_csv` sets this for Roo compatibility so blank rows remain addressable through the spreadsheet API.
- `headers_in_file: true`

This means common CSV files work without extra configuration, and SmarterCSV can infer separators and convert numeric values automatically while still preserving Roo-compatible blank rows.

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
    col_sep: ";",
    quote_char: '"'
  }
)
```

## Development

```bash
bundle install
bundle exec rspec
```

## Reporting Bugs / Feature Requests

Please [open an Issue on GitHub](https://github.com/tilo/roo-smarter_csv/issues) if you have feedback, new feature requests, or want to report a bug. Thank you!

For reporting issues, please:
  * include a small sample CSV file
  * open a pull-request adding a test that demonstrates the issue
  * mention your version of SmarterCSV, Ruby, Rails

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT
