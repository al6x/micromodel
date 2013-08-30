sync = require 'synchronize'
_    = require 'underscore'
{MongoClient, Db, Collection, Cursor} = module.exports = require 'mongodb'

# Clear database.
Db::clear = (callback) ->
  throw new Error "callback required!" unless callback

  @collectionNames (err, names) =>
    return callback err if err
    names = _(names).collect (obj) -> obj.name.replace(/^[^\.]+\./, '')
    names = _(names).select((name) -> !/^system\./.test(name))

    counter = 0
    dropNext = =>
      if counter == names.length then callback()
      else
        name = names[counter]
        counter += 1
        @collection name, (err, collection) ->
          return callback err if err
          collection.drop (err) ->
            return callback err if err
            dropNext()
    dropNext()

# Synchronising.
sync MongoClient, 'connect'
sync Db::, 'collection', 'clear', 'eval'
sync Collection::, 'insert', 'findOne', 'count', 'remove', 'update', 'ensureIndex', 'indexes' \
, 'drop', 'aggregate'
sync Cursor::, 'toArray', 'count', 'nextObject'

# MongoDB persistence for Model.
module.exports.ModelPersistence = (Model) ->
  handleSomeErrors = (model, fn) ->
    try
      fn()
      true
    catch err
      if err.code in [11000, 11001]
        (model.errors.base ||= []).push 'not unique'
        false
      else throw err

  Model.db = (db) ->
    if db then @_db = db
    else @_collection || throw new Error "db for '#{@}' not specified!"
  Model::db = -> @constructor.db()

  Model.collection = (name) ->
    if name then @_collection = name
    else @db().collection @_collection || throw new Error "collection name for '#{@}' not specified!"
  Model::collection = -> @constructor.collection()

  Model.first = (selector = {}, options = {}) ->
    data = @collection().findOne(selector, options)
    if data then new @ data else null

  Model.firstRequired = (selector = {}, options = {}) ->
    @first(selector, options) || (throw new Error("no '#{@name}' for '#{selector}' query!"))

  Model.exist = (selector = {}) -> !!@first(selector, {_id: 1})

  Model.all = (selector = {}, options = {}) ->
    @collection().find(selector, options).toArray().map (o) => new @(o)

  Model.find = (selector = {}, options = {}) ->
    @collection().find(selector, options)

  Model.count = (selector = {}, options = {}) -> @collection().count(selector, options)

  Model.build = (attrs) -> new @ attrs

  Model.create = (attrs, options) ->
    model = @build attrs
    model.create(options) || throw new Error "can't save!"
    model

  Model::create = (options = {}) ->
    return false unless @isValid()
    handleSomeErrors @, =>
      @collection().insert @toJson(), options

  Model::update = (options = {}) ->
    options = _(options).clone()
    originalId = options.originalId
    delete options.originalId

    return false unless @isValid()
    handleSomeErrors @, =>
      # In case of id change using original id.
      @collection().update {id: (originalId || @id)}, @toJson(), options

  Model::delete = (options = {}) ->
    @collection().remove {id: @id}, options

  Model::refresh = (options = {}) -> @set @collection().findOne({id: @id}, options)

inspect = (obj) -> JSON.stringify obj