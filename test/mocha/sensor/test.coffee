chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

exports.schema = (sensor, cb) ->
  for field in ['keys.warn', 'keys.fail']
    expect(sensor.schema, field).to.have.deep.property field
  validator.selfcheck sensor.schema, cb

exports.meta = (sensor, cb) ->
  for field in ['title', 'description', 'category', 'values']
    expect(sensor.meta, field).to.have.deep.property field
  for name, val of sensor.meta.values
    for field in ['title', 'description', 'type']
      expect(val, "values.#{name}").to.have.property field
  cb()

exports.validator = (sensor, values, cb) ->
  validator.check
    name: 'test'
    value: values
    schema: sensor.schema
  , (err, conf) ->
    expect(err, 'error').to.not.exist
    cb err, conf

exports.run = (sensor, config, cb) ->
  @validator sensor, config, (err, conf) ->
    sensor.run conf, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res, 'result').to.exist
      cb null, res

exports.analysis = (sensor, config, cb) ->
  @validator sensor, config, (err, conf) ->
    sensor.analysis conf, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res, 'analysis').to.exist
      cb null, res

exports.report = (sensor, config, result, cb) ->
  @validator sensor, config, (err, conf) ->
    base = require '../../../src/sensor'
    report = base.report
      name: 'test'
      sensor: sensor
      config: conf
      result: result
    expect(report, 'report').to.exist
    cb null, report
