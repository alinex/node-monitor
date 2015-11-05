chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
ping = require '../../../src/sensor/ping'

describe.only "Ping", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema ping, cb

    it "should has meta data", (cb) ->
      test.meta ping, cb

    it "should return success", (cb) ->
      test.run ping,
        host: '193.99.144.80'
      , (err, res) ->
        store = res
        expect(res.values.responseTime).to.exist
        cb()

    it "should succeed with domain name", (cb) ->
      test.run ping,
        host: 'heise.de'
      , (err, res) ->
        cb()

    it "should send multiple packets", (cb) ->
      @timeout 15000
      test.run ping,
        host: '193.99.144.80'
        count: 10
      , (err, res) ->
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.run ping,
        host: '193.99.144.80'
        warn: 'responseTime > 1'
      , (err, res) ->
        expect(res.status).to.be.equal 'warn'
        cb()

    it "should return fail", (cb) ->
      test.run ping,
        host: '137.168.111.222'
      , (err, res) ->
        expect(res.status).to.be.equal 'fail'
        cb()

  describe "reporting", ->

    it "should make the report", (cb) ->
      test.report ping,
        host: '193.99.144.80'
      , store, (err, report) ->
        console.log report
        cb()
