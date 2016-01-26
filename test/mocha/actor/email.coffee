chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

test = require '../actor'
config = require 'alinex-config'

actor = require '../../../src/actor/email'

stubData = null
transportStub =
  name: 'testsend'
  version: '1'
  send: (data, cb) ->
    stubData = data
    cb()
  logger: false

testEmail = (setup, cb) ->
  test.init
    email: setup
  , (err, action) ->
    test.run action, cb

testStub = (setup, cb) ->
  stubData = null
  setup.transport = transportStub
  test.init
    email: setup
  , (err, action) ->
    test.run action, (err, action) ->
      console.log 'SEND', action.setup
      console.log 'RECEIVE', stubData
      expect(stubData, 'send message').to.exist
      cb err, action, stubData


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
          transport: transportStub
          from: 'info@alinex.de'
          to: 'root@localhost'
          subject: 'Mocha Test 01'
      , (err, instance) ->
        action = instance
        cb()

    it "should send email", (cb) ->
      @timeout 5000
      test.run action, cb

  describe.skip "sending", ->

    it "should send email through smtp", (cb) ->
      @timeout 5000
      testEmail
        transport: "smtp://alexander.schilling%40divibib.com:" +
          process.env.PW_ALEX_DIVIBIB_COM + "@mail.divibib.com"
        from: 'alexander.schilling@divibib.com'
        to: 'info@alinex.de'
        subject: 'Mocha Test 02'
      , cb

    it "should send email through gmail", (cb) ->
      @timeout 5000
      testEmail
        transport: "smtp://alexander.reiner.schilling:" +
          process.env.PW_ALEX_GMAIL + "@smtp.gmail.com"
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: 'Mocha Test 03'
      , cb

    it "should send using smtps", (cb) ->
      @timeout 5000
      testEmail
        transport: "smtps://alexander.reiner.schilling:" +
          process.env.PW_ALEX_GMAIL + "@smtp.gmail.com"
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: 'Mocha Test 04'
      , cb

    it "should send through well-known service", (cb) ->
      @timeout 5000
      testEmail
        transport:
          service: 'gmail'
          auth:
            user: 'alexander.reiner.schilling'
            pass: process.env.PW_ALEX_GMAIL
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: 'Mocha Test 05'
      , cb

    it "should send using object structure", (cb) ->
      @timeout 5000
      testEmail
        transport:
          host: 'smtp.gmail.com'
          port: 465
          secure: true
          auth:
            user: 'alexander.reiner.schilling'
            pass: process.env.PW_ALEX_GMAIL
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: 'Mocha Test 06'
      , cb

  describe "possibilities", ->

    it "should support base settings", (cb) ->
      @timeout 5000
      testStub
        base: 'ok'
        to: 'info@alinex.de'
        subject: 'Mocha Test'
      , (err, action, email) ->
        cb()

    it "should support text+html", (cb) ->

    it "should use report if no text/html", (cb) ->

    it "should support handlebars", (cb) ->

    it "should auto create subject from body", (cb) ->
