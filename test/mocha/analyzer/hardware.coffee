chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
hardware = require '../../../src/analyzer/hardware'

describe.skip "Hardware", ->
  @timeout 120000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema hardware, cb

    it "should has meta data", (cb) ->
      test.meta hardware, cb

    it "should return success", (cb) ->
#      test.run hardware,
#        remote: 'localhost'
#      , (err, res) ->
      test.run hardware, {}, (err, res) ->
        console.log res
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.warn hardware,
        warn: 'active > 0.01%'
      , (err, res) ->
        expect(res.values.active).to.be.above 0
        cb()

  describe "reporting", ->

    it "should get analysis data", (cb) ->
      @timeout 5000
      test.analysis hardware, {}, store, (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report hardware, {}, store, (err, report) ->
        console.log report
        cb()
