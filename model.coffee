_ = require 'underscore' unless _?

# Helpers.
defineClassInheritableAccessor = (obj, name, defaultValue) ->
  _name = "_#{name}"
  obj[name] = ->
    @[_name] ?= _(defaultValue).clone()
    @[_name] = _(@[_name]).clone() if @[_name] == @__super__?.constructor[_name]
    @[_name]

# # Model
#
# Attributes stored and accessed as properties `model.name` but it shoud be setted only
# via the `set` - `model.set name: 'foo'`.
#
# Properties with `_` prefix are ignored.
class Model
  attributeRe = /^_|^errors$/

  isModel: true

  # Defaults.
  defineClassInheritableAccessor @, '_defaults', {}
  @defaults: (attrs) ->
    if attrs then @_defaults()[name] = value for name, value of attrs
    else @_defaults()

  # Initializing model from `attrs` and `defaults` property.
  constructor: (attrs, options) ->
    @errors = {}
    @set defaults, options unless _.isEmpty(defaults = @constructor.defaults())
    @set attrs, options if attrs
    @

  isNew: -> @id?

  # Equality check based on the content, deep.
  isEqual: (other) ->
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
  set: (attrs, options) ->
    return {} unless attrs?
    return @castAndSet attrs, options if options and options.cast

    # Parsing attributes.
    attrs = @parse attrs if @parse

    changes = {}
    for own name, newValue of attrs when not attributeRe.test name
      # Tracking changes.
      oldValue = @[name]
      changes[name] = oldValue unless _.isEqual oldValue, newValue

      # Updating.
      @[name] = newValue
    changes

  # Shallow clone.
  clone: -> new @constructor @attributes()

  # Clear attributes.
  clear: (options) ->
    changes = attributes()
    delete @[name] for own name of @
    changes

  # Validations.
  defineClassInheritableAccessor @, '_validations', {}
  @validations: (validations) ->
    if validations then @_validations()[name] = validator for name, validator of validations
    else @_validations()

  # Define validation rules using `model.validations` or `model.validate`, check validity of model
  # with `model.isValid()`.
  #
  # Validating attributes, returns `null` if attributes valid or any not null object as error.
  validate: ->
    for own name, validator of @constructor.validations()
      (@errors[name] ?= []).push msg if msg = validator @[name]

  # Define validation rules and store errors in `errors` property `@errors.add name: "can't be blank"`.
  isValid: ->
    @errors = {}
    @validate()
    _(@errors).isEmpty()

  hasErrors: -> !_(@errors).isEmpty()

  attributes: ->
    attrs = {}
    attrs[name] = value for own name, value of @ when not attributeRe.test name
    attrs

  toJson: -> @attributes()
  toJSON: (args...) -> @toJson args...

  toString: -> JSON.stringify @toJson()

  # Generates random string ids.
  @generateId: (length) ->
    length  ?= 6
    symbols = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    [id, count] = ["", length + 1]
    while count -= 1
      rand = Math.floor(Math.random() * symbols.length)
      id += symbols[rand]
    id

  # Type casting, override it to provide more types.
  @cast: (value, type) ->
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
      throw new Error "can't cast to unknown type '#{type}'!"

  # Schema used for attribute casting.
  defineClassInheritableAccessor @, '_types', {}
  @types: (types) ->
    if types then @_types()[name] = type for name, type of types
    else @_types()

  # Cast attributes to types and set.
  castAndSet: (attrs, options) ->
    casted = {}
    for name, type of @constructor.types() when name of attrs
      casted[name] = Model.cast attrs[name], type
    if options and options.cast
      options = _(options).clone()
      delete options.cast
    @set casted, options

# Exporting.
if module?.exports? then module.exports = Model else window.Model = Model