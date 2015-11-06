chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
memory = require '../../../src/sensor/memory'

describe "Memory", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema memory, cb

    it "should has meta data", (cb) ->
      test.meta memory, cb

    it "should return success", (cb) ->
      test.ok memory, {}, (err, res) ->
        store = res
        expect(res.values.used).to.be.above 0
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.warn memory,
        warn: 'used > 0.01%'
      , (err, res) ->
        expect(res.values.used).to.be.above 0
        cb()

  describe "reporting", ->

    it "should get analysis data", (cb) ->
      @timeout 5000
      test.analysis memory, {}, store, (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report memory, {}, store, (err, report) ->
        console.log report
        cb()
