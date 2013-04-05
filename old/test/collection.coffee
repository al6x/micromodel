require './helper'

{BaseModel, Model, FullModel, BaseCollection, Collection, FullCollection} = require '../micromodel'

describe "Collection", ->
  beforeEach ->
    @probe = new BaseModel name: 'Probe', id: 'probe'
    @scv   = new BaseModel name: 'SCV',   id: 'scv'

  it "should add, delete and get by id and index", ->
    units = new BaseCollection @probe
    expect(units).to.have.length 1
    units.add @scv
    expect(units).to.have.length 2

    expect(units.at(0)).to.eql @probe
    expect(units.at(1)).to.eql @scv

    expect(units.get(@probe.id)).to.eql @probe

    units.delete @probe
    units.delete @probe
    expect(units).to.have.length 1
    units.delete @scv
    expect(units).to.have.length 0

  it "should not add twice", ->
    units = new BaseCollection @probe, @probe
    units.add @probe
    expect(units).to.have.length 1

  it "should check for equality", ->
    group1 = new BaseCollection @probe
    group2 = new BaseCollection @probe
    group3 = new BaseCollection @scv
    expect(group1.isEqual(group2)).to.equal true
    expect(group1.isEqual(group3)).to.equal false

  it "should compare with non collections", ->
    group = new BaseCollection @probe
    expect(group.isEqual(1)).to.equal false
    expect(group.isEqual(null)).to.equal false
    expect(group.isEqual({})).to.equal false
    expect(group.isEqual([])).to.equal false

  it "should track changes", ->
    units = new BaseCollection()
    expect(units.add(@scv, @probe)).to.eql [@scv, @probe]
    expect(units.delete(@probe)).to.eql [@probe]
    expect(units.clear()).to.eql [@scv]

  it "should not track not changed elements", ->
    units = new BaseCollection()
    expect(units.add(@probe)).to.eql [@probe]
    expect(units.add(@scv, @probe)).to.eql [@scv]
    expect(units.delete(@probe)).to.eql [@probe]
    expect(units.delete(@probe)).to.eql []

  it "should convert to JSON", ->
    group = new BaseCollection @probe
    expect(JSON.parse(JSON.stringify(group))).to.eql [{id: 'probe', name: 'Probe'}]

  describe "Events", ->

    it "should emit add, delete and change events", ->
      group = new FullCollection()
      events = []
      group.on 'add',    (model) -> events.push 'add', model
      group.on 'delete', (model) -> events.push 'delete', model
      group.on 'change', (model) -> events.push 'change'
      group.add @probe
      group.add @probe
      group.add @scv
      group.delete @probe
      expect(events).to.eql [
        'add', @probe,
        'change',
        'add', @scv,
        'change',
        'delete', @probe,
        'change'
      ]

    it "should proxy model events", ->
      probe = new FullModel name: 'Probe', id: 'probe'
      group = new FullCollection()
      events = []
      group.on 'model:change', (model) -> events.push 'change', model
      group.add probe
      probe.set race: 'Protoss'
      expect(events).to.eql ['change', probe]

    it "should emit change on sort", ->
      group = new FullCollection @scv, @probe
      events = []
      group.on 'change', (model) -> events.push 'change'
      expect(group.sort(comparator: 'name')).to.eql true
      expect(events).to.eql ['change']

    it "should not emit change on sort if order not changed", ->
      group = new FullCollection @probe, @scv
      events = []
      group.on 'change', (model) -> events.push 'change'
      expect(group.sort(comparator: 'name')).to.eql false
      expect(events).to.eql []

  describe "Sorting", ->

    it "should sort and preserve order", ->
      group = new FullCollection()
      group.add @scv, @probe
      expect([group.at(0), group.at(1)]).to.eql [@scv, @probe]

      expect(group.sort(comparator: 'name')).to.eql true
      expect([group.at(0), group.at(1)]).to.eql [@probe, @scv]

      group = new FullCollection [], comparator: 'name'
      group.add @scv, @probe
      expect([group.at(0), group.at(1)]).to.eql [@probe, @scv]