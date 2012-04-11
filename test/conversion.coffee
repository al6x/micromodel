require './helper'
Model = require '../passive-model'
_     = require 'underscore'

# Adding conversion mixin to Model.
class CModel extends Model
_(CModel).extend Model.Conversion
_(CModel.prototype).extend Model.Conversion.prototype

describe 'Attribute Conversion', ->
  it "should update only typed attribytes", ->
    class Tmp.User extends CModel
      @cast
        name    : String
        hasMail : Boolean
        age     : Number

    u = new Tmp.User()
    u.set {name: 'Alex', hasMail: 'true', age: '31'}, cast: true
    expect([u.name, u.hasMail, u.age]).to.eql ['Alex', true, 31]

    # Should skip attributes if type not specified.
    u.set {unknown: false}, cast: true
    expect(u.unknown).to.be undefined

  it "should inherit attribute types", ->
    class Tmp.User extends CModel
      @cast age: Number

    class Tmp.Writer extends Tmp.User
      @cast posts: Number

    u = new Tmp.Writer()
    u.set {age: '20', posts: '12'}, cast: true
    expect([u.age, u.posts]).to.eql [20, 12]

  it 'should parse string values', ->
    cases = [
      [Boolean, 'true',       true]
      [Number,  '12',         12]
      [String,  'Hi',         'Hi']
    ]
    for cse in cases
      [type, raw, expected] = cse
      expect(CModel._cast(raw, type)).to.eql expected

    expect(CModel._cast('2011-08-23', Date)).to.eql (new Date('2011-08-23'))

describe "Model Conversion", ->
  it "should convert object to and from hash & array", ->
    class Tmp.Post extends CModel
      @children 'tags', 'comments'

    class Tmp.Comment extends CModel

    # Should aslo allow to use models that
    # are saved to array.
    # To do so we need to use toArray and afterFromHash.
    class Tmp.Tags extends CModel
      constructor: -> @array = []
      push: (args...) -> @array.push args...
      toArray: -> @array
    Tmp.Post.afterFromHash = (obj, hash) ->
      obj.tags = new Tmp.Tags
      obj.tags.array = hash.tags

    # Creating some data.
    comment = new Tmp.Comment()
    comment.text = 'Some text'

    tags = new Tmp.Tags()
    tags.push 'a', 'b'

    post = new Tmp.Post()
    post.title = 'Some title'
    post.comments = [comment]
    post.tags = tags

    hash = {
      _class   : 'Post',
      title    : 'Some title',
      comments : [{text: 'Some text', _class: 'Comment'}],
      tags     : ['a', 'b']
    }

    # Converting to Hash.
    expect(post.toHash(errors: false, class: true)).to.eql hash

    [post.id, hash.id] = ['some id', 'some id']
    expect(post.toHash(errors: false, class: true)).to.eql hash

    # Converting from Hash.
    expect(CModel.fromHash(hash).toHash(errors: false, class: true)).to.eql hash

  it "should update model from hash", ->
    class Tmp.Post extends CModel

    post = new Tmp.Post title: 'Some title'
    post.fromHash title: 'Another title'
    expect(post.title).to.be 'Another title'

  # it "chldren should have `_parent` reference to the main object", ->
  #   class Tmp.Unit extends CModel
  #     @children 'items'
  #   class Tmp.Item extends CModel
  #
  #   unit = new Tmp.Unit()
  #   unit.items = [
  #     new Tmp.Item(name: 'Psionic blade')
  #     new Tmp.Item(name: 'Plasma shield')
  #   ]
  #
  #   hash = unit.toHash()
  #   unit = CModel.fromHash(hash)
  #   expect(unit._parent).to.be undefined
  #   expect(unit.items[0]._parent).to.eql unit