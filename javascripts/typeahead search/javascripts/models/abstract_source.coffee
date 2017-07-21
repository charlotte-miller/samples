class CStone.Community.Search.Models.AbstractSource extends Backbone.RelationalModel
  STOPWORDS = """
    I a about an am are as be by for from
    how in is it of on or that the this to
    was what when where who will with w/ the
  """.toLowerCase().split(/\s+/)

  REPLACEMENTS = [
    ['@', 'at'],
    ['&', 'and'],
    [',', ''],
    ['\\+', 'and'],
    ['[\\[|\\(|\\)|\\]]', ''],   # ()
    ['\\s?-\\s?', ' '],          # -
    ['\\s?:', ''],               # :
  ]

  subModelTypeAttribute: 'name'
  subModelTypes:
    'event'        : 'CStone.Community.Search.Models.Sources.Event'
    'ministry'     : 'CStone.Community.Search.Models.Sources.Ministry'
    'combined'     : 'CStone.Community.Search.Models.Sources.Combined'
    'music'        : 'CStone.Community.Search.Models.Sources.CombinedAdapter'
    'video'        : 'CStone.Community.Search.Models.Sources.CombinedAdapter'
    'page'         : 'CStone.Community.Search.Models.Sources.CombinedAdapter'
    'question'     : 'CStone.Community.Search.Models.Sources.CombinedAdapter'
    'sermon'       : 'CStone.Community.Search.Models.Sources.CombinedAdapter'


  initialize: =>
    _(['name']).forEach (requirement)=>
      throw Error("A Source MUST have a #{requirement}") unless @get(requirement)

    unless @get('title')
      name = @get('name')
      @set(title: name.charAt(0).toUpperCase() + name.slice(1))

    # https://github.com/twitter/typeahead.js/blob/master/doc/bloodhound.md#options
    bloodhound_options =
      name:           @get 'name'
      datumTokenizer: @defaultDatumTokenizer
      queryTokenizer: @defaultQueryTokenizer
      identify:       identifyDatum
      sorter:         defaultSorter
      sufficient:     10
      local:          @get 'local'
      remote:         @get 'remote'
      prefetch:       @get 'prefetch'

    @bloodhound = new Bloodhound( bloodhound_options )

  search: (query)=>
    handleLocalSearch = (datums)=>
      @get('session').get('results').updateFromSource( @processResults(datums), @ )

    handleRemoteSearch = (datums)=>
      if @get('elasticsearch')
        unless _(datums).isEmpty()
          @get('session').get('sources').updateTotalCounts( datums[0].total_counts )
          clean_datums = _(datums).map (d)-> delete d.total_counts && d
          @bloodhound.add( clean_datums )
        datums = @bloodhound.index.search(query)
      @get('session').get('results').updateFromSource( @processResults(datums), @ )

    @bloodhound.search query, handleLocalSearch, handleRemoteSearch

  processResults: (results)-> results # Abstract Funciton - Overwrite in child

  defaultDatumTokenizer: (datum)->
    q = datum.payload.toLowerCase().trim()
    q = charFilter(q)
    tokens = _([
      [q],
      significantWordTokenizer(q),
      wordShinglesTokenizer(q),
    ]).inject(((memo,tokens)->_.union(memo,tokens)),[])
    # console.log "Data: ['#{tokens.join('\', \'')}']"
    tokens

  defaultQueryTokenizer: (query)->
    q = query.toLowerCase().trim()
    q = charFilter(q)
    tokens = _([
      [q],
      queryTailTokenizer(q),
    ]).inject(((memo,tokens)->_.union(memo,tokens)),[])
    # console.log "Query: ['#{tokens.join('\', \'')}']"
    tokens

  wordShinglesTokenizer = (query, shingle_size=3, final_shingle_size=2)->
    q_array = Bloodhound.tokenizers.whitespace(query)
    _q_array = _.chain(q_array).map (word, i)->
      return if q_array.length - (i+shingle_size) < (final_shingle_size - shingle_size)
      q_array.slice(i, i + shingle_size).join(' ')
    _q_array.compact().value()

  queryTailTokenizer = (query)->
    tokens= []
    q_array = Bloodhound.tokenizers.whitespace(query)
    while q_array.length
      q_array.shift()
      break unless q_array.length > 1
      tokens.push q_array.join(' ')
    return tokens

  significantWordTokenizer = (query)->
    q_array = Bloodhound.tokenizers.whitespace(query)
    q_array = _(q_array).difference( STOPWORDS )

  charFilter = (str)->
    _(REPLACEMENTS).each (pair)->
      [regex, replacement] = pair
      str= str.replace(///#{regex}///g, replacement)
    str


  identifyDatum = (datum)-> datum.id
  defaultSorter = (a, b) ->
    # Sort series chronologically
    # a_match = a.payload.match(/(.*)(\d)/)
    # b_match = b.payload.match(/(.*)(\d)/)
    # if a_match && b_match && a_match[1] == b_match[1]
    #   if parseInt(a_match[2]) > parseInt(b_match[2]) then return -1
    #   if parseInt(a_match[2]) < parseInt(b_match[2]) then return  1 else return 0

    if a.score > b.score then return  1
    if a.score < b.score then -1 else 0

  # Singletons ##########
  @elasticsearchProcessor: (results)->
    results_array = _(results.hits.hits).map (result)->
      highlighted = (h = result.highlight) && (d = h.description) && (d[0])
      most_relevant_preview = highlighted || result._source.preview

      combined_payload = _([
        result._source.title,
        $("<span>#{most_relevant_preview}</span>").text(),
        # result._source.keywords.join('|'),
        result._source.study_title,
        result._source.author,
      ]).compact().join(' | ')

      type:    result._type
      id:      parseInt(result._id)
      score:   result._score
      payload: combined_payload
      title:        result._source.title
      description:  most_relevant_preview
      path:         result._source.path
      total_counts: results.total_counts
    results_array

CStone.Community.Search.Models.AbstractSource.setup()
