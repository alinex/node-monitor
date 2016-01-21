chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

test = require '../sensor'
sensor = require '../../../src/sensor/time'

before (cb) -> test.setup cb

describe "Time sensor", ->

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
        sensor: 'time'
      , (err, instance) ->
        check = instance
        cb()

    it "should return success", (cb) ->
      @timeout 20000
      test.ok check, ->
        expect(check.values.local).to.be.above 0
        cb()

    it "should give warn on active", (cb) ->
      @timeout 20000
      test.init
        sensor: 'time'
        config:
          warn: 'diff < 100000'
      , (err, instance) ->
        test.warn instance, ->
          expect(instance.values.local).to.be.above 0
          cb()

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
