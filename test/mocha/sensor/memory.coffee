chai = require 'chai'
expect = chai.expect

validator = require 'alinex-validator'
test = require '../sensor'
Check = require '../../../src/check'

sensor = require '../../../src/sensor/memory'

before (cb) -> test.setup cb

describe "Memory sensor", ->

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

    it "should create new check", (cb) ->
      test.init
        sensor: 'memory'
      , (err, instance) ->
        check = instance
        cb()

    it "should return success", (cb) ->
      @timeout 20000
      test.ok check, (err) ->
        expect(check.values.used).to.be.above 0
        cb()

    it "should give warn", (cb) ->
      @timeout 20000
      test.init
        sensor: 'memory'
        config:
          warn: 'used > 0.01%'
      , (err, instance) ->
        test.warn instance, (err, res) ->
          expect(instance.values.used).to.be.above 0
          cb()

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
