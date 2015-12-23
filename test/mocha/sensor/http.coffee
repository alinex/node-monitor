chai = require 'chai'
expect = chai.expect

validator = require 'alinex-validator'
test = require '../sensor'
Check = require '../../../src/check'

sensor = require '../../../src/sensor/http'

before (cb) -> test.setup cb

describe "HTTP sensor", ->

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
        sensor: 'http'
        config:
          url: 'http://heise.de'
      , (err, instance) ->
        check = instance
        cb()

    it "should connect to webserver", (cb) ->
      @timeout 20000
      test.ok check, (err) ->
        expect(check.values.responseTime).to.exist
        expect(check.values.statusCode).to.exist
        expect(check.values.statusMessage).to.exist
        expect(check.values.server).to.exist
        expect(check.values.contentType).to.exist
        expect(check.values.length).to.exist
        cb()

    it "should fail for non-existent webserver", (cb) ->
      @timeout 20000
      test.init
        sensor: 'http'
        config:
          url: 'http://nonexistentsubdomain.unknown.site'
      , (err, instance) ->
        test.fail instance, cb

    it "should fail for wrong protocol", (cb) ->
      @timeout 20000
      test.init
        sensor: 'http'
        config:
          url: 'ftp://heise.de'
      , (err, instance) ->
        test.fail instance, cb

    it "should fail for non-existing page", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de/page-which-does-not-exist-on-this-server'
      , (err, instance) ->
        test.fail instance, cb

  describe "match body", ->
    @timeout 20000

    it "should work with simple substring", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de'
          match: 'Newsticker'
          fail: 'not match'
      , (err, instance) ->
        test.ok instance, (err, res) ->
          expect(instance.values.match).to.exist
          expect(instance.values.match).to.deep.equal ['Newsticker']
          cb()

    it "should fail with simple substring", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de'
          match: /heise Alinex Developer/
          fail: 'not match'
      , (err, instance) ->
        test.fail instance, cb

    it "should work with simple RegExp", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de'
          match: /heise Developer|iX Magazin/
          fail: 'not match'
      , (err, instance) ->
        test.ok instance, (err, res) ->
          expect(instance.values.match).to.exist
          expect(instance.values.match).to.deep.equal ['heise Developer']
          cb()

    it "should fail with simple RegExp", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de'
          match: /heise Alinex Developer/
          fail: 'not match'
      , (err, instance) ->
        test.fail instance, cb

    it "should work with named RegExp", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de'
          match: /(:<title>heise Developer|iX Magazin)/
          fail: 'not match'
      , (err, instance) ->
        test.ok instance, (err, res) ->
          expect(instance.values.match).to.exist
          expect(Boolean instance.values.match).to.equal true
          cb()

    it "should fail with named RegExp", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de'
          match: /(:<title>Alinex Developer|Alinex Magazin)/
          fail: 'not match'
      , (err, instance) ->
        test.fail instance, cb

    it "should work with named RegExp and value check", (cb) ->
      test.init
        sensor: 'http'
        config:
          url: 'http://heise.de'
          match: /(:<title>heise Developer|iX Magazin)/
          fail: 'match.title isnt \'heise Developer\''
      , (err, instance) ->
        test.ok instance, (err, res) ->
          expect(instance.values.match).to.exist
          expect(Boolean instance.values.match).to.equal true
          cb()

  describe "result", ->

    it "should have values defined in meta", (cb) ->
      test.values check, cb

    it "should get report", (cb) ->
      test.report check, cb
