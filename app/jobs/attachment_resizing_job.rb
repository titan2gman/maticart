class AttachmentResizingJob
  include Sidekiq::Worker
  sidekiq_options queue: 'high'

  def perform(attachment_id, variation)
    attachment = ActiveStorage::Attachment.find(attachment_id)
    logger.info "Resizing attachment '#{attachment.name}' id: #{attachment_id} with variation :#{variation}"
    if attachment.variable?
      variation = attachment.record_type.constantize::MEDIA_VARIANTS[variation.to_sym] 
      attachment.variant(variation).processed
    else
      logger.warn "Attachment #{attachment_id} (#{attachment.record_type}.#{attachment.name}) is not variable"
    end
  end
end
