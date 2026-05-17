# frozen_string_literal: true

require "csv"
require "date"
require_relative "version"

module Roo
  class SmarterCSV
    attr_reader :filename, :reader

    COMPATIBLE_CSV_KEYS = %i[col_sep row_sep quote_char encoding].freeze

    def sheets
      ["default"]
    end

    def cell(row, col, sheet = nil)
      sheet ||= default_sheet
      read_cells(sheet)
      @cell[normalize(row, col)]
    end

    def celltype(row, col, sheet = nil)
      sheet ||= default_sheet
      read_cells(sheet)
      @cell_type[normalize(row, col)]
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

        compat.merge(smarter)
      end
    end

    def set_value(row, col, value, _sheet)
      @cell[[row, col]] = value
    end

    def set_type(row, col, type, _sheet)
      @cell_type[[row, col]] = type
    end

    alias_method :filename_or_stream, :filename

    private

    def read_cells(sheet = default_sheet)
      sheet ||= default_sheet
      return if @cells_read[sheet]

      @reader = nil

      with_source do |source|
        @reader = ::SmarterCSV::Reader.new(source, smarter_csv_options)
        rows = @reader.process

        header_row = parsed_header_row(@reader)
        row_num = 0
        max_col_num = 0

        if header_row.any?
          row_num = 1
          store_row(row_num, header_row)
          max_col_num = [max_col_num, header_row.length].max
        end

        rows.each do |row_data|
          row_num += 1
          max_col_num = [max_col_num, store_row(row_num, row_data)].max
        end

        set_row_count(sheet, row_num)
        set_column_count(sheet, max_col_num)
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

    def store_row(row_num, row_data)
      values = case row_data
               when Hash
                 row_data.each_with_object([]) { |(_, value), result| result << value }
               when Array
                 row_data.dup
               else
                 Array(row_data)
               end

      values.each_with_index do |value, col_idx|
        coordinate = [row_num, col_idx + 1]
        @cell[coordinate] = value
        @cell_type[coordinate] = infer_type(value)
      end

      values.length
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
      @cell.each_pair do |coord, value|
        @cell[coord] = sanitize_value(value) if value.is_a?(::String)
      end
      @cleaned ||= {}
      @cleaned[sheet] = true
    end

    def sanitize_value(value)
      value.gsub(/[[:cntrl:]]|^[\p{Space}]+|[\p{Space}]+$/, "")
    end

    def reinitialize
      initialize(@filename, @options)
    end
  end
end
