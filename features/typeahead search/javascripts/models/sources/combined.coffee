#= require community/search/models/abstract_source
SearchNamespace = CStone.Community.Search.Models
SearchNamespace.Sources ||= {}

class SearchNamespace.Sources.Combined extends SearchNamespace.AbstractSource

  defaults:
    name:   'combined'
    elasticsearch: true
    prefetch:
      url: "http://#{CStoneData.domains.origin}/search/preload?types=music,page,question,sermon,video"
      transform: @elasticsearchProcessor
    remote:
      url: "http://#{CStoneData.domains.origin}/search?q=%QUERY&types=music,page,question,sermon,video"
      wildcard:'%QUERY'
      transform: @elasticsearchProcessor




SearchNamespace.Sources.Combined.setup()
