# Uses PostgreSQL JSON Type
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

require 'rails_helper'

RSpec.describe DelegateAttrsToJsonb do
  subject {AnyModelCanDelegateToJsonb.new }

  it 'wraps the JSON column in a DeepStruct' do
    expect(subject.some_jsonb_attr).to be_a DeepStruct
  end

  it 'creates "getter" methods for the delegated methods' do
    expect(defined? subject.foop).to eql 'method'

  end

  it 'creates "setter" methods for the delegated methods' do
    expect(defined? subject.foop='val').to eql 'method'
  end

  it 'sets the correct value' do
    subject.foop = "Would you foop in a box"
    subject.woop = "Would you woop with a fox"
    expect(subject.foop).to eq("Would you foop in a box")
    expect(subject.woop).to eq("Would you woop with a fox")
  end
end

class AnyModelCanDelegateToJsonb < ActiveRecord::Base
  has_no_table
  column :some_jsonb_attr, :jsonb

  delegate_attrs_to_jsonb :foop, :woop, to: :some_jsonb_attr
end
