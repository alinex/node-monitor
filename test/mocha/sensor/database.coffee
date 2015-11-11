chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
database = require '../../../src/sensor/database'

describe.only "database", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema database, cb

    it "should has meta data", (cb) ->
      test.meta database, cb

    it "should return success", (cb) ->
      test.ok database, {}, (err, res) ->
        store = res
        expect(res.values.local).to.be.above 0
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.warn database,
        warn: 'diff < 100000'
      , (err, res) ->
        expect(res.values.local).to.be.above 0
        cb()

  describe "reporting", ->

    it "should make the report", (cb) ->
      test.report database, {}, store, (err, report) ->
        console.log report
        cb()
