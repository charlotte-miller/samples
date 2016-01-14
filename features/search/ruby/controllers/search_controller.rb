class SearchController < ApplicationController
  include ElasticsearchHelpers

  skip_before_filter :verify_authenticity_token

  def index
    @results = Elasticsearch::Model.client.search({
      index: AppConfig.elasticsearch.index_name,
      type: types_w_defaults,
      # explain:true,
      # search_type:'count', #w/out hits
      body: {
        query: {
          bool: {
            must:{
              multi_match:{
                query: query,
                prefix_length:2,
                type: "best_fields",
                tie_breaker: 0.3,
                minimum_should_match: '75%',
                fields:[
                  "title.word_edge_ngrams",
                  "study_title.word_edge_ngrams",
                  "author.word_edge_ngrams",
                  "keywords.autocomplete",
                  "description",
                ]
              },
            },
            should:{
              multi_match:{
                query: query,
                prefix_length:2,
                type: "best_fields",
                tie_breaker: 0.3,
                minimum_should_match: '75%',
                fields:[
                  "title",
                  "keywords",
                  "study_title",
                  "author",

                  "title.phrase_bi_grams",
                  "title.phrase_tri_grams",
                  "description.phrase_bi_grams",
                  "description.phrase_tri_grams",
                ]
              },
            }
          }
        # end

        },
        # filter expired_at lt Time.now
        # sort:{
        #   last_published_at:{ order:'desc' },
        #   expired_at:{ order: 'asc' },
        # },

        highlight:{
          fields:{
            # title:{},
            # study_title:{},
            # author:{},
            description:{
              fragment_size: 80,
              number_of_fragments: 1
            },
            # 'description.phrase_bi_grams'=>{},
            # 'description.phrase_tri_grams'=>{},
          }
        },

        aggs: {
          type_counts: { terms:{ field:'_type' }}
        },
        _source: [:title, :preview, :path],
      }.merge(pagination_options)
    })

    filtered_results = {
      took: @results['took'],
      hits: @results['hits'],
      total_counts: total_counts,
    }

    render json: MultiJson.dump(filtered_results, pretty:false)
  end

  def preload
    @results = Elasticsearch::Model.client.search({
      index: AppConfig.elasticsearch.index_name,
      type: types_w_defaults,
      _source: [:title, :path], # :preview,
      body:{
        size:200,
        query:{match_all:{}}
      }
    })

    filtered_results = {
      took: @results['took'],
      hits: @results['hits'],
      # suggest: @results['suggest'],
      # total_counts: total_counts,
    }

    render json: MultiJson.dump(filtered_results, pretty:false)
  rescue Faraday::TimeoutError
    render json: MultiJson.dump({error:'timeout', took:0, hits:[]}, pretty:false)
  end

private

  def search_params
    # params.require(:q)
    @search_params ||= params.permit(:q, :types, :page, :results_count)
  end

  def query
    q = search_params[:q]
    q = q[0...80] #cap at 50 char
    # q = ElasticsearchHelpers.sanitize_string( q )
  end

  def types_w_defaults
    search_params[:types] || nil
  end

  def pagination_options
    return {} unless search_params[:page]

    page_size = 10
    result_count = page_size * search_params[:page]
    {
      size: page_size,
      from: result_count
    }
  end

  def total_counts
    hash_w_total = {total:@results['hits']['total']}
    if @results['aggregations']
      @results['aggregations']['type_counts']['buckets'].inject(hash_w_total) do |hash,obj|
        hash[obj['key']]= obj['doc_count']; hash
      end
    end
  end
end
