# require './helper'
# _    = require 'underscore'
# rest = require '../rest-lite'
#
# # Stub for Model.
# Model = class Model
#   isModel: true
#
#   constructor: (attrs) ->
#     @errors = {}
#     @attrs = attrs || {}
#   getId: -> @attrs.id
#   setId: (id) -> @attrs.id = id
#   toRest: -> @attrs
#   fromRest: (hash) ->
#     _(@attrs).extend hash
#     @
#   @fromRest: (hash) -> new Model hash
#
# rest.fromRest = (doc, resource) ->
#     resource.options.class?.fromRest(doc) || doc
#
# class Unit extends Model
#
# describe "Model Integration", ->
#   beforeEach ->
#     @service = rest.service 'service.com'
#     @units   = @service.resource 'units', class: Model
#
#   it "should get one", (done) ->
#     @service.stub 'get', '/units/probe', (err, data, options, callback) ->
#       expect(data).to.eql {profile: 'short'}
#       callback null, {id: 'probe', name: 'Probe'}
#
#     @units.get 'probe', {profile: 'short'}, (err, unit) ->
#       expect(unit.isModel).to.be true
#       expect(unit.attrs.name).to.be 'Probe'
#       done()
#
#   it 'should get collection', (done) ->
#     @service.stub 'get', '/units', (err, data, options, callback) ->
#       expect(data).to.eql {page: 1}
#       callback null, [{id: 'probe', name: 'Probe'}]
#
#     @units.get {page: 1}, (err, collection) ->
#       unit = collection[0]
#       expect(unit.isModel).to.be true
#       expect(unit.attrs.name).to.be 'Probe'
#       done()
#
#   it "should create", (done) ->
#     @service.stub 'post', '/units', (err, data, options, callback) ->
#       expect(data).to.eql name: 'Probe'
#       callback null, {id: 'probe'}
#
#     unit = new Unit name: 'Probe'
#     @units.create unit, (err, data) ->
#       expect(unit.getId()).to.be.a 'string'
#       done()
#
#   it "should update", (done) ->
#     @service.stub 'put', '/units/probe', (err, data, options, callback) ->
#       expect(data).to.eql id: 'probe', name: 'Probe'
#       callback null, {}
#
#     unit = new Unit id: 'probe', name: 'Probe'
#     @units.update unit, (err, data) ->
#       expect(data).to.eql unit
#       done()
#
#   it "should delete", (done) ->
#     @service.stub 'delete', '/units/probe', (err, data, options, callback) ->
#       expect(data).to.eql {}
#       callback null, {result: 'ok'}
#
#     unit = new Unit id: 'probe', name: 'Probe'
#     @units.delete unit, (err, data) ->
#       expect(data).to.eql {result: 'ok'}
#       done()
#
#   it "should return raw hash if specified", (done) ->
#     @service.stub 'get', '/units/probe', (err, data, options, callback) ->
#       callback null, {id: 'probe', name: 'Probe'}
#
#     @units.get 'probe', {}, {raw: true}, (err, unit) ->
#       expect(unit.isModel).to.be undefined
#       expect(unit.name).to.be 'Probe'
#       done()