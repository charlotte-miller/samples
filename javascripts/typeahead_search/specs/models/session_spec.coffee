describe "CStone.Community.Search.Models", ->

  describe "Session", ->
    beforeEach =>
      Backbone.Relational.store.reset()
      @session = Factory.session()

    it "should build from factory", =>
      expect(@session).toBeA( CStone.Community.Search.Models.Session )
      expect(@session).toHaveAssociated('results')
      expect(@session).toHaveAssociated('sources')

    describe 'EVENTS', =>
      describe "change:current_search", =>
        beforeEach =>
          spyOn( @session.get('sources'), 'search')
          spyOn( @session.get('results'), 'reset' )

        it "searches it's sources when the :current_search is changed", =>
          @session.set(current_search:'foo')
          expect(@session.get('sources').search).toHaveBeenCalledWith 'foo'

        it "does nothing WHEN an identical (case indifferent) string is set repeatedly", =>
          [ '', 'BIBLE', 'The Bible'].forEach (str)=>
            @session.set(current_search:str)
            @session.get('sources').search.reset()
            @session.get('results').reset.reset()
            @session.set(current_search:str.toLowerCase())
            expect(@session.get('sources').search).not.toHaveBeenCalled()
            expect(@session.get('results').reset).not.toHaveBeenCalled()

        it "resets results when search is changed from content to an empty string", =>
          @session.set(current_search:'foo')
          @session.set(current_search:'')
          expect(@session.get('results').reset).toHaveBeenCalled()

      describe 'change:dropdown_visible', =>
        it "hides the hint when dropdown is hidden visible", =>
          @session.set(dropdown_visible:true, hint_visible:true)
          expect(@session.get('hint_visible')).toBeTruthy()
          @session.set(dropdown_visible:false)
          expect(@session.get('hint_visible')).toBeFalsy()
          @session.set(dropdown_visible:true)
          expect(@session.get('hint_visible')).toBeFalsy()


      # describe '@get("results"), filtered:change', =>



    describe '#searchState()', =>
      beforeEach =>
        @session.get('results').reset()

      it "returns 'pre-search' when nothing is currently being searched", =>
        @session.set current_search: ''
        expect(@session.searchState()).toEqual 'pre-search'

      it "returns 'searching' when something is being searched and there are results", =>
        @session.set current_search: 'dog'
        expect(@session.searchState()).toEqual 'searching'

      it "returns 'no-results' when something is being searched but there are NO results", =>
        @session.set current_search: 'foo'
        expect(@session.searchState()).toEqual 'no-results'



    describe '#_updateCurrentHint()', =>
      stubFocusedPayload = (str)=>
        @session.get('results').currentFocus = -> get: -> str

      it "matches the capitalization of the current search term", =>
        [ 'Bible', 'BIBLE', 'bible', 'The Bible'].forEach (str)=>
          @session.set current_search: str
          stubFocusedPayload(str.toLowerCase())
          @session.get('results').trigger('filtered:change')
          expect(@session.get('current_hint')).toEqual str

      it "returns the original payload when original_capitalization=TRUE", =>
        [ 'Bible', 'BIBLE', 'bible', 'The Bible'].forEach (str)=>
          @session.set current_search: str
          stubFocusedPayload(str)
          @session.get('results').trigger('filtered:change')
          expect(@session.get('current_hint_w_original_capitalization')).toEqual str

      it "returns an empty string if nothing matches", =>
        @session.set current_search: "apples"
        stubFocusedPayload("oranges")
        @session.get('results').trigger('filtered:change')
        expect(@session.get('current_hint')).toEqual ''

      it "returns an empty string if the term stops matching", =>
        @session.set current_search: "apple pie"
        stubFocusedPayload("apple fritters")
        @session.get('results').trigger('filtered:change')
        expect(@session.get('current_hint')).toEqual ''

    describe '@get("active_ui")', =>
      it "is NULL when the dropdown is closed", =>
        @session.set(active_ui:'main', dropdown_visible:true)
        expect(@session.get('active_ui')).toEqual 'main'
        @session.set(dropdown_visible:false)
        expect(@session.get('active_ui')).toEqual null


    describe '@set(current_search:"term")', =>
      beforeEach =>
        @results = @session.get('results')
        @sources = @session.get('sources')
        @results.reset()


      xit "returns ALL results that match a search term", =>
        expect(@sources.length).toEqual 3
        expect(@results.pluck('payload')).toEqual []
        @session.set(current_search:'men')
        expect(@results.length).toEqual 3
        expect(@results.pluck('payload')).toEqual ["Men's Ministry", "Men's Ministry", "Men's Ministry"]

