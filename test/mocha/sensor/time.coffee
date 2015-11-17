chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
time = require '../../../src/sensor/time'

describe "Time", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema time, cb

    it "should has meta data", (cb) ->
      test.meta time, cb

    it "should return success", (cb) ->
      test.ok time, {}, (err, res) ->
        store = res
        expect(res.values.local).to.be.above 0
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.warn time,
        warn: 'diff < 100000'
      , (err, res) ->
        expect(res.values.local).to.be.above 0
        cb()

  describe "reporting", ->

    it "should make the report", (cb) ->
      test.report time, {}, store, (err, report) ->
        console.log report
        cb()