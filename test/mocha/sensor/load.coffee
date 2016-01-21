chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

test = require '../sensor'
sensor = require '../../../src/sensor/load'

before (cb) -> test.setup cb

describe "Load sensor", ->

  check = null

  describe "definition", ->

    it "should has sensor instance loaded", (cb) ->
      expect(sensor, 'sensor instance').to.exist
      cb()

    it "should has correct validator rules", (cb) ->
      test.schema sensor, cb

    it "should has meta data", (cb) ->
      test.meta sensor, cb

    it "should has api methods", (cb) ->
      expect(test.init, 'init').to.exist
      expect(test.init, 'run').to.exist
      cb()

  describe "run", ->
    @timeout 20000

    it "should create new check", (cb) ->
      test.init
        sensor: 'load'
      , (err, instance) ->
        check = instance
        cb()

    it "should return success", (cb) ->
      test.ok check, ->
        expect(check.values.short).to.be.above 0
        cb()

    it "should give warn", (cb) ->
      test.init
        sensor: 'load'
        config:
          warn: 'short > 0.01'
      , (err, instance) ->
        test.warn instance, cb

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
