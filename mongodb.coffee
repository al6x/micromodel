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
sync Db::, 'collection', 'clear'
sync Collection::, 'insert', 'findOne', 'count', 'remove', 'update', 'ensureIndex', 'indexes', 'drop'
sync Cursor::, 'toArray', 'count'

# MongoDB persistence for Model.
module.exports.ModelPersistence = (Model) ->
  extractCustomOptions = (options) ->
    options = _(options).clone()
    originalId = options.originalId
    delete options.originalId
    bang = options.bang
    delete options.bang
    [options, {bang: bang, originalId: originalId}]

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
    [options, {bang}] = extractCustomOptions options

    data = @collection().findOne(selector, options)
    if data then new @ data
    else if bang
      throw new Error "document '#{inspect selector}', '#{inspect options}' not found!"
    else null

  Model.all = (selector = {}, options = {}) ->
    @collection().find(selector, options).toArray().map (o) => new @(o)

  Model.count = (selector = {}, options = {}) -> @collection().count(selector, options)

  Model.build = (attrs) -> new @ attrs

  Model.create = (attrs, options) ->
    model = @build attrs
    model.create(options) || throw new Error "can't save!"
    model

  Model::create = (options = {}) ->
    [options, {bang}] = extractCustomOptions options
    fail = -> if bang then throw new Error "can't create invalid model '#{@}'!" else false

    return fail() unless @isValid()
    result = handleSomeErrors @, =>
      @collection().insert @toJson(), options
    result || fail()

  Model::update = (options = {}) ->
    [options, {bang, originalId}] = extractCustomOptions options
    fail = -> if bang then throw new Error "can't update invalid model '#{@}'!" else false

    return fail() unless @isValid()
    result = handleSomeErrors @, =>
      # In case of id change using original id.
      @collection().update {id: (originalId || @id)}, @toJson(), options
    result || fail()

  Model::delete = (options = {}) ->
    @collection().remove {id: @id}, options

  Model::refresh = (options = {}) -> @set @collection().findOne({id: @id}, options)

inspect = (obj) -> JSON.stringify obj