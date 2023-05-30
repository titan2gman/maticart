module ActiveStorageHook
  extend ActiveSupport::Concern

  def process_variation_later
    hook_name = name+"_variation_hook"
    if record_type.constantize.respond_to?(hook_name.to_sym)
      record_type.constantize.send(hook_name.to_sym).each {
        |variation| Rails.logger.warn AttachmentResizingJob.perform_async(id, variation.to_s)
      }
    end
  end

  included do
    after_create_commit :process_variation_later
  end
end

