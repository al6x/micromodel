# Model and Collection for working on both Client and Server sides. Uses [functional mixins](http://jslang.info/blog/functional-mixins).

# Support for both Browser and Node.js environments.
if module?.exports?
  exports = module.exports
  _       = require('underscore')
  requireEventEmitter = -> require('events').EventEmitter
  requireBackboneEvents = -> require('backbone').Events
else
  exports = window
  _       = window._ || require('underscore')
  requireEventEmitter = -> window.EventEmitter || require('events').EventEmitter
  requireBackboneEvents = -> global.Backbone?.Events || require('backbone').Events

# # Model
#
# Attributes stored and accessed as properties `model.name` but it shoud be setted only
# via the `set` method - `model.set name: 'foo'`.
#
# Properties with `_` prefix are ignored.
#
# Define validation rules using `model.validations` or `model.validate`, check validity of model
# with `model.isValid()`.
attributeRe = /^_/
exports.Model = (klass) ->
  klass ?= exports.BaseClass()
  proto =  klass.prototype
  proto.isModel = true

  # Initializing model from `attrs` and `defaults` property.
  proto.initialize = (attrs, options) ->
    @set @defaults, options if @defaults
    @set attrs, options if attrs
    @

  # Equality check based on the content, deep.
  proto.isEqual = (other) -> # , strict = false
    return true if @ == other
    return false unless other and @id == other.id and other.isModel

    # Checking if atributes and size of models are the same.
    size = 0
    for own name, value of @ when not attributeRe.test name
      size += 1
      return false unless _.isEqual value, other[name]

    otherSize = 0
    otherSize += 1 for own name of other when not attributeRe.test name

    return size == otherSize

  # Set attributes.
  proto.set = (attrs, options) ->
    return {} unless attrs?

    changes = {}
    for own name, newValue of attrs when not attributeRe.test name
      # Tracking changes.
      oldValue = @[name]
      changes[name] = oldValue unless _.isEqual oldValue, newValue

      # Updating.
      @[name] = newValue
    changes

  # Shallow clone.
  proto.clone = -> new @constructor @attributes()

  # Clear attributes.
  proto.clear = (options) ->
    changes = attributes()
    delete @[name] for own name of @
    changes

  # Validating attributes, returns `null` if attributes valid or any not null object as error.
  proto.validate = ->
    return null unless @validations
    errors = {}
    for own name, validator of @validations
      (errors[name] ?= []).push msg if msg = validator @[name]
    if _.isEmpty errors then null else errors

  # Define validation rules and store errors in `errors` property `@errors.add name: "can't be blank"`.
  proto.isValid = -> not @validate()?

  proto.attributes = ->
    attrs = {}
    attrs[name] = value for own name, value of @ when not attributeRe.test name
    attrs

  proto.toJSON = -> @attributes()

  proto.inspect = -> JSON.stringify @toJSON()
  proto.toString = -> @inspect()

  proto.cid = -> @_cid = _.uniqueId()

  klass

# Adding 'change' and `change:attr` events, supply `silent: true`  option to suppress it.
exports.Model.Events = (klass, type) ->
  exports.Events klass, type
  proto = klass.prototype

  # Adding events to `set` method.
  proto.setWithoutEvents = proto.set
  proto.set = (attrs, options) ->
    changes = @setWithoutEvents attrs, options
    @_emitChanges changes, options
    changes

  # Adding events to `clear` method.
  proto.clearWithoutEvents = proto.clear
  proto.clear = (options) ->
    changes = @clearWithoutEvents options
    @_emitChanges changes, options
    changes

  # Emitt changes.
  proto._emitChanges = (changes, options) ->
    unless _.isEmpty(changes) and not options?.silent
      @trigger "change:#{name}", @, oldValue for name, oldValue of changes
      @trigger 'change', @, changes

  klass

# # Collection.
#
# Collection store models.
exports.Collection = (klass) ->
  klass ?= exports.BaseClass()
  proto =  klass.prototype
  proto.isCollection = true

  # Initialize collection, You may provide array of objects or models and options.
  proto.initialize = (args...) ->
    [@models, @length, @ids] = [[], 0, {}]
    @add args...
    @

  # Add model or models.
  proto.add = (args...) ->
    [models, options] = if _.isArray args[0] then args else [args, {}]
    options ?= {}
    @_add models, options

  proto._add = (models, options) ->
    # Adding to collection.
    added = []
    for model in models
      # Transforming objects to model if it isn't.
      unless model.isModel
        klass = @model || throw new Error "no Model for Collection (#{@})!"
        model = new klass model

      # Requiring id presence.
      throw new Error "no id for Model (#{model})!" unless model.id?

      # Model can be added only once, ignoring if it tried to be added twice.
      continue if model.id of @ids

      @ids[model.id] = @models.length
      @models.push model
      added.push model
    @length = @models.length
    added

  # Delete model or models.
  proto.delete = (args...) ->
    [models, options] = if _.isArray args[0] then args else [args, {}]
    options ?= {}
    @_delete models, options
  proto.del = (args...) -> @delete args...

  proto._delete = (models, options) ->
    # Marking models for delete.
    [deleted, deletedIndexes] = [[], {}]
    # Ignoring objects that aren't in collection.
    for model in models when model.id of @ids
      deleted.push model
      deletedIndexes[@ids[model.id]] = true

    # Deleting.
    unless _.isEmpty deletedIndexes
      oldModels = @models
      [@models, @ids] = [[], {}]
      @models.push model for model, index in oldModels when index not of deletedIndexes
      @ids[model.id] = index for model, index in @models

    @length = @models.length
    deleted

  # Get model by id.
  proto.get = (id) -> if (index = @ids[id])? then @models[index]

  proto.has = (id) -> id of @ids

  # Get model by index.
  proto.at = (index) -> @models[index]

  # Clear collection.
  proto.clear = (options = {}) ->
    deleted = @models
    [@models, @length, @ids] = [[], 0, {}]
    deleted

  proto.inspect = -> JSON.stringify @toJSON()
  proto.toString = -> @inspect()

  proto.toJSON = -> @models

  # Equality check based on content, deep.
  proto.isEqual = (other) ->
    return true if @ == other
    return false unless other and other.length == @length and other.isCollection
    for model, index in @models
      return false unless model.isEqual other.at(index)
    true

  # Making Underscore.js methods available directly on Collection.
  underscoreMethodsReturningCollection = [
    'forEach', 'each', 'map', 'filter', 'select', 'reject',
    'every', 'all', 'some', 'any', 'sortBy', 'toArray', 'rest', 'without',
    'shuffle'];

  for method in underscoreMethodsReturningCollection
    do (method) ->
      proto[method] = ->
        list = _[method].apply _, @models, arguments...
        new @constructor list

  underscoreMethods = [
    'reduce', 'reduceRight', 'find', 'detect',
    'include', 'contains', 'invoke', 'max', 'min', 'sortedIndex',
    'size', 'first', 'initial', 'last', 'indexOf',
    'lastIndexOf', 'isEmpty', 'groupBy', 'countBy'];

  for method in underscoreMethods
    do (method) ->
      proto[method] = ->
        _[method].apply _, @models, arguments...

  klass

# Sorted Collection.
exports.Collection.Sorted = (klass) ->
  proto = klass.prototype
  proto.isSortedCollection = true

  # Sorted mixin should be applied before Events, checking for that.
  throw new Error "Sorted mixin should be applied before Events!" if proto.hasEvents

  # Define comparator and collection always will be automatically sorted.
  proto.sort = (options) -> @_sort options

  proto._sort = (options) ->
    @comparator = options.comparator if options?.comparator?
    return false unless @comparator

    # Sorting.
    if @comparator.length == 1 then @models = _(@models).sortBy @comparator
    else @models.sort @comparator

    # Updating ids.
    changed = false
    for model, index in @models
      changed = true if @ids[model.id] != index
      @ids[model.id] = index
    changed

  # Adding support for sorting in `add` method.
  proto._addWithoutSort = proto._add
  proto._add = (models, options) ->
    added = @_addWithoutSort models, options

    # Sorting.
    if added.length > 0 then @_sort options
    else if options?.comparator? then @comparator = options.comparator
    added

  klass

# Collection with events, emit `add`, `delete`, `change` and `model:change`
# events.
exports.Collection.Events = (klass, type) ->
  exports.Events klass, type
  proto = klass.prototype

  # Helper for proxying model events to collection listeners.
  proto.initializeWithoutEvents = proto.initialize
  proto.initialize = (args...) ->
    @_forwardModelChangeEvent = (model, changes) => @trigger 'model:change', model, changes, @
    @initializeWithoutEvents args...

  # Adding events for `sort` method.
  if proto.sort?
    proto.sortWithoutEvents = proto.sort
    proto.sort = (options) ->
      changed = @sortWithoutEvents options
      @trigger 'change', @ if changed and not options?.silent
      changed

  # Adding events for `add` method.
  proto._addWithoutEvents = proto._add
  proto._add = (models, options) ->
    added = @_addWithoutEvents models, options
    @_emitAddChanges added, options
    added

  # Adding events for `delete` method.
  proto._deleteWithoutEvents = proto._delete
  proto._delete = (models, options) ->
    deleted = @_deleteWithoutEvents models, options
    @_emitDeleteChanges deleted, options
    deleted

  # Adding events for `clear` method.
  proto.clearWithoutEvents = proto._delete
  proto.clear = (options) ->
    deleted = @clearWithoutEvents options
    @_emitDeleteChanges deleted, options
    deleted

  # Emit changes.
  proto._emitAddChanges = (added, options) ->
    # Forwarding model change event.
    model.on 'change', @_forwardModelChangeEvent for model in added when model.hasEvents

    # Emitting events.
    if (added.length > 0) and not options?.silent
      @trigger 'add', model, @ for model in added
      @trigger 'change', @

  proto._emitDeleteChanges = (deleted, options) ->
    # Removing forwarding model change event.
    model.off 'change', @_forwardModelChangeEvent for model in deleted when model.hasEvents

    # Emitting events.
    if (deleted.length > 0) and not options?.silent
      @trigger 'delete', model, @ for model in deleted
      @trigger 'change', @

  klass

# # Utilities.

# Events.
exports.Events = (klass, type='EventEmitter') ->
  proto = klass.prototype
  proto.hasEvents = true

  # Integration with EventEmitter.
  if type == 'EventEmitter'
    EventEmitter = requireEventEmitter()

    _(proto).extend EventEmitter.prototype

    # Adding initialization.
    initializeWithoutEventEmitter = proto.initialize
    proto.initialize = ->
      EventEmitter.apply @
      initializeWithoutEventEmitter.apply @, arguments

    # Adding shortcuts.
    proto.on      = -> @addListener.apply @, arguments
    proto.off     = -> @removeListener.apply @, arguments
    proto.trigger = -> @emit.apply @, arguments

  # Integration with BackboneEvents.
  else if type == 'Backbone.Events'
    _(proto).extend requireBackboneEvents()
  else throw new Error "unknown type #{type}"

  klass

# Base class.
exports.BaseClass = -> -> @initialize?.apply(@, arguments); @

# Base Model and Collection.
exports.BaseModel      = exports.Model()
exports.BaseCollection = exports.Collection()

# Full Model and Collection.
exports.FullModel      = exports.Model.Events exports.Model()
exports.FullCollection = exports.Collection.Events exports.Collection.Sorted exports.Collection()

# Cast value to type, override it to provide more types.
# MicroModel.cast = (value, type) ->
#   if _.isFunction type then type value
#   else if type == String then v.toString()
#   else if type == Number
#     if _.isNumber(v) then v
#     else if _.isString v
#       tmp = parseInt v
#       tmp if _.isNumber tmp
#   else if type == Boolean
#     if _.isBoolean v then v
#     else if _.isString v then v == 'true'
#   else if type == Date
#     if _.isDate v then v
#     else if _.isString v
#       tmp = new Date v
#       tmp if _.isDate tmp
#   else
#     throw "can't cast to unknown type (#{type})!"