# If it's Browser, making it looks like "standard" JS.
global ?= window
try
  util = require 'util'
catch error
  util = {inspect: (data) -> JSON.stringify(data)}

_ = global._ || require 'underscore'

# Basic Model.
class Model
  constructor: (attributes) ->
    @set @defaults if @defaults
    @errors = new Model.Errors()
    @set attributes if attributes
    @changed = {}

  eq: (other) -> _.isEqual @, other

  set: (attributes = {}, options = {}) ->
    # Casting attributes.
    if options.cast
      unless @castAttributes
        throw new Error "you need to include PassiveModel.Conversion to be able to use casting!"
      attributes = @castAttributes attributes

    # Updating attributes & tracking changes.
    @changed = {}
    for own k, v of attributes
      @changed[k] = @[k] unless _.isEqual @[k], v
      @[k] = v

    # Notifying observers if Events module enabled.
    if @trigger? and !_.isEmpty(@changed) and (options.silent != true)
      for k, v of @changed
        event = "change:#{k}"
        @trigger event, event, @
      @trigger "change", 'change', @

    @

  clear: -> delete @[k] for own k, v of @

  valid: (options) ->
    oldErrors = @errors
    @errors = new Model.Errors()
    @validate()
    newErrors = @errors
    @errors = oldErrors
    @set errors: newErrors, options
    _(@errors).size() == 0

  # Provide Your own.
  validate: ->

  invalid: -> !@valid()

  attributes: ->
    attrs = {}
    attrs[k] = v for own k, v of @ when not /^_/.test k
    delete attrs.errors
    delete attrs.changed
    attrs

# Errors.

definePropertyWithoutEnumeration = (obj, name, value) ->
  Object.defineProperty obj, name,
      enumerable: false
      writable: true
      configurable: true
      value: value

class Model.Errors

definePropertyWithoutEnumeration Model.Errors.prototype, 'clear', ->
  delete @[k] for own k, v of @

definePropertyWithoutEnumeration Model.Errors.prototype, 'add', (args...) ->
  if args.length == 1
    @add attr, message for attr, message of args[0]
  else
    [attr, message] = args
    @[attr] ?= []
    @[attr].push message

# Support for conversions.
#
# Use following code to add it to Your model:
#
#     class MyModel extends Model
#     _(MyModel).extend Model.Conversion
#     _(MyModel.prototype).extend Model.Conversion.prototype
#
class Conversion

  # Attribute Conversion.

  @cast: (args...) ->
    if args.length == 1
      @cast attr, type for own attr, type of args[0]
    else
      [attr, type] = args
      caster = "cast#{attr[0..0].toUpperCase()}#{attr[1..attr.length]}"
      @prototype[caster] = (v) ->
        if type then Conversion._cast(v, type) else v

  castAttributes: (attributes = {}) ->
    casted = {}
    for own k, v of attributes
      caster = "cast#{k[0..0].toUpperCase()}#{k[1..k.length]}"
      casted[k] = @[caster] v if caster of @
    casted

  # Model Conversion.

  @_children: []
  @children: (args...) -> @_children = @_children.concat args

  toHash: (options = {errors: true}) ->
    # Converting Attributes.
    hash = @attributes()
    hash.errors = @errors if options.errors

    # Converting children objects.
    that = @
    for k in @constructor._children
      if obj = that[k]
        if obj.toHash
          r = obj.toHash options
        if obj.toArray
          r = obj.toArray()
        else if Conversion._isArray obj
          r = []
          for v in obj
            v = if v.toHash then v.toHash(options) else v
            r.push v
        else if Conversion._isObject obj
          r = {}
          for own k, v of obj
            v = if v.toHash then v.toHash(options) else v
            r[k] = v
        hash[k] = r

    # Adding class.
    if options.class
      hash._class = @constructor.name ||
        throw new Error "no constructor name for #{util.inspect(@)}!"

    hash

  # Updates state from Hash.
  fromHash: (hash) ->
    model = @constructor.fromHash hash, @constructor.name
    attributes = model.attributes?() || model
    @set attributes
    @errors = model.errors
    @

  # Creates new model from Hash.
  @fromHash: (hash, klass) ->
    klass ?= hash._class
    return hash unless klass

    # Creating object.
    klass = @getClass klass
    obj = new klass()

    # Restoring attributes.
    obj[k] = v for own k, v of hash
    delete obj._class

    # Restoring children.
    that = @
    for k in klass._children
      if o = hash[k]
        if o._class
          r = that.fromHash o
        else if Conversion._isArray o
          r = []
          for v in o
            v = if v._class then that.fromHash(v) else v
            r.push v
        else if Conversion._isObject o
          r = {}
          for own k, v of o
            v = if v._class then that.fromHash(v) else v
            r[k] = v
      obj[k] = r

    # Allow custom processing to be added.
    klass.afterFromHash? obj, hash

    obj

  # Override this method to provide different strategy of class loading.
  @getClass: (name) ->
    app?[name] ||
    app?.Models?[name] ||
    app?.models?[name] ||
    global.Models?[name] ||
    global.models?[name] ||
    global[name] ||
    throw new Error "can't get '#{name}' class!"

  # Helpers.

  @_isArray = (obj) -> Array.isArray obj

  @_isObject = (obj) -> Object.prototype.toString.call(obj) == "[object Object]"

  @_cast = (v, type) ->
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
      throw new Error "can't cast, unknown type (#{util.inspect type})!"

    throw new Error "can't cast, invalid value (#{util.inspect v})!" unless casted?
    casted

# Collection.
class Model.Collection
  constructor: (models, options = {}) ->
    [@models, @length, @ids] = [[], 0, {}]
    @comparator = options.comparator
    @add models if models

  sort: (options) ->

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

  get: (id) -> @ids[id]

  at: (index) -> @models[index]

  clear: (options = {}) ->
    # Deleting
    deleted = @models
    [@models, @length, @ids] = [[], 0, {}]

    # Notifying
    if @trigger and (options.silent != true) and (deleted.length > 0)
      @trigger 'delete', model, @ for model in deleted
      @trigger 'change', @

    @

# Validations.
class Model.Validations
  validatesPresenceOf: (attrs...) ->
    for attr in attrs
      @errors.add attr, "can't be blank" if _.isEmpty @[attr]

# Integration with JSON.
# Conversion.prototype.toJSON = Conversion.prototype.toHash

# Integration with mongo-lite & rest-lite.
_(Conversion.prototype).extend
  isModel  : true
  getId    : -> @id
  setId    : (id) -> @id = id
  addError : (args...) -> @errors.add args...
  toMongo  : -> @toHash errors: false, class: true
  fromRest : Conversion.prototype.fromHash
  toRest   : -> @toHash errors: false, class: false

_(Conversion).extend
  fromMongo : Conversion.fromHash
  fromRest  : Conversion.fromHash

# Universal exports `module.exports`.
Model.Conversion = Conversion
if module?
  module.exports = Model
else
 window.PassiveModel = Model