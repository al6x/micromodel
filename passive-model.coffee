# Module declarations.
global = @
PassiveModel = if exports? then exports else global.PassiveModel = {}
_ = global._ || require 'underscore'

# Making Underscore.js methods available directly on Collection.
underscoreMethods = ['forEach', 'each', 'map', 'reduce', 'reduceRight', 'find',
  'detect', 'filter', 'select', 'reject', 'every', 'all', 'some', 'any',
  'include', 'contains', 'invoke', 'max', 'min', 'sortBy', 'sortedIndex',
  'toArray', 'size', 'first', 'initial', 'rest', 'last', 'without', 'indexOf',
  'shuffle', 'lastIndexOf', 'isEmpty', 'groupBy'];
PassiveModel.withUnderscoreCollection = (klass) ->
  proto = klass.prototype
  # Mixing each Underscore method as a proxy to `Collection.models`.
  _.each underscoreMethods, (method) ->
    proto[method] = ->
      _[method].apply _, [@models].concat _.toArray(arguments)

# Integration with underscore's `_.isEqual`.
PassiveModel.withUnderscoreEqual = (klass) ->
  proto = klass.prototype
  proto.isEqual = proto.eql

# Integration with EventEmitter.
PassiveModel.withEventEmitter = (klass) ->
  proto = klass.prototype
  EventEmitter = global.EventEmitter || require('events').EventEmitter

  initializeWithoutEventEmitter = proto.initialize
  methods =
    initialize     : ->
      EventEmitter.apply @
      initializeWithoutEventEmitter.apply @, arguments

  proto.isEventEmitter = true
  _(proto).extend EventEmitter.prototype
  _(proto).extend methods

# Integration with BackboneEvents.
PassiveModel.withBackboneEvents = (klass) ->
  proto = klass.prototype
  Events = global.Backbone.Events || require('backbone').Events

  # Making `Backbone.Events` looks like it's `EventEmitter`.
  methods =
    addListener    : -> @on.apply @, arguments
    removeListener : -> @off.apply @, arguments
    emit           : -> @trigger.apply @, arguments

  proto.isEventEmitter = true
  _(proto).extend Events
  _(proto).extend methods

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
PassiveModel.withModel = (klass) ->
  proto = klass.prototype

  # Helper, get attributes as hash from.
  attributes = (obj) ->
    attrs = {}
    attrs[name] = value for own name, value of obj when not /^_/.test name
    attrs

  # Methods.
  initializeWithoutModel = proto.initialize
  methods =
    # Initializing new model from `attrs` and `defaults` property.
    initialize: (attrs, options) ->
      initializeWithoutModel?.call @, attrs, options
      [@_cid, @_changed] = [_.uniqueId('c'), {}]
      @set @defaults, options if @defaults
      @set attrs, options if attrs

    # Equality check based on the content of model, deep.
    eql: (other, strict = false) ->
      return true if @ == other
      return false unless other and @id == other.id and _.isObject(other)
      if strict
        return false unless @_cid == other._cid and @constructor == other.constructor

      # Checking if atributes and size of objects are the same.
      size = 0
      for own name, value of @ when not /^_/.test name
        size += 1
        return false unless _.isEqual value, other[name]

      otherSize = 0
      otherSize += 1 for own name of other when not /^_/.test name

      return size == otherSize

    equal: (other) -> @eql other, true

    # Set attributes of model, changed attributes will be available as `model._changed`.
    #
    # If model uses events (see `useBackboneEvents` or `useEventEmitter`)
    # following events will be emitted `change:attr` and `change`.
    #
    # `silent: false` - to suppres events and `validate: false` to suppress validation.
    # `permit: ['name', 'email'] - to set only permitted attributes.
    set: (obj, options = {}) ->
      return unless obj

      # Selecting attributes only.
      attrs = attributes obj

      # Selecting only permited attributes.
      if permit = options.permit
        permited = {}
        permited[name] = value for name, value of attrs when name in permit
        attrs = permited

      # Casting attributes to specified types.
      attrs[name] = PassiveModel.cast(attrs[name], type) for name, type of @schema if @schema

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
      if @isEventEmitter and not options.silent and not _.isEmpty(@_changed)
        @emit "change:#{name}", @ for name of @_changed
        @emit 'change', @

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

    inspect: -> JSON.stringify @attributes()
    toString: -> @inspect()

    toJSON: -> @attributes()

  # Adding klass information.
  proto.isModel = true

  # Adding methods.
  _(proto).extend methods

  # Adding another mixins.
  PassiveModel.withUnderscoreEqual klass

# Cast value to type, override it to provide more types.
PassiveModel.cast = (value, type) ->
  if _.isFunction type then type value
  else if type == String then v.toString()
  else if type == Number
    if _.isNumber(v) then v
    else if _.isString v
      tmp = parseInt v
      tmp if _.isNumber tmp
  else if type == Boolean
    if _.isBoolean v then v
    else if _.isString v then v == 'true'
  else if type == Date
    if _.isDate v then v
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
PassiveModel.withCollection = (klass) ->
  proto = klass.prototype

  # Helper for proxying model events to collection listeners.
  _proxyModelEvent = (model) -> @emit 'model:change', model, @

  # Methods.
  initializeWithoutCollection = proto.initialize
  methods =
    # Initialize collection, You may provide array of models and options.
    initialize: (models, options = {}) ->
      initializeWithoutCollection?.call @, models, options
      @_proxyModelEvent = _proxyModelEvent.bind @
      [@models, @length, @ids, @cids] = [[], 0, {}, {}]
      @comparator = options.comparator
      @add models, options if models

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
      @emit 'change', @ if @isEventEmitter and options.silent != true
      @

    # Add model or models, `add` and `change` events will be triggered.
    add: (args...) ->
      if _.isArray args[0]
        [models, options] = args
      else
        lastArgument = args[args.length - 1]
        options = unless lastArgument.isModel then args.pop() else {}
        models = args
      options ?= {}
      return unless models.length > 0

      # Transforming object to model if it isn't.
      tmp = models
      models = []
      for model in tmp
        unless model.isModel
          klass = @model || throw "no Model class for Collection (#{@})!"
          model = new klass model
        models.push model

      # Adding to collection.
      added = []
      for model in models
        # Model can be added only once, ignoring if it tried to be added twice.
        continue if (model.id of @ids) or (model._cid of @cids)
        @ids[model.id] = model
        @cids[model._cid] = model
        @models.push model
        added.push model
      @length = @models.length

      # Proxing model events.
      if @isEventEmitter and model.isEventEmitter
        model.addListener 'change', @_proxyModelEvent for model in added

      # Sorting.
      @sort silent: true if @comparator

      # Emitting events.
      if @isEventEmitter and not options.silent and added.length > 0
        @emit 'add', model, @ for model in added
        @emit 'change', @
      @

    # Delete model or models, `delete` and `change` events will be emitted.
    delete: (args...) ->
      if _.isArray args[0]
        [models, options] = args
      else
        lastArgument = args[args.length - 1]
        options = unless lastArgument.isModel then args.pop() else {}
        models = args
      options ?= {}
      return unless models.length > 0

      # Deleting
      deleted = []
      for model in models
        # Ignoring models that aren't in collection.
        continue unless (model.id of @ids) or (model._cid of @cids)
        index = @models.indexOf model
        delete @ids[model.id]
        delete @cids[model._cid]
        @models.splice index, 1
        deleted.push model
      @length = @models.length

      # Removing model events proxy.
      if @isEventEmitter and model.isEventEmitter
        model.removeListener 'change', @_proxyModelEvent for model in deleted

      # Emitting events.
      if @isEventEmitter and not options.silent and deleted.length > 0
        @emit 'delete', model, @ for model in deleted
        @emit 'change', @
      @

    # Get model by id.
    get: (id) -> @ids[id] || @cids[id]

    has: (id) -> (id of @ids) or (id of @cids)

    # Get model by index.
    at: (index) -> @models[index]

    # Clear collection, `delete` and `change` events will be triggered.
    clear: (options = {}) ->
      # Deleting
      deleted = @models
      [@models, @length, @ids, @cids] = [[], 0, {}, {}]

      # Removing model events proxy.
      if @isEventEmitter and model.isEventEmitter
        model.removeListener 'change', @_proxyModelEvent for model in deleted

      # Emitting events.
      if @isEventEmitter and not options.silent and deleted.length > 0
        @emit 'delete', model, @ for model in deleted
        @emit 'change', @
      @

    # Reset collection with new models.
    reset: (args...) ->
      @clear()
      @add args...

    inspect: -> JSON.stringify @models
    toString: -> @inspect()

    toJSON: -> @models

    # Equality check based on list of models.
    eql: (other, strict = false) ->
      return true if @ == other
      return false unless other and other.length == @length and other.models
      if strict
        return false unless other and @constructor == other.constructor
      for model, index in @models
        return false unless model.eql other.models[index], strict
      true

    equal: (other) -> @eql other, true

  # Klass information.
  proto.isCollection = true

  # Adding methods.
  _(proto).extend methods

  # Adding another mixins.
  PassiveModel.withUnderscoreCollection klass
  PassiveModel.withUnderscoreEqual klass

# Class helper.
PassiveModel.klass = (args...) ->
  name    = if _(args[0]).isString() then args.shift() else null
  methods = unless _(args[args.length - 1]).isFunction() then args.pop() else {}
  mixins  = args

  # Creating empty class.
  klass = -> @initialize?.apply @, arguments
  proto = klass.prototype

  # Adding name to class and special property to check if object is instance of this class.
  if name
    klass.name = name
    proto["is#{name}"] = true

  # Adding mixings and methods.
  mixin klass for mixin in mixins
  _(proto).extend methods
  klass

# Default Model and Collection.
PassiveModel.Model      = PassiveModel.klass 'Model', PassiveModel.withModel
PassiveModel.Collection = PassiveModel.klass 'Collection', PassiveModel.withCollection