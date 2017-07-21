#= require ./result_factory
#= require ./source_factory

# ====================================================
# =                      Model                       =
# ====================================================
BackboneFactory.define 'session', CStone.Community.Search.Models.Session, ->
  results:        Factory.results().models
  sources:        Factory.sources().models
  current_search: ''
  active_ui:      null

  # title:       'Your Title Here'
  # description: 'string, function, or another Factory'
  # size:         _(['Tall', 'Grande', 'Venti', 'Trenta']).shuffle()[0]
  # section:      Factory.section()







# ====================================================
# =               Complex Factories                 =
# ====================================================
refreshFactoryInterface()
# section_w_section_materials: (overrides)-> Factory.section( _( section_materials: Factory.section_materials().models ).extend(overrides) )
# distributor_w_offers:        (overrides)-> Factory.distributor( _(offers: Factory.offers().models ).extend(overrides))
