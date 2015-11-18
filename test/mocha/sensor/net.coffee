chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
net = require '../../../src/sensor/net'

describe "Net", ->
  @timeout 20000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema net, cb

    it "should has meta data", (cb) ->
      test.meta net, cb

    it "should return success", (cb) ->
      test.ok net, {}, (err, res) ->
        store = res
        cb()

  describe "check", ->

    it "should give warn on bytes", (cb) ->
      test.warn net,
        warn: 'bytes >= 0'
      , (err, res) ->
        cb()

  describe "reporting", ->

    it "should get analysis data", (cb) ->
      @timeout 5000
      test.analysis net, {}, store, (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report net, {}, store, (err, report) ->
        console.log report
        cb()
