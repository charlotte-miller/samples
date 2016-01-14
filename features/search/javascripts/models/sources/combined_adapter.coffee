#= require community/search/models/abstract_source
#= require community/search/models/sources/combined
SearchNamespace = CStone.Community.Search.Models
SearchNamespace.Sources ||= {}

class SearchNamespace.Sources.CombinedAdapter extends SearchNamespace.AbstractSource

  defaults:
    elasticsearch: true

  initialize: =>
    _(['name']).forEach (requirement)=>
      throw Error("A Source MUST have a #{requirement}") unless @get(requirement)

    unless @get('title')
      name = @get('name')
      @set(title: name.charAt(0).toUpperCase() + name.slice(1))

    global_combined = CStone.Community.Search.combined_source ||= new SearchNamespace.Sources.Combined({name:'combined'})
    @bloodhound = global_combined.bloodhound


SearchNamespace.Sources.CombinedAdapter.setup()
