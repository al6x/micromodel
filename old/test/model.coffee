require './helper'

{BaseModel, Model, FullModel} = require '../micromodel'

describe "Model", ->
  it "should update attributes", ->
    unit = new BaseModel()
    expect(unit.attributes()).to.eql {}
    unit.set name: 'Probe'
    expect(unit.attributes()).to.eql name: 'Probe'

  it "should return attributes", ->
    unit = new BaseModel name: 'Probe', _cache: {}
    expect(unit.attributes()).to.eql name: 'Probe'

  it "should check for equality", ->
    unit1 = new BaseModel name: 'Zeratul', items: [new BaseModel(name: 'Psionic blades')]
    unit2 = new BaseModel name: 'Zeratul', items: [new BaseModel(name: 'Psionic blades')]
    expect(unit1.isEqual(unit2)).to.equal true
    unit1.items[0].name = 'Power suit'
    expect(unit1.isEqual(unit2)).to.equal false

  it "should compare with non models", ->
    unit = new BaseModel()
    expect(unit.isEqual(1)).to.equal false
    expect(unit.isEqual(null)).to.equal false
    expect(unit.isEqual({})).to.equal false
    expect(unit.isEqual(name: 'Probe')).to.equal false

  it "should validate", ->
    Unit = Model()
    Unit.prototype.validate = ->
      errors = {}
      errors.name = ["can't be blank"] if not @name? or /^\s*$/.test(@name)
      if _(errors).isEmpty() then null else errors

    unit = new Unit()
    expect(unit.validate()).to.eql name: ["can't be blank"]
    expect(unit.isValid()).to.eql false

    unit.set name: 'Probe'
    expect(unit.validate()).to.equal null
    expect(unit.isValid()).to.eql true

  it "should provide validation helper", ->
    Unit = Model()
    Unit.prototype.validations =
      name: (v) -> "can't be blank" if not v? or /^\s*$/.test(v)

    unit = new Unit()
    expect(unit.validate()).to.eql name: ["can't be blank"]

  it "should convert to JSON", ->
    unit = new BaseModel name: 'Zeratul', items: [new BaseModel(name: 'Psionic blades')]
    expect(unit.toJSON()).to.eql
      name  : 'Zeratul'
      items : [name: 'Psionic blades']

  it "should track attribute changes", ->
    unit = new BaseModel()
    expect(unit.set(name: 'Probe')).to.eql {name: undefined}
    expect(unit.set(name: 'SCV')).to.eql {name: 'Probe'}

  it "should not track the same value as attribute change", ->
    unit = new BaseModel()
    expect(unit.set(name: 'Probe')).to.eql {name: undefined}
    expect(unit.set(name: 'Probe')).to.eql {}

  describe "Events", ->

    it "should emit change events", ->
      unit = new FullModel(name: '', race: '')
      events = []
      unit.on 'change:name', (args...) -> events.push 'change:name', args...
      unit.on 'change:race', (args...) -> events.push 'change:race', args...
      unit.on 'change', (args...) -> events.push 'change', args...
      unit.set name: 'Probe', race: 'Protoss'
      unit.set name: 'Probe'
      expect(events).to.eql [
        'change:name', unit, '',
        'change:race', unit, '',
        'change', unit, {name: '', race: ''},
      ]

  # it "should set only permitted attributes", ->
  #   unit = new BaseModel()
  #   unit.set {name: 'Probe', state: 'alive'}, permit: ['name']
  #   expect(unit.attributes()).to.eql {name: 'Probe'}

  # it "should cast attributes if specified", ->
  #   Unit = Class 'Unit', withModel,
  #     schema:
  #       health : Number
  #       alive  : (v) -> v == 'yes'
  #
  #   unit = new Unit()
  #   unit.set name: 'Probe', health: '100', alive: 'yes'
  #   expect(unit.attributes()).to.eql name: 'Probe', health: 100, alive: true