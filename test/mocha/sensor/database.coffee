chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
database = require '../../../src/sensor/database'

describe "database", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema database, cb

    it "should has meta data", (cb) ->
      test.meta database, cb

    it "should return success", (cb) ->
      test.ok database,
        database: 'test-postgresql'
        query: "SELECT 100 as num, 'just a number' as comment"
      , (err, res) ->
        store = res
        expect(res.values.value).to.be.above 0
        cb()

  describe "check", ->

    it "should give warn", (cb) ->
      test.warn database,
        database: 'test-postgresql'
        query: "SELECT 100 as num, 'just a number' as comment"
        warn: 'value > 0'
      , (err, res) ->
        expect(res.values.value).to.be.above 0
        cb()

  describe "reporting", ->

    it "should make the report", (cb) ->
      test.report database,
        database: 'test-postgresql'
        query: "SELECT 100 as num, 'just a number' as comment"
      , store, (err, report) ->
        console.log report
        cb()
