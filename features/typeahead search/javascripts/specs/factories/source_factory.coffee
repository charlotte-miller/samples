BackboneFactory.define_sequence 'source_name', (n)->
  'ministry event sermon music page announcement question'.split(' ')[n%7]

BackboneFactory.define_sequence 'source_data', (n)->
  [{ payload: 'doggy', id:100+n }, { payload: 'pig', id:200+n }, { payload: 'moose', id:300+n }, { payload: "Men's Ministry", id:400+n }]

# ====================================================
# =                      Model                       =
# ====================================================
BackboneFactory.define 'source', CStone.Community.Search.Models.AbstractSource, ->
  name:   BackboneFactory.next('source_name')
  local:  BackboneFactory.next('source_data')

  # session: Factory.session(sources:'dummy')
  # title:       'Your Title Here'
  # description: 'string, function, or another Factory'
  # size:         _(['Tall', 'Grande', 'Venti', 'Trenta']).shuffle()[0]
  # section:      Factory.section()

# ====================================================
# =                   Collection                     =
# ====================================================
_(window.Factory ||= {}).extend({
  sources:   (overrides)->   new CStone.Community.Search.Collections.Sources  _({
    models: _([1,2,3]).map -> BackboneFactory.create('source', ->)
    }).extend( overrides )

})


# ====================================================
# =               Complex Factories                 =
# ====================================================
refreshFactoryInterface()
Factory.sources_from_session = (overrides)-> Factory.session(sources: Factory.sources(overrides).models).get('sources')
Factory.source_from_session  = (overrides)-> Factory.session(sources: Factory.sources(overrides).models).get('sources').first()

# section_w_section_materials: (overrides)-> Factory.section( _( section_materials: Factory.section_materials().models ).extend(overrides) )
# distributor_w_offers:        (overrides)-> Factory.distributor( _(offers: Factory.offers().models ).extend(overrides))
