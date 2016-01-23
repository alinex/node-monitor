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
          base: 'ok'
      , (err, instance) ->
        action = instance
        cb()

    it "should send email", (cb) ->
      @timeout 5000
      test.run action, ->
        expect(action.actor).to.exist
        cb()
