chai = require 'chai'
expect = chai.expect
### eslint-env node, mocha ###

test = require '../actor'
config = require 'alinex-config'
Report = require 'alinex-report'

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
      console.log 'EMAIL', stubData
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

    report = new Report()
    report.h1 'Test Report'
    report.p 'This is a short example of an report which is added Automatically
      to the email before sending.'
    report.ul ['in text', 'and html']

    it "should support base settings", (cb) ->
      testStub
        base: 'ok'
        to: 'info@alinex.de'
        subject: 'Mocha Test'
      , (err, action, email) ->
        expect(email.data.body, 'body').to.exist
        cb()

    it "should support text+html", (cb) ->
      testStub
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: 'Mocha Test'
        text: 'This is the content.'
        html: '<p>This is <b>the</b> content.</p>'
      , (err, action, email) ->
        expect(email.data.text, 'text').to.exist
        expect(email.data.html, 'html').to.exist
        cb()

    it "should use report if no text/html", (cb) ->
      testStub
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: 'Mocha Test'
        report: report
      , (err, action, email) ->
        expect(email.data.text, 'text').to.exist
        expect(email.data.html, 'html').to.exist
        cb()

    it "should use report to add to text/html", (cb) ->
      testStub
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: 'Mocha Test'
        text: 'This is the content.'
        html: '<p>This is <b>the</b> content.</p>'
        report: report
      , (err, action, email) ->
        expect(email.data.text, 'text').to.exist
        expect(email.data.html, 'html').to.exist
        cb()

    it "should auto create subject from body", (cb) ->
      testStub
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        report: report
      , (err, action, email) ->
        expect(email.data.text, 'text').to.exist
        expect(email.data.html, 'html').to.exist
        cb()

    it "should support handlebars", (cb) ->
      handlebars = require 'handlebars'
      testStub
        from: 'info@alinex.de'
        to: 'info@alinex.de'
        subject: handlebars.compile "Mail with {{title}}"
        text: handlebars.compile "This is only a {{name}}"
        context:
          title: 'handlebars'
          name: 'test'
      , (err, action, email) ->
        expect(email.data.subject, 'subject').to.equal 'Mail with handlebars'
        expect(email.data.text, 'text').to.equal 'This is only a test'
        cb()
# priority
