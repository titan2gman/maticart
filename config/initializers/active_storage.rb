require 'ext/active_storage/attachment'
ActiveSupport.on_load(:active_storage_attachment) do
  include ActiveStorageHook
end

Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy

