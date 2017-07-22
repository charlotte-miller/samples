if (!ThreeSixty) { var ThreeSixty = { Models:{}, Collections:{}, Controllers:{}, Views:{},  Templates:{} }; }

// ==============================================================================
// =                                   Models                                   =
// ==============================================================================

///////////////////////////////////////////////////////////
ThreeSixty.Models.Configuration   = Backbone.Model.extend({
  initialize: function(){
    //Callbacks
    this.bind('change', function(config, options){
      this.save_previous_state();
      this.before_switching_car_model();
      this.before_switching_exterior_color(config);
      this.before_opa_update(config, options);
      this.trigger('change:filtered'); });
  },

  // TODO - make 'image_path' dynamic from backend data
  defaults        : { angle : 10,
                      is_exterior_view : true,
                      packages : [],  accessories: [],  options :  [],
                      base_url : 'http://d3403mtifmmdhn.cloudfront.net/',
                      image_path : 'http://d3403mtifmmdhn.cloudfront.net/images/configurator360/' },

  // Associations
  // -- returns the associated backbone 'model' or an array of backbone 'models' (when plural)
  car_model       : function(){ return ThreeSixty.Options.get( this.attributes.car_model ); },
  wheel           : function(){ return this.car_model().wheels.get( this.attributes.wheel ); },
  interior_color  : function(){ return this.car_model().interior_colors.get( this.attributes.interior_color ); },
  exterior_color  : function(){ return this.car_model().exterior_colors.get( this.attributes.exterior_color ); },
  packages        : function(){
    var package_codes = this.attributes.packages;
    return  this.car_model().packages.select( function(package_obj){ return _(package_codes).include( package_obj.id ); }); },
  accessories     : function(){
    var accessories_codes = this.attributes.accessories;
    return this.car_model().accessories.select( function(accessory_obj){ return _(accessories_codes).include( accessory_obj.id ); }); },
  options         : function(){
    var options_codes = this.attributes.options;
    return this.car_model().options.select( function(option_obj){ return _(options_codes).include( option_obj.id ); }); },


  validate : function(attrs){
    if ( typeof(attrs.car_model)==='object' ) {var error = "car_model should be an id (not the model object).  Example: configModel.car_model='63' ";
      console.log(error); return error;} },


  // Collection Managment
  // -- manipulate the array of packages/accessories/options
  // -- Example:  ThreeSixty.Configuration.add_to_collection('PCH', 'accessories')
  // -- returns the [colleciton] if updated || false if unchanged
  add_to_collection     : function(code, collection, options){
    var reply                   = false;
    var array                   = this.attributes[collection];
    var is_valid_for_this_model = _(_(this.car_model().attributes[collection]).pluck('id')).include(code);
    var is_unique               = !( _(array).include(code) );
    if (is_unique && is_valid_for_this_model) {
      var dup = array.slice();  dup.push(code);
      var obj = {};             obj[collection] = dup;
      this.set( obj, {silent :true});
      if (!(options&&options.silent)) {
        this.change( {'action':'add', 'id':code, 'collection': collection} );}
      reply=dup;}
    return reply;  },

  rm_from_collection    : function(code, collection, options){
    var reply = false;
    var array = this.attributes[collection];
    var position = $.inArray(code, array);
    if (position > -1) {
      var dup = array.slice();
      _(dup).splice(position, 1);
      var obj = {};  obj[collection] = dup;
      this.set(obj, {silent :true});
      if (!(options&&options.silent)) {
        this.change( {'action':'remove', 'id':code, 'collection': collection} );}
      reply=dup;}
    return reply;  },


  // Callbacks
  save_previous_state : function(){ this.previous_state= this.previousAttributes(); },

  before_switching_car_model: function(){
    if (this.hasChanged('car_model')) {
      var new_attrs   = {};
      var this_config = this;
      var new_model   = this.car_model();
      if (!new_model) { throw("Can't find a CarModel with an ID of "+this.id); }

      // user selection || car_model default
      _(['wheel', 'interior_color', 'exterior_color']).each(function(required_feature){
        new_attrs[required_feature]= new_model.get_or_default((required_feature+'s'), this_config.attributes[required_feature], true); });
      _(['options', 'packages', 'accessories']).each(function(opa) { new_attrs[opa]= _( this_config[opa]() ).pluck('id'); });

      // Save
      this.set(new_attrs, {silent: true}); }

  },

  before_switching_exterior_color: function(config){
    var this_interior = this.attributes.interior_color;
    var safe_interiors = this.exterior_color().attributes.safe_interior_colors;
    if ( this.hasChanged('exterior_color') && !_(safe_interiors).include(this_interior) ) {
      this.set({ interior_color: safe_interiors[0]}, {silent:true}); }
    if ( this.hasChanged('exterior_color')) {
      var effected_model = this.exterior_color();
      // debugger;
      effected_model.check_dependencies( config, 'add' );
    }
  },

  before_opa_update : function(config, options){
    this.dependency_errors= [];
    if ( _(['options', 'packages', 'accessories']).include(options.collection) ){
      var effected_model = config.car_model()[options.collection].get(options.id);
      effected_model.check_dependencies( config, options.action );} },



  // Revert the configuraiton to the previous .change()
  undo : function(){ this.set( this.previous_state ); },


  collectUniqueCosts : function() {
    function hashForCost(kind, code, price) {
      var element = [];
      element.kind = kind;
      element.code = code;
      element.price = price;
      return element;
    }

    config = this;

    var configuredItems = [];

    for(i=0; i < this.attributes.accessories.length; i++) {
      configuredItems.push(this.attributes.accessories[i]);
    }

    for(i=0; i < this.attributes.options.length; i++) {
      configuredItems.push(this.attributes.options[i]);
    }

    for(i=0; i < this.attributes.packages.length; i++) {
      configuredItems.push(this.attributes.packages[i]);
    }

    configuredItems.push(this.attributes.wheel);

    configuredItems = $.unique(configuredItems);


    var optionsPackagesAndAccessories = [];

    $.each(ThreeSixty.Options.get(this.car_model()).options.models, function(index, value) {
      if (value && value.id && value.price) {
        presentAlready = false;
        for(i in optionsPackagesAndAccessories) {
          if (optionsPackagesAndAccessories.code == value.id) {
            presentAlready = true;
            break;
          }
        }

        if (!presentAlready) {
          optionsPackagesAndAccessories.push(hashForCost("option", value.id, value.price));
        }
      }
    });

    $.each(ThreeSixty.Options.get(this.car_model()).packages.models, function(index, value) {
      if (value && value.id && value.price) {
        presentAlready = false;
        for(i in optionsPackagesAndAccessories) {
          if (optionsPackagesAndAccessories.code == value.id) {
            presentAlready = true;
            break;
          }
        }

        if (!presentAlready) {
          optionsPackagesAndAccessories.push(hashForCost("package", value.id, value.price));
        }
      }
    });

    $.each(ThreeSixty.Options.get(this.car_model()).accessories.models, function(index, value) {
      if (value && value.id && value.price && value.price > 0) {
        presentAlready = false;
        for(i in optionsPackagesAndAccessories) {
          if (optionsPackagesAndAccessories.code == value.id) {
            presentAlready = true;
            break;
          }
        }

        if (!presentAlready) {
          optionsPackagesAndAccessories.push(hashForCost("accessory", value.id, value.price));
        }
      }
    });

    $.each(ThreeSixty.Options.get(this.car_model()).wheels.models, function(index, value) {
      if (value && value.id && value.price) {
        presentAlready = false;
        for(i in optionsPackagesAndAccessories) {
          if (optionsPackagesAndAccessories.code == value.id) {
            presentAlready = true;
            break;
          }
        }

        if (!presentAlready) {
          optionsPackagesAndAccessories.push(hashForCost("wheel", value.id, value.price));
        }
      }
    });


    var itemsOfValue = [];

    $.each(optionsPackagesAndAccessories, function(index, value) {
      for(i in configuredItems) {
        if(configuredItems[i] == value.code) {
          result = [];
          result.code  = value.code;
          result.price = value.price;

          var exists = false;
          for(j in itemsOfValue) {
            if (itemsOfValue[j].code == result.code) {
              exists = true;
              break;
            }
          }

          if (!exists) {
          itemsOfValue.push(result);
          }
        }
      }
    });

    return itemsOfValue;
  },


  // Price
   total_price : function(){
    itemsOfValue = this.collectUniqueCosts();

    currencyValue = 0;

    for(i in itemsOfValue) {
      currencyValue += itemsOfValue[i].price;
    }

    currencyValue += ThreeSixty.Options.get(this.attributes.car_model).price;

    return currencyValue;
  },

  formatted_price : function(){
    var price = String(this.total_price());
    var into_threes = new RegExp('(\\d{'+(price.length % 3)+'})' + '(\\d{3})');
    return '$'+(_( price.split(into_threes) ).reject(function(str){return str==='';}).join(','));
  },

  formatted_price_with_destination_charge : function(){
    var price = String(this.total_price() + 875);
    var into_threes = new RegExp('(\\d{'+(price.length % 3)+'})' + '(\\d{3})');
    return '$'+(_( price.split(into_threes) ).reject(function(str){return str==='';}).join(','));
  },


  // Inflectors
  // -- if (this.a8) { do amazing A8 things };
  a8 : function() { return this.car_model().attributes.carline === 'a8'; },


  // Image Name Builder
  image_name : function(angle, options){
    var    attr = this.attributes;
    var    exterior_color = (options && options.exterior_color) ? String(options.exterior_color) : attr.exterior_color;
    var    interior_color = (options && options.interior_color) ? String(options.interior_color) : attr.interior_color;
    var    wheel = (options && options.wheel) ? String(options.wheel) : attr.wheel;
    var    current_angle_string = (angle !== null) ? String(angle) : String(attr.angle);
    while  (current_angle_string.length < 3) { current_angle_string = '0' + current_angle_string; }

    var    image_name  =   [this.car_model().attributes.carline];                                        // carline
           if (this.car_model().attributes.carline.match("a6-sedan")) {
             image_name  = ["a6"]; //REMOVE AFTER A6 Launch as this is to handle for generated A6 name issues
           }
           image_name.push( this.car_model().attributes.title.replace(/ /g, '_')                      ); // carModel
           image_name.push( exterior_color                                                            ); // exteriorColor
           image_name.push( interior_color                                                            ); // interiorColor
           image_name.push( wheel                                                                     ); // wheel
           image_name.push( '704x310');                                                                  // imageSize for web experiance
           image_name.push( current_angle_string );                                                      // angle
    return image_name.join( '-').toLowerCase();  },


  url : function(){
    var link = '/';

    link += this.car_model().attributes.carline;
    link += '/configurator';
    return link; },


  interior_pano_path : function(interior_color_code)
  {
    // https://extranet.akqa.com/collaboration/display/audi/Audi+360+Image+Naming+convention
    // Example URL: http://d3403mtifmmdhn.cloudfront.net/images/configurator/stage/a8/interior_vr/nougat_brown/vr_config.xml

    var carline = this.car_model().attributes.carline;
    if (carline.length > 2) {
      carline = carline.substr(0, 2);
    }
    carline = carline.toLowerCase();

    var    interior_color_code_string = (interior_color_code) ? String(interior_color_code) : this.attributes.interior_color;
    var    xml_link  = this.attributes.base_url;
           xml_link += 'images/configurator/stage/' + carline + '/interior_vr/';
           xml_link += interior_color_code_string.toLowerCase() + '/';
    return xml_link;
  },


  interior_xml_link : function(interior_color_code)
  {
    var    xml_link  = this.interior_pano_path(interior_color_code);
           xml_link += 'vr_config.xml';
    return xml_link;
  },


  share_link : function(type){
    if ( !_(['facebook', 'twitter']).include(type) ) {throw('ThreeSixty.Models.Configuration.share_link() requires an argument of "facebook" or "twitter"');}
    var    share_link  = window.location.protocol +'//';
           share_link += window.location.host     +'/';
           share_link += this.car_model().attributes.carline;
           share_link += '/configurator/share?&destination=';
           share_link += type;
           share_link += '&share=';
           share_link += JSON.stringify( this.toJSON(true) );
    return share_link; },

  open_share_link : function(type){
    var config = this;
    var height; var width;
    var pop_window = function(){
      var left = (screen.width/2)-(width/2);
      var top = (screen.height/2)-(height);
      var newwindow=window.open(config.share_link(type),'share','top='+top+',left='+left+',height='+height+',width='+width+',resizable=yes');
      if (window.focus) {newwindow.focus();} };

    if (type == "twitter")  { height = 330;  width = 650;  pop_window();  $(document).trigger('configurator:ui:twitter_share'); }
    if (type == "facebook") { height = 490;  width = 980;  pop_window();  $(document).trigger('configurator:ui:facebook_share');}
    return false; },

  toJSON : function(do_not_include_root_in_json){
    var json  = {};    var attrs = _.clone( this.attributes );
    attrs.wheels = attrs.wheel;
    _(['wheel', 'angle', 'image_path', 'is_exterior_view', 'base_url']).each(function(attr){
      delete attrs[attr]; });
    if (do_not_include_root_in_json) {json=attrs;} else{json.configuration=attrs;}
    return json; },

  serialize : function(){ return jQuery.param(this.toJSON(true)); },

  save_configuration : function() {
    var outbox = this.clone();
    var attempt = 1;
    var send_it = function(){
      var save_link = 'https://'+String(location.hostname.replace(/models\./, 'my.'))+'/saved-cars';  //'my' subdomain
      outbox.save(outbox.attributes, {
        success: function(){                                                                          //Success --> configuration index
          window.location=save_link; },
        error: function(model, response){                                                             //Not logged in --> save to cookie --> configuration index
          var error = JSON.parse(response.responseText);
          if (response.status===400 && error.faux_status===401) {
            var attrs = outbox.serialize();
            var root_domain = String(location.hostname.match(/\w*\.\w*$/));
            document.cookie="configuration="+attrs+"; path=/; domain="+root_domain+';';
            window.location=save_link; }
          else{ if((attempt++)<3){ send_it(); }                                                       //Server error --> retry 3 times --> error message
            else{alert("Sorry, we are having a problem saving your configuraiton.\n\nPlease try again later");} } }}); };
            // TODO push this alert through the dependency notification system.
    send_it(); return false; }

});


///////////////////////////////////////////////////////////
ThreeSixty.Models.CarModel        = Backbone.Model.extend({
  initialize: function(){
    // Include
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    var attrs = this.attributes;
    this.wheels           = new ThreeSixty.Collections.Wheels(           attrs.wheels,             this );
    this.exterior_colors  = new ThreeSixty.Collections.ExteriorColors(   attrs.exterior_colors,    this );
    this.interior_colors  = new ThreeSixty.Collections.InteriorColors(   attrs.interior_colors,    this );
    this.featured_options = new ThreeSixty.Collections.FeaturedOptions(  attrs.featured_options,   this );
    this.packages         = new ThreeSixty.Collections.Packages(         attrs.packages,           this );
    this.accessories      = new ThreeSixty.Collections.Accessories(      attrs.accessories,        this );
    this.options          = new ThreeSixty.Collections.Options(          attrs.options,            this );
    this.price            = Number(this.attributes.price);
    this.default_configuration = {                     interior_color :  attrs.default_interior_color,
                                                       exterior_color :  attrs.default_exterior_color,
                                                       wheel          :  attrs.default_wheels,
                                                       car_model      :  this.id};  },


  // Tries to returns the specified 'model' || returns the CarModel's default 'model'
  // -- get_or_default('wheels', 'PPR')
  // -- set 'only_id' to return 'id' instead of a Backbone.Model
  get_or_default : function(plural_attr, id, only_id){
    if (!( plural_attr&&id )){ throw( 'get_or_default requires an "attribute" and an "id"') ;}

    var default_attr = this.default_configuration[plural_attr.replace(/s$/,'')];
    var desired_attr = this[plural_attr].get(id);                                                               // try getting the attr
    if (!desired_attr) {desired_attr = this[plural_attr].get(default_attr);}                                    // try finding a default
    if (!desired_attr) {desired_attr = this[plural_attr].select( function( opa ){return id == opa.id; });}      // options/packages/accessoies
    if ( only_id && desired_attr!=[] ) {desired_attr = desired_attr.id;}                                        // only_id?
    return desired_attr;  }

});


///////////////////////////////////////////////////////////
ThreeSixty.Models.ExteriorColor   = Backbone.Model.extend({
  initialize: function() {
    //Include
    _(this).extend(ThreeSixty.Models.Mixins.ParentCarModel);
    _(this).extend(ThreeSixty.Models.Mixins.OpaDependencies);  // testing if this mixin will work with this obj
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    this.price = 0; },

  needs_pearl_finish : function(){
    return _(this.attributes.dependencies).any(function(depend){
      return ( depend.action === 'require' ) && (depend.target.id === 'MPA7');
    });
  },

  valid_interior_colors : function(){
    var color_codes = this.attributes.safe_interior_colors;
    return  _(this.parent_carModel().interior_colors.models).select( function(interior_color_obj){ return _(color_codes).include( interior_color_obj.id ); }); }
});


///////////////////////////////////////////////////////////
ThreeSixty.Models.InteriorColor   = Backbone.Model.extend({
  initialize: function() {
    //Include
    _(this).extend(ThreeSixty.Models.Mixins.ParentCarModel);
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    this.price = 0; }
});


///////////////////////////////////////////////////////////
ThreeSixty.Models.Wheel           = Backbone.Model.extend({
  initialize: function(){
    // Include
    _(this).extend(ThreeSixty.Models.Mixins.ParentCarModel);
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    this.price = Number(this.attributes.price); }
});


///////////////////////////////////////////////////////////
ThreeSixty.Models.FeaturedOption  = Backbone.Model.extend({
  initialize: function(){
    // Include
    _(this).extend(ThreeSixty.Models.Mixins.ParentCarModel);
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    this.price = Number(this.attributes.price); }
});


///////////////////////////////////////////////////////////
ThreeSixty.Models.Package         = Backbone.Model.extend({
  initialize : function() {
    // Include
    _(this).extend(ThreeSixty.Models.Mixins.OpaDependencies);
    _(this).extend(ThreeSixty.Models.Mixins.ParentCarModel);
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    this.price = Number(this.attributes.price);
    this.has_additional_assets = !(_(this.attributes.additional_assets).isEmpty()); },

  expanded : false,

  toggle_expand : function( ){
    this.expanded = !this.expanded; },

  smallarrow_class : function( ){
    return this.expanded ? 'additional_assets_open' : ''; },

  additional_assets_style : function( ){
    return this.expanded ? 'display:block;' : ''; }
});


///////////////////////////////////////////////////////////
ThreeSixty.Models.Accessory       = Backbone.Model.extend({
  initialize : function()  {
    // Include
    _(this).extend(ThreeSixty.Models.Mixins.OpaDependencies);
    _(this).extend(ThreeSixty.Models.Mixins.ParentCarModel);
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    this.price = Number(this.attributes.price);
    this.has_additional_assets = !(_(this.attributes.additional_assets).isEmpty()); },

  expanded : false,

  toggle_expand : function( ){
    this.expanded = !this.expanded; },

  smallarrow_class : function( ){
    return this.expanded ? 'additional_assets_open' : ''; },

  additional_assets_style : function( ){
    return this.expanded ? 'display:block;' : ''; }

});


///////////////////////////////////////////////////////////
ThreeSixty.Models.Option          = Backbone.Model.extend({
  initialize : function(){
    // Include
    _(this).extend(ThreeSixty.Models.Mixins.OpaDependencies);
    _(this).extend(ThreeSixty.Models.Mixins.ParentCarModel);
    _(this).extend(ThreeSixty.Models.Mixins.Price);

    this.price = Number(this.attributes.price);
    this.has_additional_assets = !(_(this.attributes.additional_assets).isEmpty()); },

  expanded : false,

  toggle_expand : function( ){
    this.expanded = !this.expanded; },

  smallarrow_class : function( ){
    return this.expanded ? 'additional_assets_open' : ''; },

  additional_assets_style : function( ){
    return this.expanded ? 'display:block;' : ''; }

});



// ==============================================================================
// =                                   Mixins                                   =
// ==============================================================================
ThreeSixty.Models.Mixins = {

  ///////////////////////////////////////////////////////////
  ParentCarModel:{
    parent_carModel : function(){ return this.collection.parent_carModel;  }
  },

  ///////////////////////////////////////////////////////////
  OpaDependencies:{
    check_dependencies : function( config, action ){
      var depend = this.attributes.dependencies; if (depend){
      var raise_dependency_error = function(message){
        config.dependency_errors.push(message); };

        // remove
        if (action==='remove') {
          _(depend).chain().select(function(dep){return dep.action==='remove';}).each(function(dep){
            var target = dep.target;
            if ( target.collection==='exterior_color' ) {
              var first_safe_color = config.car_model().exterior_colors.non_pearl();
              config.set({ exterior_color: first_safe_color[0].id}, {silent:true}); }
            if ( config.rm_from_collection(target.id, target.collection, {silent:true}) ) {
              var message = _(dep.messages).values().join('<br />');
              raise_dependency_error(message);} }); }


        if (action==='add') {

          // replace
          _(depend).chain().select(function(dep){return dep.action==='replace';}).each(function(dep){
            var target = dep.target;
            if ( config.rm_from_collection(target.id, target.collection, {silent:true}) ) {
              var message = _(dep.messages).values().join('<br />');
              raise_dependency_error(message);}
            });

          // require
          _(depend).chain().select(function(dep){return dep.action==='require';}).each(function(dep){
            var target = dep.target;
            if ( config.add_to_collection(target.id,  target.collection, {silent:true}) ) {
              var message = _(dep.messages).values().join('<br />');
              raise_dependency_error(message);} });
        }
      }
    }
  },

  ///////////////////////////////////////////////////////////
  Price:{
    formatted_price : function(){
      var price       = String(Number(this.price));
      var into_threes = new RegExp('(\\d{'+(price.length % 3)+'})' + '(\\d{3})');
      var formatted   = '$'+(_( price.split(into_threes) ).reject(function(str){return str==='';}).join(','));
      return formatted=='$0' ? 'No Charge' : formatted;  },

    formatted_price_with_destination_charge : function(){
      console.log("Price = " + this.price);
      var price       = String(Number(this.price + 875));
      console.log("Price + dest charge = " + price);
      var into_threes = new RegExp('(\\d{'+(price.length % 3)+'})' + '(\\d{3})');
      var formatted   = '$'+(_( price.split(into_threes) ).reject(function(str){return str==='';}).join(','));
      return formatted=='$0' ? 'No Charge' : formatted;  }

  }
};
