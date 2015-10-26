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
      test.validator diskfree,
        share: '/'
      , (err, conf) ->
        diskfree.run 'test', conf, (err, res) ->
          expect(err).to.not.exist
          expect(res).to.exist
          expect(res.values.total).to.be.above 0
          expect(res.values.used).to.be.above 0
          expect(res.values.free).to.be.above 0
          expect(res.message).to.not.exist
          cb()

    it "should work with binary values", (cb) ->
      test.validator diskfree,
        share: '/'
        warn: 'free < 1GB'
      , (err, conf) ->
        diskfree.run 'test', conf, (err, res) ->
          expect(err).to.not.exist
          expect(res).to.exist
          expect(res.values.total).to.be.above 0
          expect(res.values.used).to.be.above 0
          expect(res.values.free).to.be.above 0
          expect(res.message).to.not.exist
          cb()
