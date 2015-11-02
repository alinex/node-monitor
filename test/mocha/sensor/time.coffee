chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
time = require '../../../src/sensor/time'

describe.only "Time", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema time, cb

    it "should has meta data", (cb) ->
      test.meta time, cb

    it "should return success", (cb) ->
      test.run time, {}, (err, res) ->
        store = res
        expect(res.values.local).to.be.above 0
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.run time,
        warn: 'diff < 1000'
      , (err, res) ->
        expect(res.values.local).to.be.above 0
        expect(res.status).to.be.equal 'warn'
        cb()

  describe "reporting", ->

    it "should make the report", (cb) ->
      test.report time, {}, store, (err, report) ->
        console.log report
        cb()
