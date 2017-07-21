require 'rails_helper'

class DummySearchableClass
  include Searchable
  searchable_model
  define_singleton_method(:import){}
end

describe Searchable, :elasticsearch do
  subject { DummySearchableClass.new }
  let(:es_client) { Elasticsearch::Model.client }

  describe 'INDEX MANAGMENT' do
    let(:es_indices)    { es_client.indices }
    let(:index_options) { {index: DummySearchableClass.index_name} }
    import_models DummySearchableClass

    it "creates the index" do
      expect(es_indices.exists(index_options)).to be true
    end

    describe ".settings" do
      let(:searchable_settings) { DeepStruct.new DummySearchableClass.settings.to_hash }
      let(:es_settings) { DeepStruct.new es_indices.get_settings(index_options) }

      it 'configures .number_of_shards' do
        expect(es_settings.number_of_shards).to eq(searchable_settings.number_of_shards)
      end

      it 'configures .number_of_replicas' do
        expect(es_settings.number_of_replicas).to eq(searchable_settings.number_of_replicas)
      end

      describe '.analysis' do
        let(:searchable_analysis) { searchable_settings.index.analysis }
        let(:es_analysis) { es_settings.sporos_test.settings.index.analysis }

        describe '.filter' do
          it 'defines custom filters' do
            filteres = searchable_analysis.filter.to_h.keys
            expect(filteres).not_to be_empty
            filteres.each do |filter|
              expect(es_analysis.filter[filter]).to_not be_nil
            end
          end
        end

        describe '.analyzer' do
          it 'defines custom analyzer' do
            analyzers = searchable_analysis.analyzer.to_h.keys
            expect(analyzers).not_to be_empty
            analyzers.each do |analyzer|
              expect(es_analysis.analyzer[analyzer]).to_not be_nil
            end
          end
        end
      end
    end

    describe '.mappings' do
      let(:searchable_mappings) { DeepStruct.new( DummySearchableClass.mappings.to_hash ).dummysearchableclass }
      let(:es_mappings) { DeepStruct.new( es_indices.get(index_options) ).sporos_test.mappings.dummysearchableclass }

      it 'does NOT dynamicly define mappings' do
        expect(es_mappings.dynamic).to eq 'false'
      end

      it 'defines .properties' do
        properties = searchable_mappings.properties.to_h.keys
        expect(properties).not_to be_empty
        properties.each do |property|
          expect(es_mappings.properties[property]).to_not be_nil
        end
      end

    end
  end
end


