chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'
index = require '../../../src/index'

index.setup()

exports.schema = (explorer, cb) ->
  validator.selfcheck explorer.schema, cb

exports.meta = (explorer, cb) ->
  for field in ['title', 'description', 'category', 'values']
    expect(explorer.meta, field).to.have.deep.property field
  for name, val of explorer.meta.values
    for field in ['title', 'description', 'type']
      expect(val, "values.#{name}").to.have.property field
  cb()

exports.validator = (explorer, values, cb) ->
  validator.check
    name: 'test'
    value: values
    schema: explorer.schema
  , (err, conf) ->
    expect(err, 'error').to.not.exist
    cb err, conf

exports.run = (explorer, config, cb) ->
  @validator explorer, config, (err, conf) ->
    explorer.run conf, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res, 'result').to.exist
      expect(res.date, 'date').to.exist
      expect(Object.keys(res.values).length).to.be.above 0
      cb null, res
