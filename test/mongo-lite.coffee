require './helper'
require '../lib/adapters/mongo-lite'

# Stubbing Model.
Model = require '../lib/passive-model'
Model.fromMongo = (doc, collection) ->
  if doc.class == 'Model' then new Model(doc) else doc
    
# Stubbing mongo.
mongo = require 'mongo-lite'
mongo.logger = null

# Enabling custom mongo options.
mongo.useHandyButNotStandardDefaults()

# Enabling support for synchronized mode and specs.
sync = require 'synchronize'
require 'mongo-lite/lib/synchronize'
sync.it = (desc, callback) ->
  it desc, (done) ->
    sync.fiber callback.bind(@), done
    
describe "Integration with Model", ->
  beforeEach (next) ->
    @db = mongo.db('test')
    @db.clear next

  describe "Collection", ->
    sync.it "should create", ->
      units = @db.collection 'units'
      unit = new Model name: 'Probe',  status: 'alive'
      expect(units.create(unit)).to.be true
      expect(unit.id).to.be.a 'string'
      expect(units.first(name: 'Probe').status).to.eql 'alive'

    sync.it "should update", ->
      units = @db.collection 'units'
      unit = new Model name: 'Probe',  status: 'alive'
      units.create(unit)
      expect(units.first(name: 'Probe').status).to.be 'alive'
      unit.status = 'dead'
      units.update(unit)
      expect(units.first(name: 'Probe').status).to.be 'dead'
      expect(units.count()).to.be 1
  
    sync.it "should delete", ->
      units = @db.collection 'units'
      unit = new Model name: 'Probe',  status: 'alive'
      units.create unit
      expect(units.delete(unit)).to.be true
      expect(units.count(name: 'Probe')).to.be 0
  
    sync.it "should use short string id (instead of BSON::ObjectId as default in mongo)", ->
      units = @db.collection 'units'
      unit = new Model name: 'Probe',  status: 'alive'
      units.create unit
      expect(unit.id).to.be.a 'string'
  
    sync.it "should return raw hash if specified", ->
      units = @db.collection 'units'
      unit = new Model name: 'Probe'
      units.save unit
      expect(units.first({}, doc: true)).to.eql unit.toMongo()
  
    sync.it "should intercept unique index errors", ->
      units = @db.collection 'units'
      unit = new Model name: 'Probe',  status: 'alive'
      expect(units.create(unit)).to.be true
      expect(unit.id).to.be.a 'string'
      expect(units.create(unit)).to.be false
      expect(unit.errors.base).to.eql ['not unique']
  
  describe "Cursor", ->
    sync.it "should return first element", ->
      units = @db.collection 'units'
      expect(units.first()).to.be null
      units.save(new Model(name: 'Zeratul'))
      expect(units.first(name: 'Zeratul').name).to.be 'Zeratul'
  
    sync.it 'should return all elements', ->
      units = @db.collection 'units'
      expect(units.all()).to.eql []
      units.save(new Model(name: 'Zeratul'))
      list = units.all(name: 'Zeratul')
      expect(list).to.have.length 1
      expect(list[0].name).to.be 'Zeratul'