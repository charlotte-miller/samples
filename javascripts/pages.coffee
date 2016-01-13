# Problem:  The design called for a Pintrest style infinate scroll, that maintaines
#           the user's homepage scroll-context while navigating the site.
#
# Solution: Asyncounously load same-orgin, full-page content. Inject the relevant
#           history, scripts, and markup into a hidden div, then animate transition between the
#           'main' and 'content'. Deep links load and transition properly to both 'main'
#           and 'content' pages. External links are immediatly ignored, and errors cause
#           the page to load normally. Cacheing and eager-loading markup; lazy-loading assets.
#
# Sources: PJAX, Turbolinks, smoothState.js

class CStone.Base.Pages
  # CStone.Base.Pages.layout
  @layout: 'CStone.Base.Pages not initialized'
  @init: (mainPath, blacklist=[])=>
    return if @initalized
    @initalized = true
    @layout = new Layout(mainPath, blacklist)
    # Initialize jQuery in page_initializers using CStone.Base.Pages.layout


  class Layout
    constructor: (mainPath, blacklist=[]) ->
      @mainPath = mainPath                                 # The url/path to the main page
      @blacklist = Layout.utility.normalizeUrls blacklist  # Array of urls that are always ignored
      @$main = $('#main-page')                             # Container element for the main page
      @$page = $('#page')                                  # Container element content pages load into
      @cache = {}                                          # Variable that stores pages after they are requested
      @href = window.location.href                         # Url of the content that is currently displayed
      window.onpopstate = @onPopState                      # Sets the popstate function

      # Sets a default state
      unless history.state #is null
        history.replaceState
          id: @$page.prop("id")
        , document.title, @href


    ###
    Loads the contents of a url into $page
    -param   {string}     url
    -param   {object}     options
      -options  {bool}    isPopped - used to determine if whe should add a new item into the history object
      -options  {bool}    onlyPrefetch - used to load a page into the cache w/out updating the DOM
    -param   {function}   (url, $container, $content) ->
    ###
    loadPage: (url, options={}, callback)=>
      # Options optional
      if _(options).isFunction()
        callback = options
        options = {}

      # Load normally if external, #hash, or page-to-page
      lastUrl = @href
      return if url == lastUrl
      if @loadNormally(lastUrl, url)
        window.location = url
        return

      # Fetches the contents of a url and stores it in the '@cache' varible
      fetch = (url) =>
        if @$main.trim_html()
          @cache[Layout.utility.normalizeUrl(@mainPath)] ||=
            status: "loaded"
            title: document.title
            html: "<div><p id='#{@$main.attr('id')}'>Stored in DOM</p></div>"
            stored_at: undefined #timeless - stays cached

        # Don't fetch we have the content already
        unless @cache.hasOwnProperty(url)
          transitions.loading()
          @cache[url] = status: "fetching"
          request = $.ajax(url)

          # Store contents in @cache variable if successful
          request.success (html) =>
            Layout.utility.storePage @cache, url, html

          # Mark as error
          request.error => @cache[url].status = "error"

        # Start checking for the status of content
        responses[@cache[url].status]()


      # If the content has been requested and is done:
      # Updates the contents from @cache[url]
      updateContent = (url) =>
        container    = if @isMainPage(url) then @$main else @$page
        $cached_html = Layout.utility.getStoredPage(@cache, url)
        $content     = Layout.utility.getContentById("##{container.prop("id")}", $cached_html)
        $page_specific_javascripts = $('#page_specific_javascripts', $cached_html)
        if $content
          document.title = @cache[url].title
          @href = url
          container.html $content  unless @isMainPage(url) && @$main.trim_html()
          @loadAndInitalizePageSpecificJavascript($page_specific_javascripts)
        else
          window.location = url # No content availble to update with, aborting...

      # List of responses for the states of the page request
      responses=
        # Page is ready, update the content
        loaded: =>
          return false if options.onlyPrefetch
          updateContent( url )
          transitions.revealing()
          unless options.isPopped
            history.pushState
              id: @$page.prop("id")
            , @cache[url].title, url

        # Loading, wait 10 ms and check again
        fetching: =>
          setTimeout (=>
            responses[@cache[url].status]()
          ), 10

        # Error, abort and redirect
        error: -> window.location = url

      $body = $("html, body")
      transitions=
        loading: =>
          return false if options.onlyPrefetch
          @$main.addClass('background')

        revealing: ->
          animatePageTransition(transitions.cleanup)

        cleanup: =>
          # Clear @cache varible if it's getting too big
          @clearCacheIfOverCapacity(5)
          callback?()


      animatePageTransition= (trans_callback)=>
        @$page.addClass('transition')
        fromMain = @isMainPage(lastUrl)
        toMain   = @isMainPage(url)
        if fromMain
          if !toMain
            @$main.addClass('background')
            @$main.removeClass('current')
            @$page.addClass('current')

        else #fromPage
          if toMain
            @$page.removeClass('current')
            @$main.addClass('current')
            setTimeout (=> @$main.removeClass('background')), 500
            setTimeout (=> @$page.html('')), 1000
          else #toPage
            @$page.removeClass('transition')

        trans_callback()

      ## Execute
      if @isMainPage(url) || @isMainPage(lastUrl)
        fetch(url)
      else
        Pace.track -> fetch(url)
      return @

    loadAndInitalizePageSpecificJavascript: ($page_specific_javascripts)=>
      loadIncludesAndRunInitializer = =>
        runInitializer = ->
          if always_run_urls.length
            script_promises = _(always_run_urls).map (script_url)-> jQuery.getScript(script_url)

        if page_js_include_urls.length
          script_promises = _(page_js_include_urls).map (script_url)=>
            @page_js_registry.push script_url
            Promise.resolve( jQuery.getScript(script_url) )
          Promise.all(script_promises).then runInitializer, (err)-> console.log(err)
        else
          runInitializer()

      @page_js_registry ||= []
      page_js_include_urls = _($('#load_once script', $page_specific_javascripts).map -> @src).without(@page_js_registry...)
      always_run_urls = $('#load_every_time script', $page_specific_javascripts).map -> @src
      loadIncludesAndRunInitializer()

    isMainPage: (url)=>
      Layout.utility.urlMatchesPath(url, @mainPath)

    isBlacklisted: (url)->
      _(@blacklist).indexOf( Layout.utility.normalizeUrl(url) ) != -1

    loadNormally: (lastUrl, url)=>
      @isBlacklisted(url) or
      Layout.utility.isExternal(url) or
      Layout.utility.isHash(url)

    onPopState: (e)=>
      # Handles the popstate event, like when the user hits 'back'
      if e.state #isnt null
        url = window.location.href
        @$page = $("#" + e.state.id)
        @loadPage url, {isPopped:true}  if @href isnt url and not Layout.utility.isHash(url)

    clearCacheIfOverCapacity: (cap) ->
      # remove the oldest members of the cache leaving the capped number of entries
      if (cache_count = _(@cache).keys().length) > cap
        _sorted_entry_pairs = _(@cache).chain().pairs().sortBy((entry_pair)-> entry_pair[1].stored_at)
        _sorted_entry_pairs.first(cache_count - cap).each (stale_entry)=> delete @cache[stale_entry[0]]

    # Static Utility Methods
    @utility:
      # URL ---
      isExternal: (url) ->
        match = url.match(/^([^:\/?#]+:)?(?:\/\/([^\/?#]*))?([^?#]+)?(\?[^#]*)?(#.*)?/)
        return true  if typeof match[1] is "string" and match[1].length > 0 and match[1].toLowerCase() isnt location.protocol
        return true  if typeof match[2] is "string" and match[2].length > 0 and match[2].replace(
          new RegExp(":(#{ {http: 80, https: 443}[location.protocol]})?$"), "") isnt location.host
        false

      isHash: (url) ->
        hasPathname = (if (url.indexOf(window.location.pathname) > 0) then true else false)
        hasHash = (if (url.indexOf("#") > 0) then true else false)
        (if (hasPathname and hasHash) then true else false)

      normalizeUrl: (path_or_url)->
        $("<a href='#{path_or_url}'>").prop('href')

      normalizeUrls: (array_of_paths_or_urls)->
        _(array_of_paths_or_urls).map (url)=> @normalizeUrl(url)

      urlMatchesPath: (url,path)->
        @normalizeUrl(path) == @normalizeUrl(url)

      # Document ---
      htmlDoc: (html) ->
        # Prevents jQuery from stripping elements from $(html)
        parent = undefined
        elems = $()
        matchTag = /<(\/?)(html|head|body|title|base|meta)(\s+[^>]*)?>/g
        prefix = "ss" + Math.round(Math.random() * 100000)
        htmlParsed = html.replace(matchTag, (tag, slash, name, attrs) ->
          obj = {}
          unless slash
            elems = elems.add("<" + name + "/>")
            if attrs
              $.each $("<div" + attrs + "/>")[0].attributes, (i, attr) ->
                obj[attr.name] = attr.value
                return

            elems.eq(-1).attr obj
          "<" + slash + "div" + ((if slash then "" else " id=\"" + prefix + (elems.length - 1) + "\"")) + ">"
        )

        # If no placeholder elements were necessary, just return normal
        # jQuery-parsed HTML.
        return $(html)  unless elems.length

        # Create parent node if it hasn't been created yet.
        parent = $("<div/>")  unless parent

        # Create the parent node and append the parsed, place-held HTML.
        parent.html htmlParsed

        # Replace each placeholder element with its intended element.
        $.each elems, (i) ->
          elem = parent.find("#" + prefix + i).before(elems[i])
          elems.eq(i).html elem.contents()
          elem.remove()
          return
        parent.children().unwrap()

      getContentById: (id, $html) ->
        # Grabs the new container's contents from the cache
        updatedContainer = $(id, $html).html()
        newContent = (if (updatedContainer && updatedContainer.length) then $(updatedContainer) else null)
        newContent

      # Cache ---
      storePage: (cache, url, html) ->
        $htmlDoc = @htmlDoc(html)
        cache[url] = # Content is indexed by the url
          status: "loaded"
          title: $htmlDoc.find("title").text()
          html: html # Stores the raw html
          stored_at: Date.now()
        cache

      getStoredPage: (cache, url)->
        @htmlDoc(cache[url].html)
