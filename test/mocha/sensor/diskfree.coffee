chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
diskfree = require '../../../src/sensor/diskfree'

describe "Diskfree", ->

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema diskfree, cb

    it "should has meta data", (cb) ->
      test.meta diskfree, cb

    it "should return success", (cb) ->
      @timeout 10000
      test.ok diskfree,
        share: '/'
      , (err, res) ->
        store = res
        expect(res.values.total).to.be.above 0
        expect(res.values.used).to.be.above 0
        expect(res.values.free).to.be.above 0
        cb()

    it "should work with binary values", (cb) ->
      test.ok diskfree,
        share: '/'
        warn: 'free < 1GB'
      , (err, res) ->
        expect(res.values.total).to.be.above 0
        expect(res.values.used).to.be.above 0
        expect(res.values.free).to.be.above 0
        cb()

  describe "reporting", ->

    it "should make an analysis report", (cb) ->
      @timeout 20000
      test.analysis diskfree,
        share: '/'
        analysis:
          dirs: '/tmp, /var/log'
      , store, (err, report) ->
        store.analysis = report
        console.log report
        cb()

    it "should make the report", (cb) ->
      test.report diskfree,
        share: '/'
        analysis:
          dirs: '/tmp, /var/log'
      , store, (err, report) ->
        console.log report
        cb()
