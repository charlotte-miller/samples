require 'rails_helper'
require 'set'

shared_examples 'it is Searchable' do |options|
  before(:all) do
    options = {
      klass: described_class,
      factory_name:nil,
    }.merge(options || {})

    @klass   = options[:klass]
    @factory = options[:factory_name] ||= @klass.to_s.downcase.to_sym
    @collection = 3.times.map { create(@factory) }
  end

  subject {build_stubbed(@factory)}

  describe 'Elasticsearch Integration -', :elasticsearch do
    describe '.import' do
      before(:each) { @klass.__elasticsearch__.create_index!(force: true) }
      after(:each)  { @klass.__elasticsearch__.create_index!(force: true) }

      it 'imports successfully' do
        expect( lambda {@klass.import}).not_to raise_error
        wait_for_success(3) { @klass.search('*').present? }
        expect(@klass.search('*').records.to_a).to eq(@collection)
      end

      it 'excludes unpublished studies' do
        skip 'implementation'
      end
    end

    describe '#as_indexed_json(options={})' do
      it 'accepts options' do
        expect(lambda {subject.as_indexed_json({foo:'bar'})}).not_to raise_error
      end

      it 'returns a hash' do
        expect(subject.as_indexed_json).to be_a(Hash)
      end

      it 'includes a the Searchable::REQUIRED_KEYS' do
        Searchable::REQUIRED_KEYS.each do |key|
           expect(subject.as_indexed_json.keys).to include(key)
        end
      end
    end
  end

  describe 'Common Helpers -' do
    describe '#url_helpers' do
      it 'delegates to Rails routes' do
        expect(Rails.application.routes).to receive(:url_for).with(:foo)
        subject.url_helpers.url_for(:foo)
      end
    end
  end

end
