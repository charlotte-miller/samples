# == Schema Information
#
# Table name: faqs
#
#  id                :integer          not null, primary key
#  faq_answer_id     :integer
#  body              :text             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  author_email      :string
#  author_email_body :text
#
# Indexes
#
#  index_faqs_on_faq_answer_id  (faq_answer_id)
#

class Faq < ActiveRecord::Base
  include Searchable

  belongs_to :faq_answer#, :class_name => "FaqAnswer", :foreign_key => "faq_answer_id"

  searchable_model type: :question # [title, preview, description, keywords, path] are already declaired

  scope :search_indexable, lambda { where('faq_answer_id IS NOT NULL') }

  def as_indexed_json(options={})
    {
      title:       body,
      preview:     shorter_plain_text(answer.body),
      path:        answer.more_info_path,
      description: answer.body,
      keywords:    [],
    }
  end


end
