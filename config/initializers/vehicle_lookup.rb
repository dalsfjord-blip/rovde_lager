Rails.application.config.vehicle_lookup = ActiveSupport::OrderedOptions.new
Rails.application.config.vehicle_lookup.enabled = ENV.fetch("ENABLE_VEHICLE_LOOKUP", true)
Rails.application.config.vehicle_lookup.api_key = Rails.application.credentials.vegvesenet_api_key || ENV["VEGVESENET_API_KEY"]
