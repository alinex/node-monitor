chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
socket = require '../../../src/sensor/socket'

describe.only "Socket", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema socket, cb

    it "should has meta data", (cb) ->
      test.meta socket, cb

    it "should return success", (cb) ->
      test.run socket,
        host: '193.99.144.80'
        port: 80
      , (err, res) ->
        store = res
        expect(res.values.responseTime).to.exist
        cb()

    it "should succeed with domain name", (cb) ->
      test.run socket,
        host: 'heise.de'
        port: 80
      , (err, res) ->
        cb()

  describe "check", ->

    it "should fail to connect to wrong port", (cb) ->
      test.run socket,
        host: '193.99.144.80'
        port: 1298
      , (err, res) ->
        expect(res.status).to.be.equal 'fail'
        cb()

    it "should fail to connect to wrong host", (cb) ->
      test.run socket,
        host: 'unknownsubdomain.nonexisting.host'
        port: 80
      , (err, res) ->
        expect(res.status).to.be.equal 'fail'
        cb()

  describe "reporting", ->

    it "should make the report", (cb) ->
      test.report socket,
        host: '193.99.144.80'
        port: 80
      , store, (err, report) ->
        console.log report
        cb()
