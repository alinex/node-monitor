chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

test = require '../actor'
Action = require '../../../src/action'
config = require 'alinex-config'

actor = require '../../../src/actor/email'

before (cb) ->
  @timeout 10000
  config.pushOrigin
    uri: "#{__dirname}/../../data/config/monitor/email.yml"
    path: 'monitor'
  cb()

describe.only "Email actor", ->

  action = null

  describe "definition", ->

    it "should has actor instance loaded", (cb) ->
      expect(actor, 'actor instance').to.exist
      cb()

    it "should has correct validator rules", (cb) ->
      test.schema actor, cb

    it "should has meta data", (cb) ->
      test.meta actor, cb

    it "should has api methods", (cb) ->
      expect(test.init, 'init').to.exist
      expect(test.init, 'run').to.exist
      cb()

  describe "run", ->

    it "should create new action", (cb) ->
      test.init
        email:
          transport:
            name: 'testsend'
            version: '1'
            send: (data, callback) ->
              callback()
            logger: false
          from: 'info@alinex.de'
          to: 'root@localhost'
          subject: 'Mocha Test 01'
      , (err, instance) ->
        action = instance
        cb()

    it "should send email", (cb) ->
      @timeout 5000
      test.run action, cb

  describe "possibilities", ->

    it "should send email through smtp", (cb) ->
      @timeout 5000
      test.init
        email:
          transport: "smtp://alexander.schilling%40divibib.com:" +
            process.env.PW_ALEX_DIVIBIB_COM + "@mail.divibib.com"
          from: 'alexander.schilling@divibib.com'
          to: 'info@alinex.de'
          subject: 'Mocha Test 02'
      , (err, action) ->
        test.run action, ->
          cb()

    it "should send email through gmail", (cb) ->
      @timeout 5000
      test.init
        email:
          transport: "smtp://alexander.reiner.schilling:" +
            process.env.PW_ALEX_GMAIL + "@smtp.gmail.com"
          from: 'info@alinex.de'
          to: 'info@alinex.de'
          subject: 'Mocha Test 03'
      , (err, action) ->
        test.run action, ->
          cb()

    it "should support text+html", (cb) ->

    it "should use report if no text/html", (cb) ->

    it "should support handlebars", (cb) ->

    it "should auto create subject from body", (cb) ->
