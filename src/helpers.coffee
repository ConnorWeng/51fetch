exports.merge = (options, overrides) ->
  extend (extend {}, options), overrides

extend = exports.extend = (object, properties) ->
  object[key] = val for key, val of properties
  object
