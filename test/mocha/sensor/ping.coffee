chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

test = require '../sensor'
sensor = require '../../../src/sensor/ping'

before (cb) -> test.setup cb

describe "Ping sensor", ->

  check = null

  describe "definition", ->

    it "should has sensor instance loaded", (cb) ->
      expect(sensor, 'sensor instance').to.exist
      cb()

    it "should has correct validator rules", (cb) ->
      test.schema sensor, cb

    it "should has meta data", (cb) ->
      test.meta sensor, cb

    it "should has api methods", (cb) ->
      expect(test.init, 'init').to.exist
      expect(test.init, 'run').to.exist
      cb()

  describe "run", ->

    it "should create new check", (cb) ->
      test.init
        sensor: 'ping'
        config:
          host: '193.99.144.80'
      , (err, instance) ->
        check = instance
        cb()

    it "should return success", (cb) ->
      @timeout 20000
      test.ok check, ->
        expect(check.values.responseTime).to.exist
        cb()

    it "should succeed with domain name", (cb) ->
      @timeout 20000
      test.init
        sensor: 'ping'
        config:
          host: 'heise.de'
      , (err, instance) ->
        test.ok instance, ->
          expect(instance.values.responseTime).to.exist
          cb()

    it "should send multiple packets", (cb) ->
      @timeout 20000
      test.init
        sensor: 'ping'
        config:
          host: '193.99.144.80'
          count: 10
      , (err, instance) ->
        test.ok instance, ->
          expect(instance.values.responseTime).to.exist
          cb()

    it "should give warn on active", (cb) ->
      @timeout 20000
      test.init
        sensor: 'ping'
        config:
          host: '193.99.144.80'
          warn: 'responseTime > 1'
      , (err, instance) ->
        test.warn instance, cb

    it "should return fail", (cb) ->
      @timeout 20000
      test.init
        sensor: 'ping'
        config:
          host: '137.168.111.222'
      , (err, instance) ->
        test.fail instance, cb

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
