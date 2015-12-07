chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'
debugReport = require('debug')('test:report')

test = require '../sensor'
Check = require '../../../src/check'
sensor = require '../../../src/sensor/cpu'

before (cb) -> test.setup cb

describe.only "CPU", ->
  @timeout 15000

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
        sensor: 'cpu'
      , (err, instance) ->
        check = instance
        cb()

    it "should return success", (cb) ->
      test.ok check, (err) ->
        expect(check.values.active).to.be.above 0
        cb()




    it "should give warn on active", (cb) ->
      test.warn cpu,
        warn: 'active > 0.01%'
      , (err, res) ->
        expect(res.values.active).to.be.above 0
        cb()

  describe "reporting", ->

    it "should get empty analysis data", (cb) ->
      @timeout 5000
      test.analysis cpu,
        analysis:
          numProc: 5
      , store, (err, report) ->
        store.analysis = report
        cb()

    it "should make the report", (cb) ->
      test.report cpu, {}, store, (err, report) ->
        debugReport "complete report", report
        cb()
