# frozen_string_literal: true

require "spec_helper"

RSpec.describe Roo::SmarterCSV do
  let(:csv_path) { File.expand_path("fixtures/sample.csv", __dir__) }
  let(:tsv_path) { File.expand_path("fixtures/sample.tsv", __dir__) }
  let(:bom_path) { File.expand_path("fixtures/sample_bom.csv", __dir__) }
  let(:empty_path) { File.expand_path("fixtures/empty.csv", __dir__) }
  let(:defaults_path) { File.expand_path("fixtures/defaults.csv", __dir__) }
  let(:blank_fields_path) { File.expand_path("fixtures/blank_fields.csv", __dir__) }
  let(:empty_rows_path) { File.expand_path("fixtures/empty_rows.csv", __dir__) }
  let(:duplicate_blank_headers_path) { File.expand_path("fixtures/duplicate_blank_headers.csv", __dir__) }
  let(:quoted_headers_path) { File.expand_path("fixtures/quoted_headers.csv", __dir__) }
  let(:clean_values_path) { File.expand_path("fixtures/clean_values.csv", __dir__) }
  let(:csv) { Roo::SmarterCSV.new(csv_path) }

  describe "Roo interface" do
    it "returns sheets array" do
      expect(csv.sheets).to eq(["default"])
    end

    it "provides default_sheet" do
      expect(csv.default_sheet).to eq("default")
    end

    it "accesses cells by row and column" do
      expect(csv.cell(2, 1)).to eq("John")
      expect(csv.cell(2, 2)).to eq(30)
      expect(csv.cell(2, 3)).to eq("john@example.com")
    end

    it "detects cell types" do
      expect(csv.celltype(1, 1)).to eq(:string)  # "Name"
      expect(csv.celltype(2, 2)).to eq(:numeric) # 30
    end

    it "provides row access" do
      row = csv.row(2)
      expect(row).to eq(["John", 30, "john@example.com", 50_000])
    end

    it "provides boundary methods" do
      expect(csv.first_row).to eq(1)
      expect(csv.last_row).to eq(4) # 3 data rows + 1 header
      expect(csv.first_column).to eq(1)
      expect(csv.last_column).to eq(4)
    end

    it "iterates rows" do
      rows = []
      csv.each { |row| rows << row }
      expect(rows.length).to eq(4)
    end

    it "parses with headers" do
      data = csv.parse(headers: true)
      expect(data.first).to be_a(Hash)
      expect(data.first.keys).to eq(%w[Name Age Email Salary])
      expect(data.first["Name"]).to eq("Name")
      expect(data[1]["Name"]).to eq("John")
    end
  end

  describe "Type detection" do
    it "detects numeric types" do
      expect(csv.celltype(2, 2)).to eq(:numeric) # 30
      expect(csv.cell(2, 2)).to eq(30)
    end

    it "detects string types" do
      expect(csv.celltype(2, 1)).to eq(:string)
      expect(csv.cell(2, 1)).to eq("John")
    end
  end

  describe "Integration with Roo::Spreadsheet" do
    it "registers itself as Roo CSV handler" do
      expect(Roo::CLASS_FOR_EXTENSION[:csv]).to eq(Roo::SmarterCSV)
    end

    it "can be opened via Roo::Spreadsheet.open" do
      spreadsheet = Roo::Spreadsheet.open(csv_path)
      expect(spreadsheet).to be_a(Roo::SmarterCSV)
      expect(spreadsheet.cell(2, 1)).to eq("John")
    end

    it "works with StringIO input" do
      spreadsheet = Roo::Spreadsheet.open(StringIO.new(File.read(csv_path)), extension: :csv)
      expect(spreadsheet).to be_a(Roo::SmarterCSV)
      expect(spreadsheet.cell(2, 2)).to eq(30)
    end

    it "reads files with a UTF-8 BOM" do
      spreadsheet = Roo::Spreadsheet.open(bom_path)
      expect(spreadsheet.cell(2, 1)).to eq("John")
      expect(spreadsheet.cell(2, 4)).to eq(50_000)
    end

    it "treats an empty csv file as an error" do
      expect { Roo::Spreadsheet.open(empty_path).cell(1, 1) }.to raise_error(SmarterCSV::EmptyFileError)
    end

    it "accepts csv_options from Roo and bridges them into SmarterCSV" do
      spreadsheet = Roo::Spreadsheet.open(tsv_path, extension: :csv, csv_options: { col_sep: "\t" })
      expect(spreadsheet.cell(2, 1)).to eq("John")
      expect(spreadsheet.cell(2, 4)).to eq(50_000)
    end

    it "uses SmarterCSV defaults when no options are supplied" do
      spreadsheet = Roo::Spreadsheet.open(defaults_path)
      expect(spreadsheet.cell(2, 2)).to eq("hello, world")
      expect(spreadsheet.cell(2, 3)).to eq(30)
      expect(spreadsheet.cell(2, 4)).to eq(1.5)
      expect(spreadsheet.celltype(2, 3)).to eq(:numeric)
      expect(spreadsheet.celltype(2, 4)).to eq(:float)
    end

    it "preserves blank fields in the middle of rows" do
      spreadsheet = Roo::Spreadsheet.open(blank_fields_path)
      expect(spreadsheet.row(2)).to eq([1, "John", "Doe", nil, "Portland", "OR", 97_201])
      expect(spreadsheet.row(3)).to eq([2, "Jane", "Smith", "Apt 3", "Seattle", "WA", nil])
      expect(spreadsheet.row(4)).to eq([3, "Bob", "Jones", nil, nil, "CA", 90_210])
      expect(spreadsheet.cell(2, 4)).to be_nil
      expect(spreadsheet.celltype(2, 4)).to eq(:empty)
    end

    it "preserves fully empty rows end-to-end" do
      spreadsheet = Roo::Spreadsheet.open(empty_rows_path)
      expect(spreadsheet.last_row).to eq(4)
      expect(spreadsheet.row(3)).to eq([nil, nil, nil])
      expect(spreadsheet.celltype(3, 1)).to eq(:empty)
      expect(spreadsheet.row(4)).to eq([2, "Bob", 40])
    end

    it "supports SmarterCSV chunk_size without changing visible spreadsheet rows" do
      spreadsheet = Roo::SmarterCSV.new(csv_path, smarter_csv: { chunk_size: 2 })
      expect(spreadsheet.last_row).to eq(4)
      expect(spreadsheet.row(2)).to eq(["John", 30, "john@example.com", 50_000])
      expect(spreadsheet.row(4)).to eq(["Bob", 35, "bob@example.com", 55_000])
    end

    it "supports user_provided_headers when headers_in_file is false" do
      spreadsheet = Roo::SmarterCSV.new(
        StringIO.new("1,John\n2,Jane\n"),
        smarter_csv: { headers_in_file: false, user_provided_headers: %i[id name] }
      )

      expect(spreadsheet.first_row).to eq(1)
      expect(spreadsheet.last_row).to eq(2)
      expect(spreadsheet.row(1)).to eq([1, "John"])
      expect(spreadsheet.row(2)).to eq([2, "Jane"])
    end

    it "handles duplicate and blank headers without shifting data columns" do
      spreadsheet = Roo::Spreadsheet.open(duplicate_blank_headers_path)
      expect(spreadsheet.row(1)).to eq(["name", nil, "name"])
      expect(spreadsheet.row(2)).to eq(["Alice", nil, "Bob"])
      expect(spreadsheet.last_column).to eq(3)
    end

    it "parses quoted headers containing separators correctly" do
      spreadsheet = Roo::Spreadsheet.open(quoted_headers_path)
      expect(spreadsheet.row(1)).to eq(["Last, First", "Age", "City, State"])
      expect(spreadsheet.row(2)).to eq(["Doe, Jane", 30, "Portland, OR"])
    end

    it "supports clean: true through Roo's public parse API" do
      spreadsheet = Roo::Spreadsheet.open(clean_values_path)
      data = spreadsheet.parse(headers: true, clean: true)

      expect(data.first.keys).to eq(%w[Name City])
      expect(data[1]).to eq({ "Name" => "John", "City" => "Portland" })
    end

    it "prefers smarter_csv options over csv_options and emits a warning" do
      spreadsheet = Roo::SmarterCSV.new(csv_path, csv_options: { col_sep: ";" }, smarter_csv: { col_sep: "," })
      expect { spreadsheet.cell(2, 1) }.to output(/conflicting option col_sep/).to_stderr
      expect(spreadsheet.cell(2, 1)).to eq("John")
    end
  end

  describe "private helper coverage" do
    let(:adapter) { described_class.new(csv_path) }

    it "covers private helper methods and mutation helpers" do
      expect(adapter.send(:normalize_option_hash, nil)).to eq({})
      expect(adapter.send(:normalize_option_hash, "nope")).to eq({})
      expect(adapter.send(:normalize_option_hash, "a" => 1)).to eq({ a: 1 })

      expect(adapter.send(:infer_type, nil)).to eq(:empty)
      expect(adapter.send(:infer_type, true)).to eq(:boolean)
      expect(adapter.send(:infer_type, false)).to eq(:boolean)
      expect(adapter.send(:infer_type, Date.new(2024, 1, 1))).to eq(:date)
      expect(adapter.send(:infer_type, Time.new(2024, 1, 1, 12, 0, 0))).to eq(:datetime)
      expect(adapter.send(:infer_type, Object.new)).to eq(:string)

      expect(adapter.send(:sanitize_value, " \tHello\n")).to eq("Hello")
      expect(adapter.send(:generated_header_key, 3)).to eq(:column_3)
      expect(adapter.send(:set_type, 1, 1, :string, nil)).to be_nil

      adapter.instance_variable_set(:@reader, double(headers: %i[a b]))
      expect(adapter.send(:sparse_row_hash, { a: 1 })).to eq({ a: 1 })
      expect(adapter.send(:sparse_row_hash, %w[x y z])).to eq({ a: "x", b: "y", column_3: "z" })
      expect(adapter.send(:sparse_row_hash, nil)).to eq({})
      expect(adapter.send(:sparse_row_hash, "solo")).to eq({ column_1: "solo" })

      adapter.instance_variable_set(:@rows, [])
      adapter.send(:store_rows, { a: 1 })
      adapter.send(:store_rows, [{ a: 2 }, nil])
      expect(adapter.instance_variable_get(:@rows)).to eq([{ a: 1 }, { a: 2 }, {}])

      adapter.instance_variable_set(:@header_row, ["H1"])
      adapter.instance_variable_set(:@header_keys, [:h1])
      adapter.instance_variable_set(:@rows, [])
      adapter.send(:ensure_data_row, 3)
      adapter.send(:ensure_header_width, 3)
      expect(adapter.instance_variable_get(:@rows).length).to eq(2)
      expect(adapter.instance_variable_get(:@header_keys)).to eq(%i[h1 column_2 column_3])
      expect(adapter.instance_variable_get(:@header_row)).to eq(["H1", nil, nil])

      adapter.instance_variable_set(:@cells_read, { "default" => true })
      adapter.instance_variable_set(:@first_row, {})
      adapter.instance_variable_set(:@last_row, {})
      adapter.instance_variable_set(:@first_column, {})
      adapter.instance_variable_set(:@last_column, {})
      adapter.set_value(1, 2, "Header", nil)
      adapter.set_value(2, 3, "Value", nil)
      expect(adapter.row(1)).to eq(["H1", "Header", nil])
      expect(adapter.row(2)).to eq([nil, nil, "Value"])
      expect(adapter.celltype(1, 3)).to be_nil
      expect(adapter.first_row).to eq(1)
      expect(adapter.last_row).to eq(3)
      expect(adapter.first_column).to eq(1)
      expect(adapter.last_column).to eq(3)

      adapter.instance_variable_set(:@header_row, ["  Head\n", nil])
      adapter.instance_variable_set(:@rows, [{ a: " row\t" }, { b: 1 }])
      adapter.instance_variable_set(:@cells_read, { "default" => true })
      adapter.send(:clean_sheet, "default")
      expect(adapter.instance_variable_get(:@header_row)).to eq(["Head", nil])
      expect(adapter.instance_variable_get(:@rows).first[:a]).to eq("row")
      expect(adapter.instance_variable_get(:@cleaned)["default"]).to eq(true)

      other = described_class.new(csv_path, csv_options: { col_sep: ";" })
      expect(other.send(:reinitialize)).to eq(1)
      expect(other).to be_a(described_class)
      expect(other.csv_options).to eq(col_sep: ";")
    end

    it "uses the URI source path when reading remote files" do
      remote = described_class.new("http://example.com/test.csv")
      allow(remote).to receive(:uri?).and_return(true)
      allow(remote).to receive(:download_uri).with("http://example.com/test.csv", "/tmp/roo-test").and_return("/tmp/downloaded.csv")

      yielded = nil
      allow(Dir).to receive(:mktmpdir).and_yield("/tmp/roo-test")
      remote.send(:with_source) { |source| yielded = source }

      expect(yielded).to eq("/tmp/downloaded.csv")
    end
  end
end
