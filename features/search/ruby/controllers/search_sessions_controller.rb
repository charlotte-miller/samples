class SearchSessionsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_action :set_search_session, only: [:show, :update]

  respond_to :html, :json

  # GET /search_sessions/1
  def show
    respond_with(@search_session)
  end

  # POST /search_sessions
  def create
    # @search_session = SearchSession.new(search_session_params)

    if set_search_session #@search_session.save
      respond_with(@search_session)
    else
      head :not_accetable
    end
  end

  # PATCH/PUT /search_sessions/1
  def update
    if set_search_session #@search_session.update(search_session_params)
      respond_with(@search_session)
    else
      head :not_accetable
    end
  end

  # # POST search/conversion
  # def conversion
  #   current_search.convert(params[:something_meaningful])
  #   # search_type
  #   head :ok
  # end
  #
  # # POST search/abandonment
  # def abandonment
  #   current_search.query = feedback_params[:current_search],
  #   current_search.results_count = search_params[:results_count]
  #   current_search.save if current_search.changed?
  #
  #   head :ok
  # end

private

  # Only allow a trusted parameter "white list" through.
  def search_session_params
    @search_session_params ||= params.require(:search_session).permit(:search_type, :query, :results_count, :convertable_id, :convertable_type, :ui_session_data)
  end

  def set_search_session
    #  @search_session = SearchSession.find_by(id: params[:id], rails_session_id:session.id)

    @search_session = SearchSession
    @search_session = @search_session.where( rails_session_id: session.id )
    @search_session = @search_session.where( "converted_at IS NULL" )
    if search_session_params[:results_count] == 0
      @search_session = @search_session.where( "results_count > 0" ) #keep dead ends for inspection
    else
      @search_session = @search_session.where( "results_count > 0" ) #keep dead ends for inspection
    end
    @search_session = @search_session.where( "updated_at > ?", 1.minute.ago ) #stale
    @search_session = @search_session.order( "updated_at DESC" )
    @search_session = @search_session.first

    # Create a new search_session unless this is MORE of the previous search

    is_continuted = @search_session && (/^#{@search_session.query}/ =~ search_session_params[:query] ||
                                        /^#{search_session_params[:query]}/ =~ @search_session.query)

    if is_continuted
      @search_session.update_attributes(search_session_params)
    else
      @search_session = SearchSession.create(search_session_params.merge({ rails_session_id: session.id }))
    end
    return @search_session
  end
end
