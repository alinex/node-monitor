chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'
index = require '../../src/index'
Check = require '../../src/check'

exports.setup = (cb) ->
  index.initPlugins cb

# check some general things

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

# check run

exports.init = (setup, cb) ->
  check = new Check setup
  check.init.call check, (err) ->
    expect(err, 'error').to.not.exist
    expect(check.sensor, 'sensor instance').to.exist
    expect(check.name, 'name initialized').to.exist
    cb err, check

exports.run = (check, cb) ->
  check.run (err) ->
    expect(err, 'error').to.not.exist
    expect(check.result, 'result').to.exist
    cb()

exports.ok = (check, cb) ->
  check.run (err, status) ->
    expect(err, 'error').to.not.exist
    expect(status 'status').to.equal 'ok'
    expect(check.status, 'stored status').to.equal 'ok'
    expect(check.values, 'values').to.exist
    expect(check.date, 'date').to.exist
    cb err, status

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

exports.noanalysis = (sensor, config, result, cb) ->
  @validator sensor, config, (err, conf) ->
    sensor.analysis conf, result, (err, res) ->
      expect(err, 'error').to.not.exist
      expect(res, 'analysis').to.not.exist
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
