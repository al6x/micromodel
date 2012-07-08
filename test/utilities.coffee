global.p      = (args...) -> console.log args...

expect        = require('chai').expect
PassiveModel  = require '../passive-model'
Model         = PassiveModel.Model
Collection    = PassiveModel.Collection
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'

describe "Utilities", ->
  it "should support inheritance without CoffeeScript", ->
    Unit = Model.extend
      defaults:
        health: 100

      initialize: ->
        @stats = {}

      isAlive: -> @health > 0

    unit = new Unit()
    expect(unit.attributes()).to.eql health: 100, stats: {}
    expect(unit).to.be.an.instanceof Model