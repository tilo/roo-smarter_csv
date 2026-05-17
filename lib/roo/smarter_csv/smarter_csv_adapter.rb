# frozen_string_literal: true

require "csv"
require "date"
require_relative "version"

module Roo
  # Roo CSV adapter backed by SmarterCSV while preserving Roo's sheet-style API.
  class SmarterCSV
    attr_reader :filename, :reader

    COMPATIBLE_CSV_KEYS = %i[col_sep row_sep quote_char encoding].freeze
    DEFAULT_SMARTER_CSV_OPTIONS = {
      remove_empty_hashes: false
      # collect_raw_lines: false
    }.freeze

    def sheets
      ["default"]
    end

    def cell(row, col, sheet = nil)
      sheet ||= default_sheet
      read_cells(sheet)
      row, col = normalize(row, col)

      return @header_row[col - 1] if header_row?(row)

      row_hash = sparse_row_for(row)
      return nil unless row_hash

      key = header_key_for(col)
      return nil unless key
      return row_hash[key] if row_hash.key?(key)

      missing_cell_value
    end

    def celltype(row, col, sheet = nil)
      sheet ||= default_sheet
      read_cells(sheet)
      row, col = normalize(row, col)

      if header_row?(row)
        value = @header_row[col - 1]
        return value.nil? ? nil : infer_type(value)
      end

      row_hash = sparse_row_for(row)
      return nil unless row_hash

      key = header_key_for(col)
      return nil unless key
      return infer_type(row_hash[key]) if row_hash.key?(key)

      :empty
    end

    def row(row_number, sheet = default_sheet)
      read_cells(sheet)

      if header_row?(row_number)
        return @header_row.length < last_column(sheet) ? @header_row + Array.new(last_column(sheet) - @header_row.length) : @header_row.dup
      end

      row_hash = sparse_row_for(row_number)
      return [] unless row_hash

      @header_keys.map { |key| row_hash.fetch(key, missing_cell_value) }
    end

    def csv_options
      @options[:csv_options] || {}
    end

    def smarter_csv_options
      @smarter_csv_options ||= begin
        compat = csv_options.each_with_object({}) do |(key, value), result|
          symbol_key = key.to_sym
          result[symbol_key] = value if COMPATIBLE_CSV_KEYS.include?(symbol_key)
        end

        smarter = normalize_option_hash(@options[:smarter_csv])

        (compat.keys & smarter.keys).each do |key|
          warn "roo-smarter_csv: conflicting option #{key} found in csv_options and smarter_csv; using smarter_csv[:#{key}]"
        end

        DEFAULT_SMARTER_CSV_OPTIONS.merge(compat).merge(smarter)
      end
    end

    def set_value(row, col, value, _sheet)
      read_cells(default_sheet) unless @cells_read[default_sheet]
      row, col = normalize(row, col)

      if header_row?(row)
        ensure_header_width(col)
        @header_row[col - 1] = value
      else
        ensure_data_row(row)
        ensure_header_width(col)
        @rows[data_row_index(row)][header_key_for(col)] = value
      end

      recalculate_bounds
      value
    end

    def set_type(_row, _col, _type, _sheet)
      nil
    end

    alias filename_or_stream filename

    private

    def read_cells(sheet = default_sheet)
      sheet ||= default_sheet
      return if @cells_read[sheet]

      @reader = nil
      @header_row = []
      @header_keys = []
      @rows = []

      with_source do |source|
        @reader = ::SmarterCSV::Reader.new(source, smarter_csv_options)
        @reader.process do |row_data|
          store_rows(row_data)
        end

        @header_row = parsed_header_row(@reader)
        @header_keys = Array(@reader.headers).dup

        set_row_count(sheet, total_rows)
        set_column_count(sheet, [@header_row.length, @header_keys.length].max)
      end

      @cells_read[sheet] = true
    end

    def with_source
      if uri?(filename)
        ::Dir.mktmpdir(Roo::TEMP_PREFIX, ENV["ROO_TMP"]) do |tmpdir|
          yield download_uri(filename, tmpdir)
        end
      else
        yield filename_or_stream
      end
    end

    def parsed_header_row(reader)
      raw_header = reader.raw_header
      return [] unless raw_header

      header = ::CSV.parse_line(
        raw_header,
        col_sep: reader.options[:col_sep] || ",",
        quote_char: reader.options.fetch(:quote_char, '"')
      )

      Array(header)
    end

    def store_rows(row_data)
      case row_data
      when Array
        row_data.each { |entry| @rows << sparse_row_hash(entry) }
      else
        @rows << sparse_row_hash(row_data)
      end
    end

    def sparse_row_hash(row_data)
      case row_data
      when Hash
        row_data.dup
      when Array
        current_headers = Array(@reader&.headers)
        row_data.each_with_index.each_with_object({}) do |(value, index), result|
          key = current_headers[index] || generated_header_key(index + 1)
          result[key] = value
        end
      when NilClass
        {}
      else
        { generated_header_key(1) => row_data }
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

    def normalize_option_hash(hash)
      return {} unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = value
      end
    end

    def set_row_count(sheet, last_row)
      @first_row[sheet] = 1
      @last_row[sheet] = last_row
      @last_row[sheet] = @first_row[sheet] if @last_row[sheet].zero?
      nil
    end

    def set_column_count(sheet, last_col)
      @first_column[sheet] = 1
      @last_column[sheet] = last_col
      @last_column[sheet] = @first_column[sheet] if @last_column[sheet].zero?
      nil
    end

    def clean_sheet(sheet)
      read_cells(sheet)
      @header_row = @header_row.map { |value| value.is_a?(String) ? sanitize_value(value) : value }
      @rows.each do |row_hash|
        row_hash.each do |key, value|
          row_hash[key] = sanitize_value(value) if value.is_a?(String)
        end
      end
      @cleaned ||= {}
      @cleaned[sheet] = true
    end

    def sanitize_value(value)
      value.gsub(/[[:cntrl:]]|^\p{Space}+|\p{Space}+$/, "")
    end

    def reinitialize
      initialize(@filename, @options)
    end

    def header_row?(row)
      @header_row.any? && row == 1
    end

    def total_rows
      @rows.length + (@header_row.any? ? 1 : 0)
    end

    def sparse_row_for(row)
      index = data_row_index(row)
      return nil if index.negative? || index >= @rows.length

      @rows[index]
    end

    def data_row_index(row)
      row - (@header_row.any? ? 2 : 1)
    end

    def header_key_for(col)
      @header_keys[col - 1]
    end

    def missing_cell_value
      nil
    end

    def ensure_data_row(row)
      @rows << {} while data_row_index(row) >= @rows.length
    end

    def ensure_header_width(col)
      @header_keys << generated_header_key(@header_keys.length + 1) while @header_keys.length < col
      @header_row << nil while @header_row.length < col
    end

    def generated_header_key(col)
      "column_#{col}".to_sym
    end

    def recalculate_bounds
      sheet = default_sheet
      @first_row[sheet] = 1
      @last_row[sheet] = total_rows.zero? ? 1 : total_rows
      @first_column[sheet] = 1
      @last_column[sheet] = [@header_row.length, @header_keys.length].max
      @last_column[sheet] = 1 if @last_column[sheet].zero?
    end
  end
end
