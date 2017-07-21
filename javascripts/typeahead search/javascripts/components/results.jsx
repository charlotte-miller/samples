if (!CStone.Community.Search) { CStone.Community.Search = {Components:{}}; }
CStone.Community.Search.Components.Results = React.createClass({
  mixins: [Backbone.React.Component.mixin],

  componentDidMount: function () {
    this.spinner_interval = this.$('.text-spinner').textrotator();
  },

  componentDidUpdate: function () {
    if (this.session().searchState()=='pre-search') {
      if (!this.spinner_interval) {
        this.spinner_interval = this.$('.text-spinner').textrotator();
      }
    } else {
      if (this.spinner_interval) {
        clearInterval(this.spinner_interval);
        this.spinner_interval = false;
      }
    }

    if (this.session().searchState()=='no-results') {
      var textarea = this.refs.faqEmailDetails.getDOMNode();
      if (textarea.dataset.autosizeOn != "true") {
       autosize( textarea );
      }
      autosize.update( textarea );
    }else{
      if (this.state.editedEmailMessage) { this.setState({ editedEmailMessage: '' }); }
    }
  },

  componentWillUnmount: function () {
    if (this.spinner_interval) {
      clearInterval(this.spinner_interval);
      this.spinner_interval = false;
    }
  },

  session: function(){ return this.getModel().session; },

  bestEmailBody: function(){
    return this.state.editedEmailMessage || "Hi,\n  Can you help me get more information about: "+this.session().get('current_search')+'\n\nThanks!';
  },

  render: function(){
    var _this = this;
    var session = _this.getModel().session;

    var buildSources= function() {
      var results_collection  = _this.getCollection().results;
      var sources_collection  = _this.getCollection().sources;
      var grouped_results = results_collection.allGrouped();

      var mapSources = function() {
        var total = 0;
        var source_nav_data = sources_collection.map(function(source) {
          var count;
          var results = grouped_results[source.get('name')] || [];

          if( source.get('elasticsearch') && results.length > 7 ) {
            count = source.get('total_count');
          }else{
            count = results !== null ? results.length : 0;
          }
          total += count;
          return {
            name: source.get('name'),
            title: source.get('title'),
            count: count,
            showMe: !!(count || session.searchState()==='pre-search'),
            focusClass: source.get('focus') ? 'active' : ''
          };
        });
        source_nav_data.unshift({
          name: 'all',
          title: 'All',
          count: total,
          isAll: true,
          showMe: _(grouped_results).size() !== 1,
          focusClass: sources_collection.findWhere({
            focus: true
          }) ? '' : 'active'
        });

        return _(source_nav_data).select(function(s){return s.showMe;}).map(function(source) {
          var caret, count;
          caret = <span className="caret"></span>;
          count = <span className="count">{source.count}</span>;
          return (
            <li className={source.focusClass+" suggestion-nav-source"} >
              <a data-source={source.name} href={"#search/filter/"+source.name} onClick={_this.onNavClick}>
                <i className={source.name+' icon'}></i>
                { source.title }
                { source.isAll ? caret : null }
                { source.count ? count : null }
              </a>
            </li>
          );
        });
      };
      return(
        <div className="suggestions-nav">
          <ul className="suggestion-nav-sources">
            { mapSources() }
          </ul>
        </div>
      );
    };

    var buildResults= function() {
      var buildEmptyHelp, buildInitHelp, buildResults, eachResult;

      buildEmptyHelp = <div className="search-help" id="empty-help">
        <div className="search-help-content">
          <h3 className="search-help-text">
            <i className="icon"></i>
            Nothing Found. Can we get back to you?
            <p className="lead">Our search gets smarter every day, but sometimes you just need to talk to a real person.</p>
          </h3>
          <form className="" onSubmit={_this.onEmailSubmit}>
            <div className="form-group">
              <div className="input-group">
                <div className="input-group-addon">
                  <b>From:</b>
                </div>
                <label className="sr-only" htmlFor="faq-sender-email">Email Body</label>
                <input placeholder="your@email.com" className="form-control" type="email" id="faq-sender-email" ref="faqEmailAddress"></input>
                <div className="input-group-addon" id="faq-recipient"><b>To:</b> faq@cornerstonesf.org</div>
              </div>
            </div>
            <div className="form-group">
              <label className="sr-only" htmlFor="faq-email-details">Email Body</label>
              <textarea id="faq-email-details" className="form-control" rows="3" value={_this.bestEmailBody()} onChange={_this.onEmailEdit} ref="faqEmailDetails"></textarea>
            </div>
            <div className="form-group">
              <button type="submit" className="btn btn-primary btn-block" >Send Email</button>
            </div>
          </form>
        </div>
      </div>;

      buildInitHelp = (
        <div className="search-help" id="init-help">
         <div className="search-help-content">
           <h3 className="search-help-text">
             <i className="icon"></i>
             Try Searching:
             <a className="text-spinner" href="#">"When does Church start", "Parking", "Child care", "BART &amp; MUNI", "Haiti Mission", "Videos", "Music", "1 Peter 2", "Ministries"</a>
             <p className="lead">We want you to find what you are looking for, so start typing to learn more about our community &amp; media library.</p>
           </h3>
         </div>
       </div>
      );

      eachResult = function() {
        return _this.state.results.map(function(result) {
          return (
            <li className={result.focusClass+" suggestion"} data-result-id={result.id} onClick={_this.onClick} onMouseOver={_this.onMouseover} >
              <i className={result.source+" icon"}></i>
              <span dangerouslySetInnerHTML={ {__html: result.title} } />
              <div className='preview'     dangerouslySetInnerHTML={ {__html: result.preview} } />
              <div className='description' dangerouslySetInnerHTML={ {__html: result.description} } />
            </li>
          );
        });
      };

      buildResults = <ol className="suggestion-list">
         { eachResult() }
       </ol>;



      return (
        <div className="suggestions">
          { (function(){
            switch (session.searchState()) {
            case 'pre-search' : return buildInitHelp;
            case 'no-results' : return buildEmptyHelp;
            default: return buildResults;}
          })() }
        </div>
      );
    };

    return (
      <div className="search-suggestions">
        <div className="search-suggestions-dropdown">
          <div className="search-results">
            { buildSources() }
            { buildResults() }
          </div>
        </div>
      </div>
    );
  },

  // Event Handlers
  //---------------------------------------------------------
  onEmailEdit: function(e){
    var textarea = this.refs.faqEmailDetails.getDOMNode();
    this.setState({ editedEmailMessage: textarea.value });
  },

  onEmailSubmit: function(e){
    e.preventDefault()
    var node = this.refs.faqEmailAddress.getDOMNode();
    if (node.value) {
      console.log(this.bestEmailBody());
    }else{
      $(node).focus();
    }
  },

  onClick: function(e) {
    // var result_id = this.$(e.target).closest('li').data('resultId');
    // var result = this.getCollection().results.get(result_id);
    // return result.open();
    this.session().openFocused()
  },

  onMouseover: function(e) {
    var results, result;
    results = this.getCollection().results;
    result  = results.get(e.target.dataset.resultId);
    if (result && !result.get('focus')) {
      return results.updateFocus(result);
    }
  },

  onNavClick: function(e) {
    var results_collection, sources_collection, current_source, to_focus, _ref;
    results_collection = this.getCollection().results;
    sources_collection = this.getCollection().sources;
    current_source     = e.target.dataset.source || this.$(e.target).parents('a').data().source;

    if (this.$('.caret:visible').length) {
      if (('all' === (_ref = results_collection.currentFilter()) && _ref === current_source)) {
        this.$('.suggestions-nav').toggleClass('expanded');
        return 'to prevent re-render';
      }
    }

    results_collection.filterBySource(current_source);
    to_focus = sources_collection.findWhere({
      name: results_collection.currentFilter()
    });
    sources_collection.updateFocus(to_focus);
    $('.text').focus();
  }

});
