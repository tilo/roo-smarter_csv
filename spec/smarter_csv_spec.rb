require 'rspec'
require 'roo'
require 'roo-smarter_csv'

describe Roo::SmarterCSV do
  let(:csv_path) { File.expand_path('../fixtures/sample.csv', __FILE__) }
  let(:csv) { Roo::SmarterCSV.new(csv_path) }

  describe 'Roo interface' do
    it 'returns sheets array' do
      expect(csv.sheets).to eq(['default'])
    end

    it 'provides default_sheet' do
      expect(csv.default_sheet).to eq('default')
    end

    it 'accesses cells by row and column' do
      expect(csv.cell(2, 1)).to eq('John')
      expect(csv.cell(2, 2)).to eq(30)
      expect(csv.cell(2, 3)).to eq('john@example.com')
    end

    it 'detects cell types' do
      expect(csv.celltype(1, 1)).to eq(:string)  # "Name"
      expect(csv.celltype(2, 2)).to eq(:numeric) # 30
    end

    it 'provides row access' do
      row = csv.row(2)
      expect(row).to eq(['John', 30, 'john@example.com', 50000])
    end

    it 'provides boundary methods' do
      expect(csv.first_row).to eq(1)
      expect(csv.last_row).to eq(4)  # 3 data rows + 1 header
      expect(csv.first_column).to eq(1)
      expect(csv.last_column).to eq(4)
    end

    it 'iterates rows' do
      rows = []
      csv.each { |row| rows << row }
      expect(rows.length).to eq(4)
    end

    it 'parses with headers' do
      data = csv.parse(headers: true)
      expect(data.first).to be_a(Hash)
      expect(data.first.keys).to eq(['Name', 'Age', 'Email', 'Salary'])
      expect(data.first['Name']).to eq('John')
    end
  end

  describe 'Type detection' do
    it 'detects numeric types' do
      expect(csv.celltype(2, 2)).to eq(:numeric)  # 30
      expect(csv.cell(2, 2)).to eq(30)
    end

    it 'detects string types' do
      expect(csv.celltype(2, 1)).to eq(:string)
      expect(csv.cell(2, 1)).to eq('John')
    end
  end

  describe 'Integration with Roo::Spreadsheet' do
    it 'can be opened via Roo::Spreadsheet.open' do
      spreadsheet = Roo::Spreadsheet.open(csv_path)
      expect(spreadsheet).to be_a(Roo::SmarterCSV)
      expect(spreadsheet.cell(2, 1)).to eq('John')
    end
  end
end
