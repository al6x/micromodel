# Adapter integrating PassiveModel with mongo-lite.
_     = require 'underscore'
mongo = require 'mongo-lite'
Model = require '../passive-model'

# Extending Passive Model.

_(Model.prototype).extend
  # Convert model to mongo hash.
  toMongo  : -> @toHash except: ['errors']

_(Model).extend
  # Restores model from mongo hash.
  #
  # To get class name it uses `class` attribute of document or `collection.options.class`. You
  # also may override it and provide custom implementation.
  fromMongo : (doc, collection) ->
    className = collection.options.class || doc.class
    if className
      klass = @getClass className
      @fromHash doc, klass
    else
      doc

# Extending Mongo `Collection`.
colp = mongo.Collection.prototype
_(colp).extend

  # Extending `create`.
  createWithoutModel: colp.create
  create: (obj, options..., callback) ->
    if obj._model
      doc = obj.toMongo()

      @createWithoutModel doc, options..., (err, result) ->
        # In case of model result should be boolean value.
        result = not err

        # Setting new id.
        obj.id = mongo.helper.getId(doc) unless err

        # Intercepting unique index errors and storing it as model errors.
        if err and (err.code in [11000, 11001])
          obj.errors.add base: 'not unique'
          err = null

        callback err, result
    else
      @createWithoutModel obj, options..., callback

  # Extending `update`.
  updateWithoutModel: colp.update
  update: (args..., callback) ->
    if args[0]._model
      [model, options] = [args[0], (args[1] || {})]
      id = model.id || throw new Error "can't update model without id!"
      doc = model.toMongo()
      selector = {}
      mongo.helper.setId selector, id
      @updateWithoutModel selector, doc, options, (err, result) ->
        # In case of model result should be boolean value.
        callback err, (not err)
    else
      @updateWithoutModel args..., callback

  # Extending `delete`.
  deleteWithoutModel: colp.delete
  delete: (args..., callback) ->
    if args[0]._model
      [model, options] = [args[0], (args[1] || {})]
      id = model.id || throw new Error "can't delete model without id!"
      selector = {}
      mongo.helper.setId selector, id
      @deleteWithoutModel selector, options, (err, result) ->
        # In case of model result should be boolean value.
        callback err, (not err)
    else
      @deleteWithoutModel args..., callback

  # Extending `save`.
  saveWithoutModel: colp.save
  save: (args..., callback) ->
    if args[0]._model
      model = args[0]
      if model.id
        @update args..., callback
      else
        @create args..., callback
    else
      @saveWithoutModel args..., callback


# Extending Mongo `Cursor`.
curp = mongo.Cursor.prototype
_(curp).extend

  # Extending `next`.
  nextWithoutModel: curp.next
  next: (callback) ->
    @nextWithoutModel (err, doc) =>
      return callback err if err
      obj = if doc and doc.class and !@options.doc
        Model.fromMongo doc, @collection
      else
        doc
      callback err, obj