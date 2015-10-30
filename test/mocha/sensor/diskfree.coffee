chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
diskfree = require '../../../src/sensor/diskfree'

describe "Diskfree", ->

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema diskfree, cb

    it "should has meta data", (cb) ->
      test.meta diskfree, cb

    it "should return success", (cb) ->
      @timeout 10000
      test.run diskfree,
        share: '/'
      , (err, res) ->
        expect(res.values.total).to.be.above 0
        expect(res.values.used).to.be.above 0
        expect(res.values.free).to.be.above 0
        cb()

    it "should work with binary values", (cb) ->
      test.run diskfree,
        share: '/'
        warn: 'free < 1GB'
      , (err, res) ->
        expect(res.values.total).to.be.above 0
        expect(res.values.used).to.be.above 0
        expect(res.values.free).to.be.above 0
        expect(res.status).to.be.equal 'ok'
        cb()

  describe "analysis", ->

    it "should make an analysis report", (cb) ->
      test.analysis diskfree,
        share: '/'
        analysis:
          dirs: '/tmp, /var/log'
      , (err, report) ->
        console.log report
        cb()
