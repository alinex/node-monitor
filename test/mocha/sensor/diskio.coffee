chai = require 'chai'
expect = chai.expect
validator = require 'alinex-validator'

test = require './test'
diskio = require '../../../src/sensor/diskio'

describe "DiskIO", ->
  @timeout 15000

  store = null

  describe "run", ->

    it "should has correct validator rules", (cb) ->
      test.schema diskio, cb

    it "should has meta data", (cb) ->
      test.meta diskio, cb

    it "should return success", (cb) ->
      test.ok diskio,
        device: 'sda'
      , (err, res) ->
        store = res
        expect(res.values.read).to.exist
        cb()

  describe "check", ->

    it "should give warn on active", (cb) ->
      test.warn diskio,
        device: 'sda'
        warn: 'read >= 0'
      , (err, res) ->
        expect(res.values.read).to.exist
        cb()

  describe "reporting", ->

    it "should make the report", (cb) ->
      test.report diskio,
        device: 'sda'
      , store, (err, report) ->
        console.log report
        cb()
