# attr_accessors for a serialized column
# Perfect for single table inheritance
#
# Usage:
# class SocialPost::Image
#  delegate_attrs_to_jsonb :img_height, :img_width, to:'post_details'
#  ...
#
# class SocialPost::Video
#  delegate_attrs_to_jsonb :video_duration, to:'post_details'
#  ...
#

module DelegateAttrsToJsonb
  extend ActiveSupport::Concern

  module ClassMethods
    def delegate_attrs_to_jsonb *args #options={to:jsonb_col}
      options    = args.extract_options!
      jsonb_col  = options[:to]
      attr_names = args
      attr_names.each do |attr_name|
        self.table_name.classify.constantize.send(:define_method , jsonb_col ){ DeepStruct.new super() }
        delegate *attr_names, to:jsonb_col

        attr_names.each do |virtual_attr|
          self.table_name.classify.constantize.send( :define_method, "#{virtual_attr}=" ) do |val|
            working_copy = self.send(jsonb_col).to_h
            working_copy[virtual_attr]= val
            self.send "#{jsonb_col}=", working_copy
          end
        end

      end
    end

  end
end

# include the extension
ActiveRecord::Base.send(:include, DelegateAttrsToJsonb)
