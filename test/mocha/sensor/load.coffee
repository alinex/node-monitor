chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
load = require '../../../src/sensor/load'

describe "Load", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema load, cb

    it "should has meta data", (cb) ->
      test.meta load, cb

    it "should return success", (cb) ->
      test.ok load, {}, (err, res) ->
        store = res
        expect(res.values.short).to.be.above 0
        cb()

  describe "check", ->

    it "should give warn on short load", (cb) ->
      test.warn load,
        warn: 'short > 0.01'
      , (err, res) ->
        expect(res.values.short).to.be.above 0
        cb()

  describe "reporting", ->

    it "should get analysis data", (cb) ->
      @timeout 5000
      test.analysis load, {}, store, (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report load, {}, store, (err, report) ->
        console.log report
        cb()
