describe "CStone.Community.Search.Collections", ->

  describe "Results", ->
    beforeEach =>
      results = _(['ministry', 'event', 'sermon']).map (source)-> Factory.result(source:source)
      @results = Factory.results(models:results)

    it "should build from factory", =>
      expect(@results).toBeA(CStone.Community.Search.Collections.Results)
      expect(@results.at(0)).toBeA(CStone.Community.Search.Models.Result)

    describe "#filtered", =>
      it "starts with the same models as the parent collection", =>
        expect(@results.filtered.length).toEqual 3
        expect(@results.pluck('id')).toEqual @results.filtered.pluck('id')

    describe "#filterBySource(source)", =>
      it "removes non-matching results", =>
        _(['ministry', 'event', 'sermon']).forEach (source)=>
          @results.filterBySource(source)
          expect(@results.sources()).toEqual [source]

    describe "#updateFocus( optional_model )", =>
      beforeEach =>
        @filtered = @results.filtered
        @runner = (args...)=>
          @filtered.where(focus:true).forEach (m)-> m.set(focus:false) # Clear
          @results.updateFocus(args...)                                # Execute
          focused = @filtered.where(focus:true)                        # Find focused
          expect(focused.length).toEqual 1                             # Verifiy count
          focused[0]                                                   # Return result

      it "initalizes with focus on the first", =>
        focused = @filtered.where(focus:true)[0]
        expect(focused).toEqual @filtered.first()

      it "focuses the first model if not specified", =>
        expect(@runner()).toEqual @filtered.first()

      it "focuses on the specified model", =>
        specified_model = @results.at(1)
        expect( @runner(specified_model) ).toEqual specified_model

      it "focuses on the first model if the specified model has been filtered out", =>
        @results.filterBySource('sermon') #filter out @results.first()
        expect( @runner(@results.first()) ).toEqual @filtered.first()

      it "focuses on the first model if the specified model is not found", =>
        expect( @runner(Factory.result()) ).toEqual @filtered.first()

    describe "#moveFocus(up_down)", =>
      beforeEach =>
        @filtered = @results.filtered
        [@first_result, @middle_result, @last_result] = @filtered.models

      describe 'UP', =>
        it "moves focus to the previous model", =>
          @results.updateFocus(@middle_result)
          expect( @results.currentFocus() ).toEqual @middle_result
          @results.moveFocus('up')
          expect( @results.currentFocus() ).toEqual @first_result

        it "does nothing if the first model is already focused", =>
          expect( @results.currentFocus() ).toEqual @first_result
          @results.moveFocus('up')
          expect( @results.currentFocus() ).toEqual @first_result

      describe 'DOWN', =>
        it "moves focus to the next model", =>
          expect( @results.currentFocus() ).toEqual @first_result
          @results.moveFocus('down')
          expect( @results.currentFocus() ).toEqual @middle_result

        it "does nothing if the last model is already focused", =>
          @results.updateFocus(@last_result)
          expect( @results.currentFocus() ).toEqual @last_result
          @results.moveFocus('down')
          expect( @results.currentFocus() ).toEqual @last_result

    # describe '#updateFromSource(source, models_data=[])', =>
    #   it "adds new sources to the collection", =>
    #     @results.updateFromSource('foo', [{id:123}])
    #     expect(@results.pluck('source')).toContain 'foo'
    #
    #   it "adds new models to an existing source's collection", =>
    #     @results.updateFromSource('event', [{id:123}])
    #     expect(@results.pluck('id')).toContain 123
    #
    #   it "removes old models from the collection", =>
    #     old_event = @results.findWhere(source:'event')
    #     expect(@results.models).toContain old_event
    #     @results.updateFromSource('event', [{id:123}])
    #     expect(@results.models).not.toContain old_event
    #
    #   it "scopes changes to a single source", =>
    #     @results.updateFromSource('event', [{id:123}])
    #     expect(@results.length).toEqual 3

