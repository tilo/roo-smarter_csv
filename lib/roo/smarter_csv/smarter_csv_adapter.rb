# frozen_string_literal: true

require_relative 'version'

module Roo
  class SmarterCSV < Roo::Base
    attr_reader :filename, :reader

    def initialize(filename, options = {})
      # Basic setup
      unless is_stream?(filename)
        file_type_check(filename, '.csv', 'a CSV', options.fetch(:file_warning, :error))
      end

      # Extract options
      @smarter_csv_options = extract_options(options)
      
      # Initialize parent
      super(filename, options)

      @filename = filename
      @cells_loaded = false
    end

    # REQUIRED: Sheet names
    def sheets
      ["default"]
    end

    # REQUIRED: Get cell value
    def cell(row, col, sheet = nil)
      sheet ||= default_sheet
      read_cells(sheet)
      @cell[[row, col]]
    end

    # REQUIRED: Get cell type
    def celltype(row, col, sheet = nil)
      sheet ||= default_sheet
      read_cells(sheet)
      @cell_type[[row, col]] || :string
    end

    private

    def extract_options(options)
      {
        col_sep: options[:col_sep],
        row_sep: options[:row_sep],
        headers_in_file: options.fetch(:headers_in_file, true),
        remove_empty_hashes: options.fetch(:remove_empty_hashes, true),
        skip_empty_lines: options.fetch(:skip_empty_lines, true),
      }.compact
    end

    def read_cells(sheet = default_sheet)
      return if @cells_loaded

      @reader = ::SmarterCSV::Reader.new(@filename, @smarter_csv_options)
      row_num = 0

      @reader.process do |chunk|
        chunk.each do |row_data|
          row_num += 1
          load_row(row_num, row_data)
        end
      end

      # Set boundaries
      @first_row[sheet] = 1
      @last_row[sheet] = [row_num, 1].max
      @first_column[sheet] = 1
      
      max_col = @cell.keys.map { |k| k[1] }.max || 1
      @last_column[sheet] = max_col

      @cells_loaded = true
    end

    def load_row(row_num, row_data)
      case row_data
      when Hash
        row_data.each_with_index do |(key, value), col_idx|
          col = col_idx + 1
          @cell[[row_num, col]] = value
          @cell_type[[row_num, col]] = infer_type(value)
        end
      when Array
        row_data.each_with_index do |value, col_idx|
          col = col_idx + 1
          @cell[[row_num, col]] = value
          @cell_type[[row_num, col]] = infer_type(value)
        end
      end
    end

    def infer_type(value)
      case value
      when NilClass then :empty
      when TrueClass, FalseClass then :boolean
      when Integer then :numeric
      when Float then :float
      when Date then :date
      when DateTime, Time then :datetime
      when String then value.empty? ? :empty : :string
      else :string
      end
    end

    # REQUIRED: Store operations
    def set_value(row, col, value, _sheet)
      @cell[[row, col]] = value
    end

    def set_type(row, col, type, _sheet)
      @cell_type[[row, col]] = type
    end

    alias_method :filename_or_stream, :filename
  end
end
