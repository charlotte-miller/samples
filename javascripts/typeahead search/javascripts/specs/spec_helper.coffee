#  APPLICATION
#= require_self
#= require vendor
#= require application
#= require community/news
#= require community/search
#= require community/posts/all
#
#  TEST HELPERS
#= require support/jasmine-jquery-1.7.0
#= require support/sinon
#= require support/vendor/backbone-factory
#= require support/bind-poly
#= require_tree ./support/helpers
#= require_tree ./specs/community/news/factories
#= require_tree ./specs/community/pages/factories
#= require_tree ./specs/community/search/factories
#
#  SPECS
#  Teaspoon will look for files that match _spec.{js,js.coffee,.coffee}.

window.CStoneData ||= {domains:{origin:'sporos-test.com'}}