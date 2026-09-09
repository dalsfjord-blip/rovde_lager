# Configure Active Storage for local development and production
Rails.application.config.active_storage.service_configurations = {
  local: {
    service: "Disk",
    root: Rails.root.join("storage")
  },
  test: {
    service: "Disk",
    root: Rails.root.join("tmp/storage")
  }
}

# Set the default service based on environment
if Rails.env.development? || Rails.env.test?
  Rails.application.config.active_storage.default_service = :local
else
  # For production, you can configure S3, Cloudflare R2, or other services
  Rails.application.config.active_storage.default_service = :local
end
