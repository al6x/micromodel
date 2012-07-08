# Namespace and dependencies.
PassiveModel = if exports? then exports else @PassiveModel = {}
_ = @_ || require 'underscore'

# Model can be used without events or integrated with EventEmitter or Backbone.Events.
[useEvents, initializeEmitter, addListener, removeListener, emit] = [false, null, null, null, null]
PassiveModel.useEventEmitter = (EventEmitter) ->
  useEvents = true
  _(PassiveModel.Model.prototype).extend EventEmitter.prototype
  _(PassiveModel.Collection.prototype).extend EventEmitter.prototype
  initializeEmitter = (obj) -> EventEmitter.call @
  addListener       = (obj, event, fn) -> obj.addListener event, fn
  removeListener    = (obj, event, fn) -> obj.removeListener event, fn
  emit              = (obj, event, arg1, arg2) -> obj.emit event, arg1, arg2

PassiveModel.useBackboneEvents = (BackboneEvents) ->
  useEvents = true
  _(PassiveModel.Model.prototype).extend BackboneEvents
  _(PassiveModel.Collection.prototype).extend BackboneEvents
  initializeEmitter = (obj) -> EventEmitter.call @
  addListener       = (obj, event, fn) -> obj.on event, fn
  removeListener    = (obj, event, fn) -> obj.off event, fn
  emit              = (obj, event, arg1, arg2) -> obj.trigger event, arg1, arg2

PassiveModel.dontUseEvents = ->
  useEvents = false

# # Model
#
# Attributes stored as properties `model.name` but it shoud be setted only
# via the `set` method - `model.set name: 'foo'`.
#
# Properties with `_` prefix have special meaning (like caching `model._cache`) and
# ignored.
#
# By default model has no schema or attribute types, but it can be defined using `model.cast`
# method.
#
# There are special property `model._changed` - it contains changes from the last `set` operation.
#
# Define validation rules using `model.validations` and `model.validate`, there are
# also `isValid` method.
#
# Model can be serialized by usng `toHash` and `fromHash` methods.
#
# Use `model.on 'change', fn` to listen for `change` and `change:attrName` events.
#
# Specify `model.schema` to cast attributes to specified types.
#
# Example:
#
#     class User extends Model
#       validations:
#         name: (v) -> "can't be empty" if /^\s*$/.test v
#       schema:
#         age     : Number
#         enabled : (v) -> v == 'yes'
#
PassiveModel.Model = class Model
  # Initializing new model from `attrs` and `defaults` property.
  constructor: (attrs, options) ->
    @set @defaults, options if @defaults
    @set attrs, options if attrs
    @_changed = {}
    initializeEmitter @ if useEvents

  # Equality check based on the content of model, deep.
  eql = (other) ->
    return true if @ == other
    return false unless other and @id == other.id and _.isObject(other)

    # Checking if atributes and size of objects are the same.
    size = 0
    for own name, value of @ when not /^_/.test name
      size += 1
      return false unless _.isEqual value, other[name]

    otherSize = 0
    otherSize += 1 for own name of other when not /^_/.test name

    return size == otherSize

  eql: eql

  equal: (other) ->
    return false unless other and @constructor == other.constructor
    @eql other

  # Integration with underscore's `_.isEqual`.
  isEqual: eql

  # Helper, get attributes as hash from .
  attributes = (obj) ->
    attrs = {}
    attrs[name] = value for own name, value of obj when not /^_/.test name
    attrs

  # Set attributes of model, changed attributes will be available as `model._changed`.
  #
  # If model uses events (see `useBackboneEvents` or `useEventEmitter`)
  # following events will be emitted `change:attr` and `change`.
  #
  # `silent: false` - to suppres events and `validate: false` to suppress validation.
  # `permit: ['name', 'email'] - to set only permitted attributes.
  set: (obj = {}, options = {}) ->
    # Selecting attributes only.
    attrs = attributes obj

    # Selecting only permited attributes.
    if permit = options.permit
      permited = {}
      permited[name] = value for name, value of attrs when name in permit
      attrs = permited

    # Casting attributes to specified types.
    attrs[name] = Model.cast(attrs[name], type) for name, type of @schema if @schema

    # Validating attributes.
    return false if @validate(attrs) and options.validate != false

    # Updating and tracking changes.
    @_changed = {}
    unless options.silent
      for name, newValue of attrs
        currentValue = @[name]
        unless _.isEqual currentValue, newValue
          @_changed[name] = currentValue
          @[name]         = newValue
    else
      @[name] = newValue for name, newValue of attrs

    # Emitting changes.
    if useEvents and not options.silent and not _.isEmpty(@_changed)
      emit @, "change:#{name}", @ for name of @_changed
      emit @, 'change', @

    true

  # Shallow clone of model.
  clone: -> new @constructor @attributes()

  # Clear model.
  clear: ->
    delete @[name] for own name of @
    @_changed = {}
    @

  # Validating attributes, returns `null` if attributes valid or any not null object as error.
  validate: (attrs = {}) ->
    return null unless @validations
    errors = {}
    for name, value of attrs
      (errors[name] ?= []).push msg if msg = @validations[name]?(value)
    if _.isEmpty(errors) then null else errors

  # Define validation rules and store errors in `errors` property `@errors.add name: "can't be blank"`.
  isValid: -> @validate @

  attributes: -> attributes @

  # JSON conversion, including nested models.
  toJSON: -> attributes @

  inspect: -> JSON.stringify attributes @
  toString: -> inspect @

  # Cast value to type, override it to provide more types.
  @cast: (value, type) ->
    return type value if _.isFunction type

    if type == String
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
      throw "can't cast to unknown type (#{type})!"

# # Collection of models.
#
# Collection can store models, automatically sort it with given order and
# emit `add`, `change`, `delete` and `model:change`, `model:change:attr` events if
# Events module provided.
PassiveModel.Collection = class Collection
  # Initialize collection, You may provide array of models and options.
  constructor: (models, options = {}) ->
    [@models, @length, @ids] = [[], 0, {}]
    @comparator = options.comparator
    @add models if models
    initializeEmitter @ if useEvents

  # Define comparator and collection always will be automatically sorted.
  sort: (options) ->
    @comparator = options.comparator if options.comparator
    throw "no comparator!" unless @comparator

    # Sorting.
    if @comparator.length == 1
      @models = _(@models).sortBy @comparator
    else
      @models.sort @comparator

    # Emitting changes.
    emit @, 'change', @ if useEvents and options.silent != true
    @

  # Add model or models, `add` and `change` events will be triggered.
  add: (args...) ->
    if _.isArray args[0]
      [models, options] = args
    else
      lastArgument = args[args.length - 1]
      options = unless lastArgument instanceof Model then args.pop() else {}
      models = args
    options ?= {}

    # Transforming object to model if it isn't.
    tmp = models
    models = []
    for model in models
      unless model instanceof Model
        klass = @model || throw "no Model class for Collection!"
        model = new klass model
      models.push

    # Adding to collection.
    added = []
    for model in models
      throw "can't add Model without id to Collection (#{model.inspect()})!" unless model.id
      # Model can be added only once, ignoring if it tried to be added twice.
      continue if id of @ids
      @ids[model.id] = model
      @models.push model
      added.push model
    @length = @models.length

    # Proxing model events.
    addListener model, 'change', @proxyModelEvent for model in added if useEvents

    # Sorting.
    @sort silent: true if @comparator

    # Emitting events.
    if useEvents and not options.silent and added.length > 0
      emit @, 'add', model, @ for model in added
      emit @, 'change', @
    @

  # Delete model or models, `delete` and `change` events will be emitted.
  delete: (args...) ->
    if _.isArray args[0]
      [models, options] = args
    else
      lastArgument = args[args.length - 1]
      options = unless lastArgument instanceof Model then args.pop() else {}
      models = args
    options ?= {}

    # Deleting
    deleted = []
    for model in models
      # Ignoring models that aren't in collection.
      continue unless model.id of @ids
      index = @models.indexOf model
      delete @ids[id]
      @models.splice index, 1
      deleted.push model
    @length = @models.length

    # Removing model events proxy.
    removeListener model, 'change', @proxyModelEvent for model in deleted if useEvents

    # Emitting events.
    if useEvents and not options.silent and deleted.length > 0
      emit @, 'delete', model, @ for model in deleted
      emit @, 'change', @
    @

  proxyModelEvent: (event, model) => emit @, "model:#{event}", model, @

  # Get model by id.
  get: (id) -> @ids[id]

  # Get model by index.
  at: (index) -> @models[index]

  # Clear collection, `delete` and `change` events will be triggered.
  clear: (options = {}) ->
    # Deleting
    deleted = @models
    [@models, @length, @ids] = [[], 0, {}]

    # Removing model events proxy.
    removeListener model, 'change', @proxyModelEvent for model in deleted if useEvents

    # Emitting events.
    if useEvents and not options.silent and deleted.length > 0
      emit @, 'delete', model, @ for model in deleted
      emit @, 'change', @
    @

  # Reset collection with new models.
  reset: (args...) ->
    @clear()
    @add args...

  # JSON conversion, including nested models.
  toJSON: -> @models

  inspect: -> JSON.stringify @models
  toString: -> inspect @