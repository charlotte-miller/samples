BackboneFactory.define_sequence 'id', (n)-> n

# ====================================================
# =                      Model                       =
# ====================================================
BackboneFactory.define 'result', CStone.Community.Search.Models.Result, ->
  id: BackboneFactory.next('id')
  source: 'ministry'
  payload: "Men's Ministry"
  path: '/men'
  # size:         _(['Tall', 'Grande', 'Venti', 'Trenta']).shuffle()[0]
  # section:      Factory.section()





# ====================================================
# =                   Collection                     =
# ====================================================
_(window.Factory ||= {}).extend({
  results:   (overrides)->   new CStone.Community.Search.Collections.Results  _({
    models: _([1,2,3]).map -> BackboneFactory.create('result', ->)
    }).extend( overrides )

})


# ====================================================
# =               Complex Factories                 =
# ====================================================
refreshFactoryInterface()
Factory.results_from_session = (overrides)-> Factory.session(results: Factory.results(overrides).models).get('results')
Factory.result_from_session  = (overrides)-> Factory.session(results: Factory.results(overrides).models).get('results').first()

# section_w_section_materials: (overrides)-> Factory.section( _( section_materials: Factory.section_materials().models ).extend(overrides) )
# distributor_w_offers:        (overrides)-> Factory.distributor( _(offers: Factory.offers().models ).extend(overrides))
