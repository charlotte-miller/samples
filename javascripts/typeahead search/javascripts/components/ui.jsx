//= require ./results

if (!CStone.Community.Search) { CStone.Community.Search = {Components:{}}; }
CStone.Community.Search.Components.UI = React.createClass({
  mixins: [Backbone.React.Component.mixin],

  componentWillReceiveProps: function(props) {
    if (props.model) {
      props.model.on('change:dropdown_visible', this.thenScrollToMainUI);
    }
  },

  componentWillUnmount: function(){
    this.session().off('change:dropdown_visible', this.thenScrollToMainUI);
  },

  render: function() {
    var _this = this;
    var defaults = {
      dropdown_visible:false
    };

    var iOS = (typeof navigator !== 'undefined') && /iPad|iPhone|iPod/i.test(navigator.userAgent),
        android = (typeof navigator !== 'undefined') && /Android/i.test(navigator.userAgent),
        isMobile = (iOS || android);

    var session, session_model, Results;
    session = this.state.model || defaults;
    session_model = this.session();
    if (session.dropdown_visible) {
      Results = React.createElement(CStone.Community.Search.Components.Results, {
        model: {
          session: session_model
        },
        collection: {
          sources: session_model.get('sources'),
          results: session_model.get('results'),
        }
      });
    }

    return (
      <div id="main-header" className={"header"+(session.dropdown_visible ? ' search-focused' : '')}>
        <div className="container">
          <div id="main-header-content">
            <a href="#" id="logo" name="logo">
              <img className="logo-img" src="/static/images/cornerstone_logo_reverse.svg" alt="CornerstoneSF" width="230" height="110"/>
            </a>
            <div className="search" id="global-search">
              <form className="search-form" role="search" onSubmit={this.onSubmit}>
                <div className="input-group" >
                  <input  autoComplete="off" placeholder="Hi! What are you looking for?" type="text"
                          ref="global-search-input" className="text" id="global-search-input"
                          onFocus={   this.onInputFocus }
                          onChange={  this.onInputKey   }
                          onKeyDown={ this.onInputKey   }
                          />

                  <input className="search-hint" value={ session.hint_visible ? session.current_hint : ''} />
                  <div className="input-group-btn">
                    <button className="search-button submit" type="submit" onClick={this.onIconClick}>
                      <i className="glyphicon glyphicon-search"></i>
                    </button>
                  </div>
                </div>
                <div className="examples">
                  Examples:&nbsp; <span className="thin">Kids, &nbsp;Parking, &nbsp;Small Groups, &nbsp;Luke 12:12, &nbsp;Current Series, &nbsp;Get Involved</span>
                </div>
              </form>
              { Results }
            </div>
          </div>
        </div>
        {(function(){
          if (!isMobile) {
            return <div id="volume-controls">
              <i className="theater-icon glyphicon" onClick={_this.headerFitClick} ></i>
              <i className="glyphicon glyphicon glyphicon-repeat" ref="header-video-restart" onClick={_this.headerRestartClick} ></i>
              <i className="volume glyphicon" ref="header-volume" onClick={_this.headerVolumeClick} ></i>
            </div>
          }
        })()}
      </div>
    );
  },

  // = Event Handlers =
  // ----------------------------------------------------------------------
  headerFitClick: function(e){
    var $video = $('#main-header video').first();
    var $main = $('#main-header').first();
    $main.toggleClass('theater-mode');

    if ($main.hasClass('theater-mode')) {
      $video[0].play();
      if (($video.prop('muted') || !$video.prop('volume'))) {
        $('#volume-controls').addClass('sound-out');
        $video.prop({'muted':false, volume:0});
        $video.animate({volume: 0.7}, 2000, 'easeOutCirc');
      }
    }
  },

  headerRestartClick: function(e){
    var $video = $('#main-header video').first();
    $video.prop('currentTime', 0);
  },

  headerVolumeClick: function(e){
    var $video = $('#main-header video').first();
    var $volume = $('#volume-controls');
    $volume.toggleClass('sound-out');
    if ($volume.hasClass('sound-out')) {
      $video.prop({'muted':false, volume:0});
      $video.animate({volume: 0.7}, 2500, 'easeOutCirc');
    } else {
      $video.animate({volume: 0}, 800, 'easeOutCirc');
    }
  },

  onInputFocus: function(e) {
    if (e) { e.preventDefault();}
    this.session().set({
      active_ui: this.props.ui_name,
      dropdown_visible: true,
    });
  },

  onIconClick: (function(e) {
    e.preventDefault();
    this.session().set({ active_ui: this.props.ui_name });
    this.session().toggle('dropdown_visible');
    var $global_search_input = $(this.refs['global-search-input'].getDOMNode());
    if (this.session().get('dropdown_visible')) {
      this.session().set({ current_search: $global_search_input.val()});
      $global_search_input.putCursorAtEnd();
    } else {
      this.session().set({ current_search: ''});
      $global_search_input.val('');
      this.$('.submit, .text').blur();
    }
  }),

  onSubmit: function(e) {
    e.preventDefault();
    this.session.openFocused();
  },

  onInputKey: function(e) {
    var _this, target, $target, key_code, specialKeyCodeMap;
    _this = this;
    target = e.target;
    $target = $(target);
    key_code = e.which || e.keyCode;
    specialKeyCodeMap = {
      9: 'tab',
      27: 'esc',
      39: 'right',
      13: 'enter',
      38: 'up',
      40: 'down'
    };
    if (e.type === 'keydown' && specialKeyCodeMap[key_code]) {
      switch (specialKeyCodeMap[e.which]) {
        case 'up':
          e.preventDefault();
          _this.session().moveFocus('up');
          break;
        case 'down':
          e.preventDefault();
          _this.session().moveFocus('down');
          break;
        case 'right':
          if ($target.isCursorAtEnd()) {
            e.preventDefault();
            _this.session().acceptHint();
            _this.updateInputField();
          }
          break;
        case 'tab':
          e.preventDefault();
          if ($target.isCursorAtEnd()) {
            _this.session().acceptHint();
            _this.updateInputField();
          }
          break;
        case 'enter':
          e.preventDefault();
          _this.session().openFocused();
          break;
        case 'esc':
          e.preventDefault();
          _this.session().set({
            dropdown_visible: false
          });
      }
    }
    if (e.type === 'input'  && !specialKeyCodeMap[key_code]) {
      var backspace_keys;
      backspace_keys = [8, 91, 93];
      if (_(backspace_keys).include(key_code) || e.type === 'cut') {
        if (!(target.value.length && $target.isCursorAtEnd())) {
          _this.session().set({
            hint_visible: false
          });
        }
      }
      return _this.session().set({
        current_search: target.value
      });
    }
  },


  // Helpers
  // ----------------------------------------------------------------------
  session: function(){ return this.getModel(); },

  updateInputField: function(){
    // NOTE: Breaks the one-way data flow. Use cautiously.
    var $global_search_input = $(this.refs['global-search-input'].getDOMNode());
    $global_search_input.val(this.session().get('current_search'));
  },


  // React to Model - Change DOM
  // ----------------------------------------------------------------------

  thenScrollToMainUI: function() {
    var col_sm_min, container, scroll_to;
    if (!(this.props.ui_name === 'main' && this.session().get('dropdown_visible'))) {
      return;
    }
    col_sm_min = 768;
    container = $('#main-page');
    scroll_to = container.width() < col_sm_min ? '#global-search' : '#main-header';
    return $(scroll_to).smoothScroll(CStone.Animation.layoutTransition.duration, CStone.Animation.layoutTransition.easing, {
      container: container,
      offset: -100
    });
  },
});
