describe "CStone.Community.Search.Models", ->
  describe "Result", ->
    beforeEach =>
      @result = Factory.result_from_session()

    it "should build from factory", =>
      expect(@result).toBeA( CStone.Community.Search.Models.Result )
      expect(@result).toHaveAssociated('session')
