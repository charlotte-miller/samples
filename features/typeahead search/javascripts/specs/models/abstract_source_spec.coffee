describe "CStone.Community.Search.Models", ->

  describe "AbstractSource", ->
    @source = Factory.source_from_session()

    it "should build from factory", =>
      expect(@source).toBeA( CStone.Community.Search.Models.AbstractSource )
      expect(@source).toHaveAssociated('session')


    describe '#defaultQueryTokenizer(query)', =>
      should_include = (q, result)=>
        expect(@source.defaultQueryTokenizer(q)).toInclude(result)

      it "normalizes capitalization and special char", ->
        should_include "I AM", 'i am'
        should_include 'cake & coffee', 'cake and coffee'
        should_include '[Notes]: fun-time was fun (for a time)', 'notes fun time was fun for a time'

      it "includes the full query", =>
        should_include('I am the bread of life', 'i am the bread of life')

      it "extracts significant words", =>
        should_include('I am the bread of life', 'bread')
        should_include('I am the bread of life', 'life')

      it "includes reverse word shingles (to ignore the first part of a phrase)", =>
        should_include('I am the true vine', 'am the true')


    # describe '#defaultDatumTokenizer(datum)', =>
    #   it "prints", =>
    #     console.log('Datum')
    #     console.log(@source.defaultDatumTokenizer(payload:'I am the bread of life'))
