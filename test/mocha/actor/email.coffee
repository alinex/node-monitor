chai = require 'chai'
expect = chai.expect

validator = require 'alinex-validator'
config = require 'alinex-config'
#test = require '../sensor'
#Check = require '../../../src/check'

actor = require '../../../src/actor/email'

before (cb) ->
  @timeout 5000
  config.pushOrigin
    uri: "#{__dirname}/../data/config/monitor/email.yml"
  cb()

describe.only "Email actor", ->

  describe "simple mail", ->

    it "should initialize", (cb) ->
      actor.init (err) ->
        expect(err, 'error').to.not.exist
        cb()

    it "should send email", (cb) ->
      actor.run (err) ->
        expect(err, 'error').to.not.exist
        cb()
