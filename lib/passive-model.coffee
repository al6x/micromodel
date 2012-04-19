# If it's Browser, making it looks like "standard" JS.
global ?= window
_ = global._ || require 'underscore'
raise = (msg) -> throw new Error msg

# # Model
#
# Model for representing Business Data & Logic.
#
# Attributes stored as properties You can get it as `model.name` but You should set it only via `set` method,
# like `model.set name: 'foo'`.
# Atributes starting with `_` prefix are ignored, You can use it for temporarry things like
# caching `_cache`.
#
# By default model has no schema or attribute types, but You can define attribute types if You need it,
# see `cast` method.
#
# It has three special properties `id`, `errors` - containing current errors
# and `changed` - containing attributes changed from last `set` operation.
#
# You can define validation rules in `validate` method and run validation validity of model by
# using `valid` method.
#
# Model can be used on both Client and Server with differrent persistency providers, see `mongo-lite`
# and `rest-lite` adapters. You can also serialize model to and from hash by using `toHash`
# and 'fromHash` methods.
#
# If You need notifications (for example to use it with Backbone framework) it can be integrated with
# Backbone.Events module, and will trigger `change` and `change:attr` events.
#
# Use `_(Model.prototype).extend Backbone.Events` to integrate it with `Backbone.Events`.
class Model
  # You can initialize model with `attributes`, arguments are the same as for `set` method.
  # You can also define the `defaults` property on the model with default attribute values.
  constructor: (attributes, options) ->
    @set @defaults, options if @defaults
    @set attributes if attributes
    @_wrapErrors()
    @changed = {}

  # Check for equality based on the content of objects, deep.
  eq: (other) -> _.isEqual @, other

  # Set attributes of model, if the attribute is the same it will be ignored, list
  # of changed attributes will be available in `changed` variable.
  #
  # If model implements `trigger` method (for example by extending Backbone.Events module) the
  # following events will be triggered (except if new value of attribute is equal to old in that case
  # no event will be triggered): `change:attr` for every changed attribute and`change`.
  #
  # - if `cast` option provided it will set only attributes that explicitly defined in
  # schema (see `cast` method) and ignore others, You may use it as a vay to safe update attributes.
  # - if `silent` option provided no event will be triggered.
  #
  set: (attributes, options) ->
    attributes ?= {}
    options ?= {}

    # Casting attributes.
    attributes = @castAttributes attributes if options.cast

    # Updating attributes & tracking changes.
    @changed = {}
    for own k, v of attributes
      @changed[k] = @[k] unless _.isEqual @[k], v
      @[k] = v

    # Wrapping errors in handy wrapper.
    @_wrapErrors()

    # Notifying observers if Events module enabled.
    if @trigger? and !_.isEmpty(@changed) and (options.silent != true)
      for k, v of @changed
        event = "change:#{k}"
        @trigger event, event, @
      @trigger 'change', 'change', @

    @

  # Clone model
  clone: -> new @constructor @attributes()

  # Clear model.
  clear: ->
    delete @[k] for own k, v of @
    @errors = new Model.Errors()
    @changed = {}
    @

  # Check model for validity using `validate` method, if there will be errors - they will be saved in
  # `errors` property. If model implements `trigger` method `change:errors` & `change` events will
  # be trigerred.
  #
  # Model is valid when `errors` property is empty.
  valid: (options = {}) ->
    oldErrors = @errors
    @errors = new Model.Errors()
    @validate()
    newErrors = @errors
    @errors = oldErrors
    @set errors: newErrors, silent: options.silent
    _(@errors).size() == 0

  invalid: -> !@valid()

  # Define validation rules and store errors in `errors` property `@errors.add name: "can't be blank"`.
  validate: ->

  # Return list of model attributes, properties starting from `_` prefix are ignored, so are special
  # `errors` and `changed` properties.
  attributes: ->
    attrs = {}
    attrs[k] = v for own k, v of @ when not /^_/.test k
    delete attrs.errors
    delete attrs.changed
    attrs

  # Wraps errors object into special wrapper with andy helper methods.
  _wrapErrors: ->
    unless @errors?.constructor == Model.Errors
      old = @errors || {}
      @errors = new Model.Errors()
      @errors[k] = v for own k, v of old

# Utility helper for adding methods to object without making it enumerable.
definePropertyWithoutEnumeration = (obj, name, value) ->
  Object.defineProperty obj, name,
      enumerable: false
      writable: true
      configurable: true
      value: value

# # Errors
#
# Error messages stored in `errors` property of model in arbitrary format, but usually its strucrue
# looks like this:
#
#   errors:
#     name   : ["can't be blank"]
#     accept : ['must be accepted']
#
# in order to easy working with errors we adding helper methods `add` and `clear`.
class Model.Errors

# Clearing error messages.
definePropertyWithoutEnumeration Model.Errors.prototype, 'clear', ->
  delete @[k] for own k, v of @

# Adding message to errors, use `@errors.add name: "can't be blank"` it will be added as
# `{name: ["can't be blank"]}`.
definePropertyWithoutEnumeration Model.Errors.prototype, 'add', (args...) ->
  if args.length == 1
    @add attr, message for attr, message of args[0]
  else
    [attr, message] = args
    @[attr] ?= []
    @[attr].push message

# # Conversions.
#
# Convert model to and from Hash, also supports child models.

# Adding conversion methods to Model prototype.
_(Model.prototype).extend
  # Marker to easy distinguish model from other objects.
  _model: true

  # Convert model to hash, You can use `only` and `except` options to specify exactly what
  # attributes do You need. It also converts child models.
  toHash: (options) ->
    options ?= {}

    # Converting Attributes.
    hash = {}
    if options.only
      hash[k] = @[k] for k in options.only
    else if options.except
      hash = @attributes()
      delete hash[k] for k in options.except
    else
      hash = @attributes()

    # Adding errors.
    hash.errors = @errors if options.errors

    # Converting children objects.
    that = @
    for k in @constructor._children
      continue if options.only and !(options.only.indexOf(k) > 0)
      continue if options.except and (options.except.indexOf(k) > 0)

      if obj = that[k]
        if obj.toHash
          r = obj.toHash options
        # if obj.toArray
        #   r = obj.toArray()
        else if _.isArray obj
          r = []
          for v in obj
            v = if v.toHash then v.toHash(options) else v
            r.push v
        else if _.isObject obj
          r = {}
          for own k, v of obj
            v = if v.toHash then v.toHash(options) else v
            r[k] = v
        else
          r = obj
        hash[k] = r

    # Adding class.
    if options.klass
      klass = @constructor.name || raise "no constructor name!"
      hash.class = klass

    hash

  # Updates model from Hash, also updates child models.
  fromHash: (hash) ->
    model = Model.fromHash hash, @constructor
    attributes = model.attributes()
    attributes.errors = model.errors
    @set attributes
    @

# Addig conversion methods to Model class.
_(Model).extend

  # Declare embedded child models `@children 'comments'`.
  children: (args...) -> @_children = @_children.concat args

  # By default there's no child models.
  _children: []

  # Creates new model from Hash, also works with child models.
  fromHash: (hash, klass) ->
    raise "can't unmarshal model, no class provided!" unless klass

    # Creating object.
    obj = new klass()

    # Restoring attributes.
    obj[k] = v for own k, v of hash
    delete obj.class
    obj._wrapErrors()

    # Restoring children.
    for k in (klass._children || [])
      if o = hash[k]
        if o.class
          klass = Model.getClass o.class
          r = Model.fromHash o, klass
        else if _.isArray o
          r = []
          for v in o
            if v.class
              klass = Model.getClass v.class
              v = Model.fromHash v, klass
            r.push v
        else if _.isObject o
          r = {}
          for own k, v of o
            if v.class
              klass = Model.getClass v.class
              v = Model.fromHash v, klass
            r[k] = v
      obj[k] = r

    # Allow custom processing to be added.
    # klass.afterFromHash? obj, hash

    obj

  # Takes string - name of class and returns class function.
  #
  # In order to deserialize model from hash we need a way to get a class from its string name.
  # There may be different strategies, for example You may store Your class globally `global.Post`
  # or in some namespace for example `app.Post` or `models.Post`, or use other strategy.
  #
  # Override it if You need other strategy.
  getClass: (name) ->
    global.models?[name] || global.app?[name] || global[name] ||
      raise "can't get '#{name}' class!"

# # Attribute types
#
# You can specify attribyte tupes for model, and use it to automatically cast string values to
# correct types.
#
# For example if You declare `count` as having Number type then `model.set {count: '2'}, cast: true`
# will cast String `'2'` to Number and only then assign it to model.

# Extending Model with attribute types.
_(Model).extend

  # Use `cast count: Number` to declare that `count` attribute has Number type.
  cast: (args...) ->
    if args.length == 1
      @cast attr, type for own attr, type of args[0]
    else
      [attr, type] = args
      caster = "cast#{attr[0..0].toUpperCase()}#{attr[1..attr.length]}"
      @prototype[caster] = (v) ->
        if type then Model._cast(v, type) else v

  # Cast string value to given type, You may override and extend it to provide more types or Your
  # own custom types.
  _cast: (v, type) ->
    type ?= String
    casted = if type == String
      v.toString()
    else if type == Number
      if _.isNumber(v)
        v
      else if _.isString v
        tmp = parseInt v
        tmp if _.isNumber tmp
    else if type == Boolean
      if _.isBoolean v
        v
      else if _.isString v
        v == 'true'
    else if type == Date
      if _.isDate v
        v
      else if _.isString v
        tmp = new Date v
        tmp if _.isDate tmp
    else
      raise "can't cast, unknown type #{type}!"

    raise "can't cast, invalid value #{v}!" unless casted?
    casted

# Extending model with attribute types.
_(Model.prototype).extend

  # Cast string attributes to correct types, if attribute have no type it will be ignored and skipped.
  castAttributes: (attributes = {}) ->
    casted = {}
    for own k, v of attributes
      caster = "cast#{k[0..0].toUpperCase()}#{k[1..k.length]}"
      casted[k] = @[caster] v if caster of @
    casted

# # Collection
#
# Collection can store models, automatically sort it with given order and
# notify watchers with `add`, `change`, and `delete` events if Events module provided.
class Model.Collection

  # Initialize collection, You may provide array of models and options.
  constructor: (models, options = {}) ->
    [@models, @length, @ids] = [[], 0, {}]
    @comparator = options.comparator
    @add models if models

  # Define comparator and collection always will be automatically sorted.
  sort: (options) ->

  # Add model or models, `add` and `change` events will be triggered (if Events module provided).
  add: (args...) ->
    if args.length == 1 and _.isArray(args[0])
      [models, options] = [args[0], {}]
    else
      options = unless args[args.length - 1]?.isModel then args.pop() else {}
      models = args

    # Adding.
    for model in models
      @models.push model
      @ids[model.id] = model unless _.isEmpty(model.id)
    @length = @models.length

    # Sorting.
    @sort silent: true

    # Notifying
    if @trigger and (options.silent != true)
      @trigger 'add', model, @ for model in models
      @trigger 'change', @

    @

  # Delete model or models, `delete` and `change` events will be triggered (if Events module provided).
  delete: (args...) ->
    if args.length == 1 and _.isArray(args[0])
      [models, options] = [args[0], {}]
    else
      options = unless args[args.length - 1]?.isModel then args.pop() else {}
      models = args

    # Deleting
    deleted = []
    for model in models
      id = model.id
      unless _.isEmpty id
        if id of @ids
          deleted.push model
          delete @ids[id]
          index = @models.indexOf model
          @models.splice index, 1
      else
        for m, index in @models when model.eq m
          deleted.push m
          delete @ids[m.id]
          @models.splice index, 1

    @length = @models.length

    # Notifying
    if @trigger and (options.silent != true) and (deleted.length > 0)
      @trigger 'delete', model, @ for model in deleted
      @trigger 'change', @

    @

  # Get model by id.
  get: (id) -> @ids[id]

  # Get model by index.
  at: (index) -> @models[index]

  # Clear collection, `delete` and `change` events will be triggered (if Events module provided).
  clear: (options = {}) ->
    # Deleting
    deleted = @models
    [@models, @length, @ids] = [[], 0, {}]

    # Notifying
    if @trigger and (options.silent != true) and (deleted.length > 0)
      @trigger 'delete', model, @ for model in deleted
      @trigger 'change', @

    @

# # Validations
#
# A shortcuts for couple of most frequently used valiations.
_(Model.prototype).extend

  # Validates presence of attribute or attributes.
  validatesPresenceOf: (attrs...) ->
    for attr in attrs
      v = @[attr]
      blank = (v == null) or (v == undefined) or
        (_.isString(v) and (v.replace(/\s+/g, '') == ''))

      @errors.add attr, "can't be blank" if blank

# Exporting to outer world.
if module?
  module.exports = Model
else
 global.PassiveModel = Model