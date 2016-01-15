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
    uri: "#{__dirname}/../data/config/monitor/email.yml"
  cb()

describe.only "Email actor", ->

  describe "simple mail", ->

    it "should send email", (cb) ->
      actor.run
        transport: 'smtp://alexander.schilling%40divibib.com:<<<env://PW_ALEX_DIVIBIB_COM>>>@mail.divibib.com'
        from: 'alexander.schilling@divibib.com'
        to: 'alexander.schilling@divibib.com'
        # cc
        # bcc
        # replyTo
        subject: 'Testmail from Alinex Monitor'
        text: 'Hello World'
      , (err) ->
        expect(err, 'error').to.not.exist
        cb()
