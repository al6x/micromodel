require './helper'
Model    = require '../lib/passive-model'
_        = require 'underscore'
Backbone = require 'backbone'

# Adding Events mixin to Model.
class EModel extends Model
_(EModel.prototype).extend Backbone.Events

describe 'Integration with Events', ->
  it "should trigger changed attributes", ->
    class Unit extends EModel

    unit = new Unit()
    events = []
    unit.on 'change:name', (event, model)-> events.push event
    unit.set name: 'probe'
    expect(events).to.eql ['change:name']