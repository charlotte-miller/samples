#= require community/search/models/abstract_source

class CStone.Community.Search.Collections.Sources extends CStone.Shared.Backbone.ExtendedCollection
  PRESENTATION_ORDER = 'ministry event sermon music video page question'.split(' ')

  model: CStone.Community.Search.Models.AbstractSource

  ###
    options[:only]
    options[:except]
  ###
  search: (query, options={})=>
    uniq_sources = _(@models).uniq (m)-> m.constructor.name
    uniq_sources.forEach (source)-> source.search(query)

  comparator: (a,b)->
    [a,b] = [a,b].map (source)-> PRESENTATION_ORDER.indexOf source.get('name')
    if a < b then return  -1
    if a > b then 1 else 0

  updateFocus: (optional_model)=>
    return unless @length
    current_focus = @findWhere(focus:true)
    current_focus.set(focus:false) if current_focus
    optional_model.set(focus:true) if optional_model

  clearRemotelyBuiltIndexes: =>
    remote_sources = @select((source)->source.get('remote'))
    _(remote_sources).each (remote_source)->
      remote_source.bloodhound.clear()

  updateTotalCounts: (total_counts)=>
    _(total_counts).each (count, source)=>
      unless source=='total'
        @findWhere(name:source).set(total_count:count)
