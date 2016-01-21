chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

debugReport = require('debug')('test:report')
validator = require 'alinex-validator'
index = require '../../src/index'
Action = require '../../src/action'

exports.setup = (cb) ->
  index.initPlugins cb

# action some general things

exports.schema = (actor, cb) ->
  validator.selfcheck actor.schema, cb

exports.meta = (actor, cb) ->
  for field in ['title', 'description', 'values']
    expect(actor.meta, field).to.have.deep.property field
  for name, val of actor.meta.values
    for field in ['title', 'description', 'type']
      expect(val, "values.#{name}").to.have.property field
  cb()

# action run

exports.init = (setup, cb) ->
  action = new Action setup
  action.init.call action, (err) ->
    expect(err, 'error').to.not.exist
    expect(action.actor, 'actor instance').to.exist
    expect(action.name, 'name initialized').to.exist
    cb err, action

exports.ok = (action, cb) ->
  action.run (err, status) ->
    expect(status, 'status').to.equal 'ok'
    expect(action.status, 'stored status').to.equal 'ok'
    expect(action.date, 'date').to.exist
    expect(err, 'error').to.not.exist
    expect(action.err, 'error').to.not.exist
    expect(action.values, 'values').to.exist
    cb err, status

exports.warn = (action, cb) ->
  action.run (err, status) ->
    expect(status, 'status').to.equal 'warn'
    expect(action.status, 'stored status').to.equal 'warn'
    expect(action.date, 'date').to.exist
    expect(err, 'error').to.not.exist
    expect(action.err, 'error').to.exist
    cb null, status

exports.fail = (action, cb) ->
  action.run (err, status) ->
    expect(status, 'status').to.equal 'fail'
    expect(action.status, 'stored status').to.equal 'fail'
    expect(action.date, 'date').to.exist
    expect(err, 'error').to.not.exist
    expect(action.err, 'error').to.exist
    cb null, status

exports.values = (action, cb) ->
  for name of action.values
    expect(action.actor.meta.values[name], "value #{name}").to.exist
  cb()

exports.report = (action, cb) ->
  report = action.report()
  debugReport report.toString()
  expect(report, 'report').to.exist
  cb()
