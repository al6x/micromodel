var assert     = require('assert')
var MicroModel = require('micromodel')

// # Basic usage, creating simple model.
var Model = MicroModel.Model

var unit = new Model({name: 'Probe'})
assert.equal(unit.name, 'Probe')
unit.set({name: 'SCV'})
assert.equal(unit.name, 'SCV')

// # Defining custom classes.
//
// MicroModel uses very simple class model called Functional Mixins,
// see http://bit.ly/functional-mixins for details.
var Class            = MicroModel.Class
var withModel        = MicroModel.withModel
var withEventEmitter = MicroModel.withEventEmitter

// Defining `Unit` class and adding `withModel` and `withEventEmitter` modules to it.
var Unit = Class('Unit', withModel, withEventEmitter, {
  // Adding some custom methods.
  isAlive: function(){return this.life > 0}
})

var unit = new Unit({name: 'Probe', life: 80})
assert.equal(unit.name, 'Probe')
assert.equal(unit.isAlive(), true)

// Listening to events.
var events = []
unit.addListener('change', function(model){events.push('changed')})
unit.set({life: 0})
assert.deepEqual(events, ['changed'])