# If it's Browser, making it looks like "standard" JS.
global ?= window
util = require?('util') || {inspect: (data) -> JSON.stringify(data)}

_ = global._ || require 'underscore'

# Basic Model.
class Model
  isModel: true

  constructor: (attributes) ->
    @set @defaults if @defaults
    @set attributes if attributes
    @errors = new Model.Errors()

  eq: (other) -> _.isEqual @, other

  set: (attributes = {}, options = {}) ->
    @[k] = v for own k, v of attributes
    @

  clear: -> delete @[k] for own k, v of @

  valid: -> _(@errors).size() == 0

  invalid: -> !@valid()

  attributes: ->
    attrs = {}
    attrs[k] = v for own k, v of @ when not /^_/.test k
    delete attrs.errors
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
      setterName = "set#{attr[0..0].toUpperCase()}#{attr[1..attr.length]}WithCasting"
      @prototype[setterName] = (v) ->
        v = if type then Conversion._cast(v, type) else v
        @[attr] = v

  set: (attributes = {}, options = {}) ->
    if options.cast then @setWithCasting(attributes) else _(@).extend(attributes)
    @

  setWithCasting: (attributes = {}) ->
    for own k, v of attributes
      setterName = "set#{k[0..0].toUpperCase()}#{k[1..k.length]}WithCasting"
      @[setterName] v if setterName of @
    @

  # Model Conversion.

  @_children: []
  @children: (args...) -> @_children = @_children.concat args

  getId: -> @id

  setId: (id) -> @id = id

  toHash: ->
    # Converting Attributes.
    hash = @attributes()

    # Converting children objects.
    that = @
    for k in @constructor._children
      if obj = that[k]
        if obj.toHash
          r = obj.toHash()
        if obj.toArray
          r = obj.toArray()
        else if Conversion._isArray obj
          r = []
          for v in obj
            v = if v.toHash then v.toHash() else v
            r.push v
        else if Conversion._isObject obj
          r = {}
          for own k, v of obj
            v = if v.toHash then v.toHash() else v
            r[k] = v
        hash[k] = r

    # Adding class.
    hash._class = @constructor.name ||
      throw new Error "no constructor name for #{util.inspect(@)}!"

    hash

  # Updates state from Hash.
  fromHash: (hash) ->
    model = @constructor.fromHash hash, @
    _(@).extend(model.attributes?() || model)
    @errors = model.errors
    @

  # Creates new model from Hash.
  @fromHash: (hash) ->
    return hash unless hash._class

    # Creating object.
    klass = @getClass hash._class
    obj = new klass()

    # Restoring attributes.
    obj[k] = v for own k, v of hash
    delete obj._class

    # Restoring children.
    that = @
    for k in klass._children
      if o = hash[k]
        if o._class
          r = that.fromHash o, obj
        else if Conversion._isArray o
          r = []
          for v in o
            v = if v._class then that.fromHash(v, obj) else v
            r.push v
        else if Conversion._isObject o
          r = {}
          for own k, v of o
            v = if v._class then that.fromHash(v, obj) else v
            r[k] = v
      obj[k] = r

    # If it's nested object also setting its parent.
    # obj._parent = parent if parent

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

# Universal exports `module.exports`.
Model.Conversion = Conversion
if module?
  module.exports = Model
else
 window.PassiveModel = Model