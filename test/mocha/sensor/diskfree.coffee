chai = require 'chai'
expect = chai.expect

validator = require 'alinex-validator'
test = require '../sensor'
Check = require '../../../src/check'

sensor = require '../../../src/sensor/diskfree'

before (cb) -> test.setup cb

describe.only "Diskfree sensor", ->

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
        sensor: 'diskfree'
        config:
          share: '/'
      , (err, instance) ->
        check = instance
        cb()

    it "should return success", (cb) ->
      @timeout 20000
      test.ok check, (err) ->
        expect(check.values.total).to.be.above 0
        expect(check.values.used).to.be.above 0
        expect(check.values.free).to.be.above 0
        cb()

    it "should work with binary values", (cb) ->
      @timeout 20000
      test.init
        sensor: 'diskfree'
        config:
          share: '/'
          warn: 'free < 1GB'
      , (err, instance) ->
        test.ok instance, (err, res) ->
          expect(check.values.total).to.be.above 0
          expect(check.values.used).to.be.above 0
          expect(check.values.free).to.be.above 0
          cb()

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
