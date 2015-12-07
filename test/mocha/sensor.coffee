chai = require 'chai'
expect = chai.expect
debugReport = require('debug')('test:report')

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

exports.ok = (check, cb) ->
  check.run (err, status) ->
    expect(status, 'status').to.equal 'ok'
    expect(check.status, 'stored status').to.equal 'ok'
    expect(check.date, 'date').to.exist
    expect(err, 'error').to.not.exist
    expect(check.err, 'error').to.not.exist
    expect(check.values, 'values').to.exist
    cb err, status

exports.warn = (check, cb) ->
  check.run (err, status) ->
    expect(status, 'status').to.equal 'warn'
    expect(check.status, 'stored status').to.equal 'warn'
    expect(check.date, 'date').to.exist
    expect(err, 'error').to.exist
    expect(check.err, 'error').to.exist
    cb err, status

exports.fail = (check, cb) ->
  check.run (err, status) ->
    expect(status, 'status').to.equal 'fail'
    expect(check.status, 'stored status').to.equal 'fail'
    expect(check.date, 'date').to.exist
    expect(err, 'error').to.exist
    expect(check.err, 'error').to.exist
    cb err, status

exports.values = (check, cb) ->
  for name, val of check.values
    expect(check.sensor.meta.values[name], "value #{name}").to.exist
  cb()

exports.report = (check, cb) ->
  check.report (err, report) ->
    expect(err, 'error').to.not.exist
    expect(report, 'report').to.exist
    cb()
