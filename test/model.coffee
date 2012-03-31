require './helper'

describe "Model", ->
  it "should check for equality based on model attributes", ->
    class Unit extends Model
    class Item extends Model

    unit1 = new Unit name: 'Zeratul'
    unit1.items = [new Item(name: 'Psionic blade')]

    unit2 = new Unit name: 'Zeratul'
    unit2.items = [new Item(name: 'Psionic blade')]

    expect(unit1.eq(unit2)).to.be true

    unit1.items[0].name = 'Power suit'
    expect(unit1.eq(unit2)).to.be false

  it "should compare with non models", ->
    class Unit extends Model

    unit = new Unit()
    expect(unit.eq(1)).to.be false
    expect(unit.eq(null)).to.be false

  it "should update attributes", ->
    class Tmp.User extends Model

    u = new Tmp.User()
    u.set name: 'Alex', hasMail: 'true', age: '31', banned: 'false'
    expect([u.name, u.hasMail, u.age, u.banned]).to.eql ['Alex', 'true', '31', 'false']

  it "should provide helper for adding errors", ->
    class Unit extends Model

    unit = new Unit()
    unit.errors.add name: "can't be blank"
    expect(unit.errors).to.eql {name: ["can't be blank"]}
    unit.errors.clear()
    expect(unit.errors).to.eql {}