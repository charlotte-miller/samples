describe "CStone.Community.Search.Collections", ->

  describe "Sources", ->
    @sources = Factory.sources()

    it "should build from factory", =>
      expect(@sources).toBeA(CStone.Community.Search.Collections.Sources)
      expect(@sources.at(0)).toBeA(CStone.Community.Search.Models.AbstractSource)
      expect(_(@sources.pluck('name')).unique().length).toEqual 3
