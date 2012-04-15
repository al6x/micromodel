global.expect = require 'expect.js'
global.p      = (args...) -> console.log args...
Model         = require '../lib/passive-model'

# Namespace for temporarry objects.
global.Tmp = {}
beforeEach ->
  global.Tmp = {}

# Stubbing class loading.
Model.getClass = (name) ->
  Tmp[name] || (throw new Error "can't get '#{name}' class!")