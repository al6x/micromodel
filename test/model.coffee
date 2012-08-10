global.p         = (args...) -> console.log args...

expect           = require('chai').expect
MicroModel       = require '../micromodel'
Model            = MicroModel.Model
withModel        = MicroModel.withModel
withEventEmitter = MicroModel.withEventEmitter
_                = require 'underscore'
Class            = MicroModel.Class

describe "Model", ->
  it "should update attributes", ->
    unit = new Model()
    expect(unit.attributes()).to.eql {}
    unit.set name: 'Probe'
    expect(unit.attributes()).to.eql name: 'Probe'

  it "should return attributes", ->
    unit = new Model name: 'Probe', _cache: {}
    expect(unit.attributes()).to.eql name: 'Probe'

  it "should check for equality", ->
    Unit = Class 'Unit', withModel
    Protoss = Class 'Protoss', withModel
    Item = Class 'Item', withModel
    unit1 = new Unit    name: 'Zeratul', items: [new Item(name: 'Psionic blades')]
    unit2 = new Protoss name: 'Zeratul', items: [new Item(name: 'Psionic blades')]
    expect(unit1.eql(unit2)).to.equal true
    expect(unit1.equal(unit2)).to.equal false
    unit1.items[0].name = 'Power suit'
    expect(unit1.eql(unit2)).to.equal false

  it "should compare with non models", ->
    unit = new Model()
    expect(unit.eql(1)).to.equal false
    expect(unit.eql(null)).to.equal false
    expect(unit.eql({})).to.equal true
    expect(unit.eql(name: 'Probe')).to.equal false

  it "should validate", ->
    Unit = Class 'Unit', withModel,
      validate: (attrs = {}) ->
        errors = {}
        errors.name = ["can't be blank"] if /^\s*$/.test attrs.name
        if _(errors).isEmpty() then null else errors

    unit = new Unit()
    expect(unit.set(name: '')).to.equal false
    expect(unit.attributes()).to.eql {}
    expect(unit.set(name: 'Probe')).to.equal true
    expect(unit.attributes()).to.eql name: 'Probe'
    expect(unit.set({name: ''}, validate: false)).to.equal true
    expect(unit.attributes()).to.eql name: ''

  it "should provide validation helper", ->
    Unit = Class 'Unit', withModel,
      validations:
        name: (v) -> "can't be blank" if /^\s*$/.test v

    unit = new Unit()
    expect(unit.validate(name: '')).to.eql name: ["can't be blank"]

  it "should track attribute changes", ->
    unit = new Model()
    expect(unit._changed).to.eql {}
    unit.set name: 'Probe'
    expect(unit._changed).to.eql {name: undefined}
    unit.set name: 'SCV'
    expect(unit._changed).to.eql {name: 'Probe'}

  it "should not track changes if silent specified", ->
    unit = new Model()
    expect(unit._changed).to.eql {}
    unit.set {name: 'Probe'}, silent: true
    expect(unit._changed).to.eql {}

  it "should not track the same value as attribute change", ->
    unit = new Model()
    unit.set name: 'Probe', state: 'alive'
    unit.set name: 'Probe', state: 'dead'
    expect(unit._changed).to.eql {state: 'alive'}

  it "should set only permitted attributes", ->
    unit = new Model()
    unit.set {name: 'Probe', state: 'alive'}, permit: ['name']
    expect(unit.attributes()).to.eql {name: 'Probe'}

  it "should cast attributes if specified", ->
    Unit = Class 'Unit', withModel,
      schema:
        health : Number
        alive  : (v) -> v == 'yes'

    unit = new Unit()
    unit.set name: 'Probe', health: '100', alive: 'yes'
    expect(unit.attributes()).to.eql name: 'Probe', health: 100, alive: true

  it "should emit change events", ->
    Unit = Class 'Unit', withModel, withEventEmitter
    unit = new Unit()
    events = []
    unit.on 'change:name', -> events.push 'change:name'
    unit.on 'change:race', -> events.push 'change:race'
    unit.on 'change', -> events.push 'change'
    unit.set name: 'Probe', race: 'Protoss'
    expect(events).to.eql ['change:name', 'change:race', 'change']

  it "should convert to JSON", ->
    Unit = Class 'Unit', withModel
    Item = Class 'Item', withModel
    unit = new Unit name: 'Zeratul', items: [new Item(name: 'Psionic blades')]
    expect(JSON.parse(JSON.stringify(unit))).to.eql
      name  : 'Zeratul'
      items : [name: 'Psionic blades']