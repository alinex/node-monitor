chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

test = require '../sensor'
sensor = require '../../../src/sensor/socket'

before (cb) -> test.setup cb

describe "Socket sensor", ->

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
        sensor: 'socket'
        config:
          host: '193.99.144.80'
          port: 80
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
        sensor: 'socket'
        config:
          host: 'heise.de'
          port: 80
      , (err, instance) ->
        test.ok instance, cb

    it "should fail to connect to wrong port", (cb) ->
      @timeout 20000
      test.init
        sensor: 'socket'
        config:
          host: '193.99.144.80'
          port: 1298
      , (err, instance) ->
        test.fail instance, cb

    it "should fail to connect to wrong host", (cb) ->
      @timeout 20000
      test.init
        sensor: 'socket'
        config:
          host: 'unknownsubdomain.nonexisting.host'
          port: 80
      , (err, instance) ->
        test.fail instance, cb

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
