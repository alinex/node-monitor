chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
cpu = require '../../../src/sensor/cpu'

describe.only "CPU", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema cpu, cb

    it "should has meta data", (cb) ->
      test.meta cpu, cb

    it "should return success", (cb) ->
      test.run cpu, {}, (err, res) ->
        store = res
        expect(res.values.active).to.be.above 0
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.run cpu,
        warn: 'active > 0.01%'
      , (err, res) ->
        expect(res.values.active).to.be.above 0
        expect(res.status).to.be.equal 'warn'
        cb()

  describe "reporting", ->

    it "should get analysis data", (cb) ->
      @timeout 5000
      test.analysis cpu,
        analysis:
          procNum: 5
      , (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report cpu,
        analysis:
          procNum: 5
      , store, (err, report) ->
        console.log report
        cb()
