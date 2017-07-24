# Converts an obj into a 'polymorphic' hash and back into the @obj_instance
#
#   @lesson.to_findable_hash        #=> {klass:'Lesson', id:12}
#   {klass:'Lesson', id:12}.to_obj  #=> @lesson
#
# [Tip] Use w/ background workers to serialize objects into primative arguments
#
require 'rails_helper'

describe FindableHash do
  subject { AnyModel.new }

  describe 'ActiveRecord::Base#to_findable_hash' do
    it "reduces an obj to a 'polymorphic' style hash" do
      subject.to_findable_hash.should == {id:1, klass:'AnyModel'}
    end
  end

  describe 'Hash#to_obj' do
    it "raises NoMethodError w/out the proper keys" do
      lambda {
        {one:1, two:2}.to_obj
      }.should raise_error NoMethodError
    end

    it "finds the object based the hash" do
      AnyModel.should_receive(:find).with(1)
      {id:1, klass:'AnyModel'}.to_obj
    end
  end
end

class AnyModel < ActiveRecord::Base
  has_no_table
  def id; 1 ;end
end
