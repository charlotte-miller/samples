#= require community/search/models/abstract_source
SearchNamespace = CStone.Community.Search.Models
SearchNamespace.Sources ||= {}

class SearchNamespace.Sources.Ministry extends SearchNamespace.AbstractSource

  defaults:
    name:   'ministry'
    # local:  CStoneData.ministry_search #TODO
    local:  [{ payload: 'doggy', id:21 }, { payload: 'pig', id:22 }, { payload: 'moose', id:23 }]

  processResults: (results)=>
    _(results).map (result)=>
      result.type ||= 'ministry'
      result

SearchNamespace.Sources.Ministry.setup()
