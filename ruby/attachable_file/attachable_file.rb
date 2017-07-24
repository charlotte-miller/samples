# === Configures Paperclip/S3
# - Provides a _generic_ method for storing files in the cloud
# - Adds the +<attachment>_remote_url=+ method to process hosted files asyncanously
#
module AttachableFile
  extend ActiveSupport::Concern

  module ClassMethods
    # === Usage:
    #  has_attached_file, :video, path: ':rails_env/:class/:attachment/:updated_at-:basename.:extension'
    #
    # *Generates:*
    #  has_attached_file :video,
    #    :storage          => :s3,
    #    :s3_storage_class => :reduced_redundancy,
    #    :s3_permissions   => :public_read,
    #    :bucket           => AppConfig.s3.bucket,
    #    :s3_credentials   => AppConfig.s3.credentials,
    #    :path             => ':rails_env/:class/:attachment/:updated_at-:basename.:extension'
    #
    #  process_in_background :video
    #  validates_attachment_content_type :video, :content_type => ['vidoe/mp4']
    #
    #  attr_accessor :video_original_url
    #  attr_reader :video_remote_url
    #  def video_remote_url=(url_str)
    #    return if url_str.nil?
    #    self.video_original_url = @video_remote_url = url_str
    #    (@attachments_for_processing ||= []) << :video
    #
    #    # require lib/extensions/active_record/instance_after_save
    #    def self.after_save
    #      return if @already_queued
    #      AttachmentDownloader.perform_async(self.to_findable_hash, @attachments_for_processing) && @already_queued=true
    #    end
    #  end
    #
    #
    def has_attachable_file( attachment_name, options={} )
      options[:path] = environment_specific_path(options)

      class_eval do
        has_attached_file attachment_name, {
          :storage          => :s3,
          :s3_storage_class => :reduced_redundancy,
          :s3_permissions   => :public_read,
          :bucket           => AppConfig.s3.bucket,
          :s3_credentials   => AppConfig.s3.credentials,
          :s3_host_name     => AppConfig.s3.url,
          :hash_secret      => AppConfig.paperclip.hash_secret,
          :hash_data        => ":class/:id/:attachment/:fingerprint-:style",
          :s3_host_alias    => lambda {|attach| AppConfig.domains.assets.gsub('%d', '')}, #rand(0..3).to_s # Override for large media assets
          :url              => ':s3_alias_url',
        }.deep_merge(options)

        unless options[:process_immediately]
          #https://github.com/jrgifford/delayed_paperclip/issues/83
          # process_in_background attachment_name
        end

        if Rails.env.test?
          do_not_validate_attachment_file_type attachment_name
        else
          validates_attachment_content_type attachment_name, :content_type => options[:content_type]
        end
      end

      # https://github.com/thoughtbot/paperclip/wiki/Attachment-downloaded-from-a-URL
      class_eval %Q{
        # non_original_url compatability
        attr_accessor :#{attachment_name}_original_url unless column_names.include? '#{attachment_name}_original_url'

        attr_reader :#{attachment_name}_remote_url
        def #{attachment_name}_remote_url=(url_str)
          return if url_str.nil?
          clean_url_str = 3.times.inject(url_str) {|memo,i| memo = URI.unescape(memo).strip }
          self.#{attachment_name}_original_url = @#{attachment_name}_remote_url = URI.escape( clean_url_str )
          (@attachments_for_processing ||= []) << :#{attachment_name}

          # require lib/extensions/active_record/instance_after_save
          def self.after_save
            return if @already_queued
            AttachmentDownloader.perform_async(self.to_findable_hash, @attachments_for_processing) && @already_queued=true
          end
        end
      }

    # Required for rails to load before the database is migrated
    rescue StandardError => error
      raise error if self.table_exists?
    end

  private

    def environment_specific_path(has_attached_file_options)
      production_path = has_attached_file_options[:production_path] || ':class/:attachment/:hash.:extension'
                 path = has_attached_file_options[:path]            || ':rails_env/:class/:id/:attachment/:style.:extension'

      (Rails.env.production? && production_path) || path
    end

  end
end
