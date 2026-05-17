# frozen_string_literal: true

require "roo"
require "smarter_csv"
require_relative "roo/smarter_csv/version"

module Roo
  class SmarterCSV < Roo::Base
    VERSION = ROO_SMARTER_CSV_VERSION
  end
end

require_relative "roo/smarter_csv/smarter_csv_adapter"

# Roo namespace extensions for the SmarterCSV-backed CSV adapter.
module Roo
  # Registers the SmarterCSV-backed CSV adapter as Roo's CSV handler.
  CLASS_FOR_EXTENSION.merge!(
    csv: Roo::SmarterCSV
  )
end
