namespace :maticart do
  desc "Updating notification images process."
  task notification_image_processing: :environment do
    Notification.find_each do |notification|
      if notification.redirect_path&.match(/collections/)
        collection_address = notification.redirect_path.split("/").last
        collection = Collection.unscoped.find_by(address: collection_address)
        notification.update(image_url: Notification.collection_image_url(collection))
      end
    end
  end
  desc "process collection media variants."
  task collection_process_attachment_variations: :environment do
    Collection.attachment_variation_hook.each do |variation|
      Collection.unscoped.all.each do |collection|
        AttachmentResizingJob.perform_async(collection.attachment.id, variation.to_s) if collection.attachment.attached?
      end
    end
  end
  task collection_process_cover_variations: :environment do
    Collection.cover_variation_hook.each do |variation|
      Collection.unscoped.all.each do |collection|
        AttachmentResizingJob.perform_async(collection.cover.id, variation.to_s) if collection.cover.attached?
      end
    end
  end
end
