class CStone.Community.Search.Models.Result extends Backbone.RelationalModel

  defaults:
    score:0

  initialize: =>
    _(['id','source']).forEach (requirement)=>
      throw Error("A Result MUST have a #{requirement}") unless @get(requirement)

  toJSON: =>
    id: @get('id')
    source:  @get('source')
    payload: @get('payload')
    title:   @get('title')
    path: @get('path')
    focusClass: if @get('focus') then 'active' else ''

  open: =>
    # window.location= @get('path')
    CStone.Base.Pages.layout.loadPage @get('path')

CStone.Community.Search.Models.Result.setup()
