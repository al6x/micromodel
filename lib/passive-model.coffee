# If it's Browser, making it looks like Node.js.
global ?= window
_      = global._ || require 'underscore'

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
#     _(User.prototype).extend EventEmitter.prototype
EventEmitter = null
class Model
  # Initializing new model from `attrs` and `defaults` property.
  constructor: (attrs, options) ->
    @set @defaults, options if @defaults
    @set attrs, options if attrs
    @_changed = {}

    # Initializing EventEmitter if provided.
    if @emit
      EventEmitter ?= global.EventEmitter || require('events').EventEmitter
      EventEmitter.call @

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
  # If model implements `emit` method (for example by mixing `EventEmitter`)
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
    unless options.silent or !@emit or _.isEmpty(@_changed)
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
    if _.size(errors) > 0 then errors else null

  # Define validation rules and store errors in `errors` property `@errors.add name: "can't be blank"`.
  isValid: -> @validate @

  attributes: -> attributes @

  # JSON conversion, including nested models.
  toJSON: -> attributes @

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

# # # Collection
# #
# # Collection can store models, automatically sort it with given order and
# # notify watchers with `add`, `change`, and `delete` events if Events module provided.
# class Model.Collection
#
#   # Initialize collection, You may provide array of models and options.
#   constructor: (models, options = {}) ->
#     [@models, @length, @ids] = [[], 0, {}]
#     @comparator = options.comparator
#     @add models if models
#
#   # Define comparator and collection always will be automatically sorted.
#   sort: (options) ->
#     @comparator = options.comparator if options.comparator
#     throw "no comparator!" unless @comparator
#
#     if @comparator.length == 1
#       @models = _(@models).sortBy @comparator
#     else
#       @models.sort @comparator
#     @trigger 'change', @ if options.silent != true
#     @
#
#   # Add model or models, `add` and `change` events will be triggered (if Events module provided).
#   add: (args...) ->
#     if _.isArray(args[0])
#       [models, options] = [args[0], {}]
#     else
#       options = unless args[args.length - 1]?._model then args.pop() else {}
#       options ?= {}
#       models = args
#
#     # Transforming to model if specified and models aren't already of class of model.
#     if @modelClass and models.length > 0 and !models[0]._model
#       models = (new @modelClass model for model in models)
#
#     # Adding.
#     for model in models
#       @models.push model
#       @ids[model.id] = model unless _.isEmpty(model.id)
#     @length = @models.length
#
#     # Callback to hook additional logic, sorting and filtering for example.
#     @onAdd models
#
#     # Notifying
#     if @trigger and (options.silent != true)
#       @trigger 'add', model, @ for model in models
#       @trigger 'change', @
#
#     @
#
#   onAdd: (models) ->
#     # Sorting.
#     @sort silent: true if @comparator
#
#   # Delete model or models, `delete` and `change` events will be triggered (if Events module provided).
#   delete: (args...) ->
#     if _.isArray(args[0])
#       [models, options] = [args[0], {}]
#     else
#       options = unless args[args.length - 1]?._model then args.pop() else {}
#       options ?= {}
#       models = args
#
#     # Deleting
#     deleted = []
#     for model in models
#       id = model.id
#       unless _.isEmpty id
#         if id of @ids
#           deleted.push model
#           delete @ids[id]
#           index = @models.indexOf model
#           @models.splice index, 1
#       else
#         for m, index in @models when model.eql m
#           deleted.push m
#           delete @ids[m.id]
#           @models.splice index, 1
#
#     @length = @models.length
#
#     # Callback.
#     @onDelete deleted
#
#     # Notifying
#     if @trigger and (options.silent != true) and (deleted.length > 0)
#       @trigger 'delete', model, @ for model in deleted
#       @trigger 'change', @
#
#     @
#
#   # Override it if You need additional actions taken on delete.
#   onDelete: ->
#
#   # Get model by id.
#   get: (id) -> @ids[id]
#
#   # Get model by index.
#   at: (index) -> @models[index]
#
#   # Clear collection, `delete` and `change` events will be triggered (if Events module provided).
#   clear: (options = {}) ->
#     # Deleting
#     deleted = @models
#     [@models, @length, @ids] = [[], 0, {}]
#
#     # Notifying
#     if @trigger and (options.silent != true) and (deleted.length > 0)
#       @trigger 'delete', model, @ for model in deleted
#       @trigger 'change', @ unless deleted.length == 0
#
#     @
#
#   reset: (args...) ->
#     @clear()
#     @add args...
#
#   # Callbacks will be called when collection will be loaded. Collection marked as loaded
#   # by calling `loaded` without arguments.
#   loaded: (callback) ->
#     if callback
#       if @_loaded then callback() else (@_loadedListeners ?= []).push callback
#     else
#       callback() for callback in (@_loadedListeners || [])
#       delete @_loadedListeners
#       @_loaded = true

# Exporting.
if module?
  module.exports = Model
else
  global.PassiveModel = Model