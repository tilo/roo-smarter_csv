# frozen_string_literal: true

require 'roo'
require 'smarter_csv'

module Roo
  autoload :SmarterCSV, 'roo/smarter_csv/smarter_csv_adapter'

  # Override default CSV handler with SmarterCSV backend
  CLASS_FOR_EXTENSION.merge!(
    csv: Roo::SmarterCSV
  )
end
