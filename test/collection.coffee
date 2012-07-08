global.p      = (args...) -> console.log args...

expect        = require('chai').expect
PassiveModel  = require '../passive-model'
Model         = PassiveModel.Model
Collection    = PassiveModel.Collection
EventEmitter  = require('events').EventEmitter
_             = require 'underscore'

describe "Collection", ->
  beforeEach ->
    PassiveModel.dontUseEvents()

    class @Unit extends Model
    @probe = new @Unit id: 'probe', name: 'Probe'
    @scv = new @Unit name: 'SCV'

  it "should add, delete and get by id, cid and index", ->
    class Units extends Collection
    units = new Units @probe
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
    class Units extends Collection
    units = new Units @probe, @probe
    units.add @probe
    expect(units).to.have.length 1

  it "should check for equality", ->
    class Units extends Model
    group1 = new Units @probe
    group2 = new Units @probe
    group3 = new Units @scv
    expect(group1.eql(group2)).to.equal true
    expect(group1.eql(group3)).to.equal false

  it "should compare with non collections", ->
    class Units extends Model
    group = new Units @probe
    expect(group.eql(1)).to.equal false
    expect(group.eql(null)).to.equal false
    expect(group.eql({})).to.equal false
    expect(group.eql([])).to.equal false

  it "should emit add, delete and change events", ->
    PassiveModel.useEventEmitter EventEmitter

    class Units extends Collection
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
    PassiveModel.useEventEmitter EventEmitter

    class Units extends Collection
    group = new Units()
    events = []
    group.on 'model:change', (model) -> events.push "change #{model.name}"
    group.add @probe
    @probe.set race: 'Protoss'
    expect(events).to.eql ['change Probe']

  it "should convert to JSON", ->
    class Units extends Collection
    group = new Units @probe
    expect(JSON.parse(JSON.stringify(group))).to.eql [{id: 'probe', name: 'Probe'}]

  it "should sort and preserve order"