chai = require 'chai'
expect = chai.expect

validator = require 'alinex-validator'
config = require 'alinex-config'
#test = require '../sensor'
#Check = require '../../../src/check'

actor = require '../../../src/actor/email'

before (cb) ->
  @timeout 10000
  config.pushOrigin
    uri: "#{__dirname}/../../data/config/monitor/email.yml"
    path: 'monitor'
  cb()

describe.only "Email actor", ->

  describe "simple mail", ->

    it "should send email", (cb) ->
      console.log config.get '/'
      actor.run
        base: 'default'
        from: 'monitor'
      , null, (err) ->
        expect(err, 'error').to.not.exist
        cb()
