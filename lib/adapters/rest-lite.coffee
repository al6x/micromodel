# 
# fromRest : Conversion.prototype.fromHash
# toRest   : -> @toHash errors: false, class: false
# 
# 
# 
# fromRest  : (doc, resource) ->
#   className = resource.options.class || doc.class
#   if className
#     klass = Conversion.getClass className
#     Conversion.fromHash doc, klass
#   else
#     doc





# Override this to provide other unmarshalling behavior.
# You can use information in doc itself (like `_class` attribute) or
# information in `resource` (like `resource.options.class`) to infer
# document class, or just return raw document.
fromRest: (doc, resource) -> doc

# Cleaning special options.
delete options.raw


create: (obj, options..., callback) ->
  doc = if obj.isModel then obj.toRest() else obj
  unless err
    data = obj.fromRest data if obj.isModel and options.raw != true
    setId obj, getId(data)
    
    
update: (args..., callback) ->
  throw new Error "callback required!" unless callback
  [first, second, third] = args
  if first.isModel
    [id, obj, options] = [getId(first), first, second]
  else
    [id, obj, options] = [first, second, third]
  throw new Error "can't update without id!" unless id
  options ?= {}

  doc = if obj.isModel then obj.toRest() else obj
  @call 'put', id, '', doc, options, (err, data) =>
    data = obj.fromRest data if !err and obj.isModel and options.raw != true
    callback err, data



delete: (first, args..., callback) ->
  throw new Error "callback required!" unless callback
  id = if first.isModel then getId(first) else first
  throw new Error "can't delete without id!" unless id
  [data, options] = args
  @call 'delete', id, '', data, options, callback

  

save: (obj, options..., callback) ->
  method = if getId(obj) then 'update' else 'create'
  @[method] obj. options..., callback