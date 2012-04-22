superagent ?= require 'superagent'
PassiveModel ?= require 'passive-model'

# Utility functions.
rp = superagent.Request.prototype

# Adding delete.
superagent.delete = superagent.del

# Making superagent return (err, res) if we supply two arguments to callback.
rp.endWithoutErr = rp.end
rp.end = (fn) ->
  @endWithoutErr (res) ->
    return fn(res) if fn.length < 2
    if res.ok then fn(null, res) else fn(response.text);

# `id` helper `.get('/users').id('alex')`.
rp.id = (obj) ->
  @url = "#{@url}/#{obj.id? || obj}"
  @

# Allow send Model.
rp.sendWithoutModel = rp.send
rp.send = (data) ->
  if data._model
    @model data
    data = data.toHash()
  @sendWithoutModel data

# Unmarshal or update model.
rp.model = (model) ->
  @model = model
  @

rp.endWithoutModel = rp.end
rp.end = (fn) ->
  @endWithoutModel (err, res) =>
    if @model and !err
      data = res.body
      if _.isFunction @model
        # unmarshalling model or array of models.
        if _.isArray data
          models = (PassiveModel.fromHash(doc, @model) for doc in data)
          fn null, models
        else
          fn null, PassiveModel.fromHash(res.body, @model)
      else
        # updating existing model.
        fn null, @model.fromHash(data)
    else
      fn err, res