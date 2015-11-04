chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
user = require '../../../src/sensor/user'

describe "User", ->

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema user, cb

    it "should has meta data", (cb) ->
      test.meta user, cb

    it "should return success", (cb) ->
      @timeout 10000
      test.run user,
        user: 'alex'
      , (err, res) ->
        store = res
        cb()

  describe "reporting", ->

    it "should make an analysis report", (cb) ->
      test.analysis user,
        user: 'alex'
        analysis:
          numProc: 5
      , (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report user,
        user: 'alex'
        analysis:
          numProc: 5
      , store, (err, report) ->
        console.log report
        cb()
