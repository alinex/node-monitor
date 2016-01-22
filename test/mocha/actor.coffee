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
  action = new Action 'test', setup
  #console.log action
  expect(action.name, 'name initialized').to.exist
  expect(action.type, 'actor instance').to.exist
  cb null, action

  exports.run = (action, cb) ->
  action.run (err) ->
    console.log 'actor end', err

    expect(action.date, 'date').to.exist
    expect(err, 'error').to.not.exist
    expect(action.err, 'error').to.not.exist
    expect(action.values, 'values').to.exist
    cb err, status
