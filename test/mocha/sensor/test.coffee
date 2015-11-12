chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'
index = require '../../../src/index'

index.setup()

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

exports.ok = (sensor, config, cb) ->
  @validator sensor, config, (err, conf) ->
    sensor.run conf, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res.message, 'message').to.not.exist
      expect(res.status).to.equal 'ok'
      expect(res, 'result').to.exist
      expect(res.date, 'date').to.exist
      cb null, res

exports.warn = (sensor, config, cb) ->
  @validator sensor, config, (err, conf) ->
    sensor.run conf, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res.message, 'message').to.exist
      expect(res.status).to.equal 'warn'
      cb null, res

exports.fail = (sensor, config, cb) ->
  @validator sensor, config, (err, conf) ->
    sensor.run conf, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res.message, 'message').to.exist
      expect(res.status).to.equal 'fail'
      cb null, res

exports.analysis = (sensor, config, result, cb) ->
  @validator sensor, config, (err, conf) ->
    sensor.analysis conf, result, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res, 'analysis').to.exist
      cb null, res

exports.report = (sensor, config, result, cb) ->
  @validator sensor, config, (err, conf) ->
    base = require '../../../src/sensor'
    report = base.report
      sensor: sensor
      config: conf
      result: result
    expect(report, 'report').to.exist
    cb null, report
