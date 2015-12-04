chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'
debug = require('debug')('test:report')

test = require './test'
cpu = require '../../../src/sensor/cpu'

describe.only "CPU", ->
  @timeout 15000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema cpu, cb

    it "should has meta data", (cb) ->
      test.meta cpu, cb

    it "should return success", (cb) ->
      test.ok cpu, {}, (err, res) ->
        store = res
        expect(res.values.active).to.be.above 0
        cb()

  describe "check", ->

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
        debug "complete report", report
        cb()
