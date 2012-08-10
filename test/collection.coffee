global.p         = (args...) -> console.log args...

expect           = require('chai').expect
MicroModel       = require '../micromodel'
Model            = MicroModel.Model
withModel        = MicroModel.withModel
Collection       = MicroModel.Collection
withCollection   = MicroModel.withCollection
withEventEmitter = MicroModel.withEventEmitter
_                = require 'underscore'
Class            = MicroModel.Class

describe "Collection", ->
  beforeEach ->
    @Unit  = Class 'Unit', withModel, withEventEmitter
    @probe = new @Unit name: 'Probe', id: 'probe'
    @scv   = new @Unit name: 'SCV'

  it "should add, delete and get by id, cid and index", ->
    units = new Collection @probe
    expect(units).to.have.length 1
    units.add @scv
    expect(units).to.have.length 2

    expect(units.at(0)).to.eql @probe
    expect(units.at(1)).to.eql @scv
    expect(units.get(@probe.id)).to.eql @probe
    expect(units.get(@probe._cid)).to.eql @probe
    expect(units.get(@scv._cid)).to.eql @scv

    units.delete @probe
    units.delete @probe
    expect(units).to.have.length 1
    units.delete @scv
    expect(units).to.have.length 0

  it "should not add twice", ->
    units = new Collection @probe, @probe
    units.add @probe
    expect(units).to.have.length 1

  it "should check for equality", ->
    group1 = new Collection @probe
    group2 = new Collection @probe
    group3 = new Collection @scv
    expect(group1.eql(group2)).to.equal true
    expect(group1.eql(group3)).to.equal false

  it "should compare with non collections", ->
    group = new Collection @probe
    expect(group.eql(1)).to.equal false
    expect(group.eql(null)).to.equal false
    expect(group.eql({})).to.equal false
    expect(group.eql([])).to.equal false

  it "should emit add, delete and change events", ->
    Units = Class 'Units', withCollection, withEventEmitter
    group = new Units()
    events = []
    group.on 'add',    (model) -> events.push "add #{model.name}"
    group.on 'delete', (model) -> events.push "delete #{model.name}"
    group.on 'change', (model) -> events.push 'change'
    group.add @probe
    group.add @probe
    group.add @scv
    group.delete @probe
    expect(events).to.eql ['add Probe', 'change', 'add SCV', 'change', 'delete Probe', 'change']

  it "should proxy model events", ->
    Units = Class 'Units', withCollection, withEventEmitter
    group = new Units()
    events = []
    group.addListener 'model:change', (model) -> events.push "change #{model.name}"
    group.add @probe
    @probe.set race: 'Protoss'
    expect(events).to.eql ['change Probe']

  it "should convert to JSON", ->
    group = new Collection @probe
    expect(JSON.parse(JSON.stringify(group))).to.eql [{id: 'probe', name: 'Probe'}]

  it "should sort and preserve order"