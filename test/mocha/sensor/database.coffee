chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require '../sensor'
Check = require '../../../src/check'
sensor = require '../../../src/sensor/database'

before (cb) -> test.setup cb

describe.only "Database sensor", ->

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
        sensor: 'database'
        config:
          database: 'test-postgresql'
          query: "SELECT 100 as num, 'just a number' as comment"
      , (err, instance) ->
        check = instance
        cb()

    it "should return success", (cb) ->
      @timeout 20000
      test.ok check, (err) ->
        expect(check.values.data.num).to.be.equal 100
        cb()

    it "should give warn", (cb) ->
      @timeout 20000
      test.init
        sensor: 'database'
        config:
          database: 'test-postgresql'
          query: "SELECT 100 as num, 'just a number' as comment"
          warn: 'data.num > 0'
      , (err, instance) ->
        test.warn instance, (err, res) ->
          expect(instance.values.data.num).to.be.above 0
          cb()

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
