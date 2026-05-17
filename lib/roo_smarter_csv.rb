# frozen_string_literal: true

require "roo"
require "smarter_csv"
require_relative "roo/smarter_csv/smarter_csv_adapter"

# Roo namespace extensions for the SmarterCSV-backed CSV adapter.
module Roo
  # Registers the SmarterCSV-backed CSV adapter as Roo's CSV handler.
  CLASS_FOR_EXTENSION.merge!(
    csv: Roo::SmarterCSV
  )
end
