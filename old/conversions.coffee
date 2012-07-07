# Casting attributes.
attributes = @castAttributes attributes


# # Conversions.
#
# Convert model to and from Hash, also supports child models.

# Adding conversion methods to Model prototype.
_(Model.prototype).extend
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
    hash.errors = @errors unless options.errors == false

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
    if options.class
      klass = @constructor.name || throw "no constructor name!"
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
    throw "can't unmarshal model, no class provided!" unless klass
    throw Error "#{klass} isn't ancestor of Model!" unless klass.prototype._model

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
    obj.afterUnmarshalling? hash

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
      throw "can't get '#{name}' class!"
