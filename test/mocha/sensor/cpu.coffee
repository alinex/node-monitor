chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
cpu = require '../../../src/sensor/cpu'

describe "CPU", ->

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema cpu, cb

    it "should has meta data", (cb) ->
      test.meta cpu, cb

    it "should return success", (cb) ->
      @timeout 10000
      test.run cpu, {}, (err, res) ->
        expect(res.values.active).to.be.above 0
        cb()

    it "should work with binary values", (cb) ->
      test.run cpu,
        warn: 'active > 0.01%'
      , (err, res) ->
        expect(res.values.active).to.be.above 0
        expect(res.status).to.be.equal 'warn'
        cb()

  describe "analysis", ->

    it "should make an analysis report", (cb) ->
      test.analysis cpu,
        analysis:
          procNum: 5
      , (err, report) ->
        console.log report
        cb()
