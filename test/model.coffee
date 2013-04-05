require './helper'

Model = require '../model'

describe "Model", ->
  [Unit, Item] = [null, null]
  beforeEach ->
    class Unit extends Model
    class Item extends Model

  it "should update attributes", ->
    unit = new Unit()
    expect(unit.attributes()).to.eql {}
    unit.set name: 'Probe'
    expect(unit.attributes()).to.eql name: 'Probe'

  it "should return attributes", ->
    unit = new Unit name: 'Probe', _cache: {}
    expect(unit.attributes()).to.eql name: 'Probe'

  it "should check for equality", ->
    unit1 = new Unit name: 'Zeratul', items: [new Item(name: 'Psionic blades')]
    unit2 = new Unit name: 'Zeratul', items: [new Item(name: 'Psionic blades')]
    expect(unit1.isEqual(unit2)).to.equal true
    unit1.items[0].name = 'Power suit'
    expect(unit1.isEqual(unit2)).to.equal false

  it "should compare with non models", ->
    unit = new Unit()
    expect(unit.isEqual(1)).to.equal false
    expect(unit.isEqual(null)).to.equal false
    expect(unit.isEqual({})).to.equal false
    expect(unit.isEqual(name: 'Probe')).to.equal false

  it "should validate", ->
    Unit::validate = ->
      @errors.name = ["can't be blank"] if not @name? or /^\s*$/.test(@name)

    unit = new Unit()
    expect(unit.isValid()).to.eql false
    expect(unit.errors).to.eql name: ["can't be blank"]

    unit.set name: 'Probe'
    expect(unit.isValid()).to.eql true
    expect(unit.errors).to.eql {}

  it "should provide validation helper", ->
    Unit.validations =
      name: (v) -> "can't be blank" if not v? or /^\s*$/.test(v)

    unit = new Unit()
    expect(unit.isValid()).to.eql false
    expect(unit.errors).to.eql name: ["can't be blank"]

  it "should convert to JSON", ->
    Unit::toJson = ->
      data = super()
      data.items = data.items.map (item) -> item.toJson()
      data
    unit = new Unit name: 'Zeratul', items: [new Item(name: 'Psionic blades')]
    expect(unit.toJson()).to.eql
      name  : 'Zeratul'
      items : [name: 'Psionic blades']

  it "should track attribute changes", ->
    unit = new Unit()
    expect(unit.set(name: 'Probe')).to.eql {name: undefined}
    expect(unit.set(name: 'SCV')).to.eql {name: 'Probe'}

  it "should not track the same value as attribute change", ->
    unit = new Unit()
    expect(unit.set(name: 'Probe')).to.eql {name: undefined}
    expect(unit.set(name: 'Probe')).to.eql {}

  it "should cast attributes to specified types", ->
    Unit.types
      health : Number
      alive  : (v) -> v == 'yes'

    unit = new Unit name: 'Probe'
    unit.castAndSet health: '100', alive: 'yes'
    expect(unit.attributes()).to.eql name: 'Probe', health: 100, alive: true

  it "should set only permitted attributes", ->
    Unit.types
      health : Number

    unit = new Unit name: 'Probe'
    unit.castAndSet health: '100', alive: 'yes'
    expect(unit.attributes()).to.eql name: 'Probe', health: 100