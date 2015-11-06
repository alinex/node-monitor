chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
http = require '../../../src/sensor/http'

describe "HTTP", ->
  @timeout 10000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema http, cb

    it "should has meta data", (cb) ->
      test.meta http, cb

    it "should connect to webserver", (cb) ->
      test.ok http,
        url: 'http://heise.de'
      , (err, res) ->
        store = res
        expect(res.values.responseTime).to.exist
        expect(res.values.statusCode).to.exist
        expect(res.values.statusMessage).to.exist
        expect(res.values.server).to.exist
        expect(res.values.contentType).to.exist
        expect(res.values.length).to.exist
        cb()

  describe "check", ->

    it "should fail for non-existent webserver", (cb) ->
      test.fail http,
        url: 'http://nonexistentsubdomain.unknown.site'
      , (err, res) ->
        expect(res.message).to.exist
        cb()

    it "should fail for wrong protocol", (cb) ->
      test.fail http,
        url: 'ftp://heise.de'
      , (err, res) ->
        expect(res.message).to.exist
        cb()

    it "should fail for non-existing page", (cb) ->
      test.fail http,
        url: 'http://heise.de/page-which-does-not-exit-on-this-server'
      , (err, res) ->
        expect(res.message).to.exist
        cb()

  describe "match body", ->

    it "should work with simple substring", (cb) ->
      test.ok http,
        url: 'http://heise.de'
        match: 'Newsticker'
        fail: 'not match'
      , (err, res) ->
        expect(res.values.match).to.exist
        expect(res.values.match).to.deep.equal ['Newsticker']
        cb()

    it "should fail with simple substring", (cb) ->
      test.fail http,
        url: 'http://heise.de'
        match: 'GODCHA nOt INCLUDED'
        fail: 'not match'
      , (err, res) ->
        cb()

    it "should work with simple RegExp", (cb) ->
      test.ok http,
        url: 'http://heise.de'
        match: /heise Developer|iX Magazin/
        fail: 'not match'
      , (err, res) ->
        expect(res.values.match).to.exist
        expect(res.values.match).to.deep.equal ['heise Developer']
        cb()

    it "should fail with simple RegExp", (cb) ->
      test.fail http,
        url: 'http://heise.de'
        match: /heise Alinex Developer/
        fail: 'not match'
      , (err, res) ->
        cb()

    it "should work with named RegExp", (cb) ->
      test.ok http,
        url: 'http://heise.de'
        match: /(:<title>heise Developer|iX Magazin)/
        fail: 'not match'
      , (err, res) ->
        expect(res.values.match).to.exist
        expect(Boolean res.values.match).to.equal true
        cb()

    it "should fail with named RegExp", (cb) ->
      test.fail http,
        url: 'http://heise.de'
        match: /(:<title>Alinex Developer|Alinex Magazin)/
        fail: 'not match'
      , (err, res) ->
        expect(res.message).to.exist
        cb()

    it "should work with named RegExp and value check", (cb) ->
      test.ok http,
        url: 'http://heise.de'
        match: /(:<title>heise Developer|iX Magazin)/
        fail: 'match.title isnt \'heise Developer\''
      , (err, res) ->
        expect(res.values.match).to.exist
        expect(Boolean res.values.match).to.equal true
        cb()

  describe "reporting", ->

    it "should make an analysis report", (cb) ->
      test.analysis http,
        url: 'http://heise.de'
        analysis:
          bodyLength: 256
      , store, (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report http,
        url: 'http://heise.de'
        analysis:
          bodyLength: 256
      , store, (err, report) ->
        console.log report
        cb()
