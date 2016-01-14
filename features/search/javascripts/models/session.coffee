class CStone.Community.Search.Models.Session extends Backbone.RelationalModel
  urlRoot: '/search_sessions'

  initialize: =>
    @on 'change:current_search',   @_searchSourcesForCurrentSearch
    @on 'change:current_search',   _.debounce @_storeSearchHistory, 2000 #2 sec
    @on 'change:convertable_id',   @_storeSearchHistory
    @on 'change:dropdown_visible', @_hideHintWhenHidingDropdown
    @on 'change:dropdown_visible', @_clearActiveUiWhenHidingDropdown
    @listenTo @get('results'), 'filtered:change', @_updateCurrentHint
    @listenTo @get('results'), 'filtered:reset',  @_updateCurrentHint
    @listenTo @get('results'), 'filtered:change',          @_updateSources
    @listenTo @get('results'), 'filtered:reset',           @_updateSources
    @listenTo @get('results'), 'filtered:filtered:reset',  @_updateSources

  defaults:
    dropdown_visible:false
    hint_visible:false
    active_ui:null #['main','header']
    current_search:''
    current_hint:''
    current_hint_w_original_capitalization:''

  relations: _([
    {
      type:            'HasMany'
      key:             'results'
      relatedModel:    'CStone.Community.Search.Models.Result'
      collectionType:  'CStone.Community.Search.Collections.Results'
    },
    {
      type:            'HasMany'
      key:             'sources'
      relatedModel:    'CStone.Community.Search.Models.AbstractSource'
      collectionType:  'CStone.Community.Search.Collections.Sources'
    },
    # {
    #   type:            'HasOne'
    #   key:             'search_history'
    #   relatedModel:    'CStone.Community.Search.Models.SearchHistory'
    # }
  ]).map (relation)-> _(relation).extend(reverseRelation: {key:'session', type:'HasOne'})

  toJSON:=>
    _(super).extend
      search_session:
        search_type: @get('results').currentFilter()
        query: @get('current_search')
        results_count: @get('results').length
        convertable_id:   @get('convertable_id')
        convertable_type: @get('convertable_type')
        ui_session_data: JSON.stringify(_(@attributes).pick('active_ui', 'current_hint', 'hint_visible'))

  # Public Helpers
  # ----------------------------------------------------------------------

  searchState: =>
    is_searching = !!@get('current_search')
    return 'pre-search'   unless is_searching
    return 'searching'    if is_searching && @get('results').length
    return 'no-results'   if is_searching

  acceptHint: =>
    @set {current_search: @get('current_hint')}

  # toggle dropdown_visible, hint_visible, etc.
  toggle: (flag, additional_options)=>
    val = @get(flag)
    throw new Error('Cannot Toggle a non-boolean value') unless _(val).isBoolean()
    @set(additional_options) if additional_options
    @set(flag, !val)

  openFocused: =>
    eureka = @get('results').currentFocus()
    return unless eureka
    @set({convertable_id:eureka.get('id'), convertable_type:eureka.get('source')})
    eureka.open()

  moveFocus: (up_down)=>
    @get('results').moveFocus(up_down)

  # Internal
  # ----------------------------------------------------------------------

  _searchSourcesForCurrentSearch: =>
    query = @get('current_search')
    return if ///^#{@previous('current_search')||''}$///i.test query
    if query
      @get('sources').search(query)
    else
      @get('results').reset()
      @get('sources').clearRemotelyBuiltIndexes()

  _hideHintWhenHidingDropdown: =>
    @set(hint_visible:false) unless @get('dropdown_visible')

  _updateCurrentHint: =>
    current_search = @get('current_search')
    focused =  @get('results').currentFocus() && @get('results').currentFocus().get('payload')
    case_indiferent_matcher = ///^.*#{current_search}///i
    if focused && case_indiferent_matcher.test focused
      hint = focused.toLowerCase().replace case_indiferent_matcher, current_search
      hint = hint.replace( ///(#{current_search}[^\:|\-|\?|\!|\.|\(|\)]*).*$///i, '$1').trim()
      unless single_word = /\s/.test hint
        hint_phrase = focused.match( ///([^\:|\-|\?|\!|\.]*#{current_search}).*$///i )[0]
        hint_phrase = hint_phrase.replace( ///(#{current_search}[^\:|\-|\?|\!|\.]*).*$///i, '$1').trim()
        hint = "#{hint} - #{hint_phrase}"
      @set(current_hint: hint, current_hint_w_original_capitalization: focused, hint_visible:true)
    else
      @set(current_hint: '', current_hint_w_original_capitalization: '', hint_visible:false)

  _clearActiveUiWhenHidingDropdown: =>
    @set(active_ui:null) unless @get('dropdown_visible')

  _updateSources: =>
    results_collection = @get('results')
    sources_collection = @get('sources')
    sources = results_collection.sources()
    filter = if sources.length == 1 then sources[0] else results_collection.currentFilter()
    to_focus = sources_collection.findWhere({
      name: filter
    })
    sources_collection.updateFocus(to_focus)

  _storeSearchHistory:=>
    return if @searchState() == 'pre-search'
    @save()
    .done =>
      @set({convertable_id:undefined, convertable_type:undefined, converted_at:undefined}, silent: true)

    # add @get('current_search') to a seperate SearchHistory object
    # collaps typing into the 'final' product
    # store the selected (opened) result
    # store dead-ends (zero results) and the next thing they search/select

CStone.Community.Search.Models.Session.setup()
