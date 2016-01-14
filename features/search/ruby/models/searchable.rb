# ===Adds helpers for ElasticSearch Integration
#
module Searchable
  extend ActiveSupport::Concern

  REQUIRED_KEYS = [:title, :display_description, :path, :description, :keywords]

  included do
    include Sanitizable
    include ActionView::Helpers::TextHelper #truncate, excerpt, hightlight, etc.
    include Elasticsearch::Model
    delegate :url_helpers, to: 'Rails.application.routes'

    # include Elasticsearch::Model::Callbacks  # https://github.com/elasticsearch/elasticsearch-rails/tree/master/elasticsearch-model#asynchronous-callbacks

    class << self
      def import_with_scope( options = {} )
        import_without_scope({ scope: 'search_indexable' }.merge(options))
      end
      alias_method_chain :import, :scope
    end
  end

  module ClassMethods

    def searchable_model( options={}, &specific_indexes )
      options = DeepStruct.new(options)

      class_eval do
        index_name     AppConfig.elasticsearch.index_name
        document_type  (options.type || name.demodulize.downcase).to_sym

        settings index: {
          number_of_shards: 1,
          number_of_replicas: 0,
          analysis: {
            # tokenizer:   { ...    custom tokenizers     ... },
            filter: {
              word_edge_ngram:{
                type:'edge_ngram',
                min_gram:3,
                max_gram:20,
              },

              phrase_bi_gram:{
                type:'shingle',
                output_unigrams:false,
              },

              phrase_tri_gram:{
                type:'shingle',
                min_shingle_size:3,
                max_shingle_size:3,
                output_unigrams:false,
              },

              # wordnet_synonym:{
              #   type:'synonym',
              #   format:'wordnet',
              #   synonyms_path:'/var/lib/wn_s.pl'
              # },

              cstone_synonyms:{
                type:'synonym',
                synonyms:[
                  'sermon => message',
                  'christ => jesus',
                ]
              },

              cstone_stopwords:{
                type:'stop',
                stopwords:['pastor', 'chruch']
              },

              word_edge_ngram__range:{
                # Don't search for terms that are longer or shorter then the avalible ngrams
                type:'length',
                min:3,
                max:20,
              },

              query_length_cap:{
                # Don't make terms that are longer then the searchable length in SearchController
                type:'length',
                max:80,
              },

              common_leading_stopword:{
                type:'pattern_replace',
                pattern:"^(an?|the)\b",
                replacement:'',
                preserve_original:true
              }
            },

            char_filter: {
              "&_to_and" => {
                type: 'mapping',
                mappings: [ '&=> and ']
              },

              "@_to_at" => {
                type: 'pattern_replace',
                pattern: '\s+@\s+',
                replacement:' at '
              },
            },

            analyzer: {
              html_stem: {
                type:'custom',
                char_filter: ['html_strip', '&_to_and', '@_to_at'],
                tokenizer: 'classic',
                filter:['trim', 'lowercase', 'asciifolding', 'stop', 'cstone_synonyms', 'cstone_stopwords', 'porter_stem'], #'wordnet_synonym'
              },

              html_word_edge_ngram__index:{
                type:'custom',
                char_filter: ['html_strip', '&_to_and', '@_to_at'],
                tokenizer: 'classic',
                filter:['trim', 'lowercase', 'asciifolding', 'common_leading_stopword', 'cstone_synonyms', 'kstem', 'word_edge_ngram__range', 'word_edge_ngram'],
              },

              html_word_edge_ngram__search:{
                type:'custom',
                char_filter: ['html_strip', '&_to_and', '@_to_at'],
                tokenizer: 'classic',
                filter:['trim', 'lowercase', 'asciifolding', 'common_leading_stopword', 'cstone_synonyms', 'kstem', 'word_edge_ngram__range'],
              },

              html_phrase_bi_gram:{
                type:'custom',
                char_filter: ['html_strip', '&_to_and', '@_to_at'],
                tokenizer: 'classic',
                filter:['trim', 'lowercase', 'asciifolding', 'common_leading_stopword', 'cstone_synonyms', 'phrase_bi_gram', 'query_length_cap'], #'wordnet_synonym',
              },

              html_phrase_tri_gram:{
                type:'custom',
                char_filter: ['html_strip', '&_to_and', '@_to_at'],
                tokenizer: 'classic',
                filter:['trim', 'lowercase', 'asciifolding', 'common_leading_stopword', 'cstone_synonyms', 'phrase_tri_gram', 'query_length_cap'], #'wordnet_synonym',
              },
            },
          }
        } do
          mappings dynamic: 'false' do
            #Indexes are not automaticly created and must be added by code to be searched

            indexes :title,
                     analyzer: 'html_stem', boost: 3,
                     fields:{

                       word_edge_ngrams:{
                         type:'string',
                         index_analyzer:  'html_word_edge_ngram__index',
                         search_analyzer: 'html_word_edge_ngram__search',
                       },

                       phrase_bi_grams:{
                         type:'string',
                         analyzer:'html_phrase_bi_gram',
                         boost: 5,
                       },

                       phrase_tri_grams:{
                         type:'string',
                         analyzer:'html_phrase_tri_gram',
                         boost: 8,
                       },
                     }

            indexes :description,
                     analyzer: 'html_stem', boost:0.5, #(-%50)
                     term_vector: "with_positions_offsets",
                     fields:{

                       # word_edge_ngrams:{
                       #   type:'string',
                       #   index_analyzer:  'html_word_edge_ngram__index',
                       #   search_analyzer: 'html_word_edge_ngram__search'
                       # },

                       phrase_bi_grams:{
                         type:'string',
                         analyzer:'html_phrase_bi_gram',
                         boost:3
                       },

                       phrase_tri_grams:{
                         type:'string',
                         analyzer:'html_phrase_tri_gram',
                         boost: 5,
                       },
                     }

            indexes :keywords,
                     analyzer: 'keyword',
                     fields:{
                       # POPULAR TERMS ONLY? COMMON PHRASES?
                       # These have to start at the begining... so they are not well suited to title / description
                       # Better for keywords / questions etc.
                       #
                       autocomplete:{
                         type:'completion',
                         index_analyzer:'keyword',
                         search_analyzer:'keyword',
                         payloads:true,             # {path:'/blah'}
                         preserve_separators:true,  #foof != foo fighters
                       }
                     }
                     # boost:2.0
                     #might makes sense to stem bible verses

            # Not Searchable
            indexes :path,                index:'no'
            indexes :display_description, index:'no'

            # Add model specific indexes
            instance_eval( &specific_indexes ) if block_given?
          end
        end
      end
    end

  end #ClassMethods


private

  # Helpers - could be analyzers
  def shorter_plain_text(str, truncate_options={})
    truncate( plain_text(str), {
      length:80,
      omission:'...',
      separator: ' '
    }.merge(truncate_options))
  end

  # def dont_stem(*terms)
  #   (BOOKS_OF_THE_BIBLE | terms).map(&:downcase).uniq
  # end
end
