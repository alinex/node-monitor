### eslint-env node, mocha ###

validator = require 'alinex-validator'

describe "Base", ->

  describe "configuration", ->

    it "should run the selfcheck on the schema", (cb) ->
      validator = require 'alinex-validator'
      schema = require '../../src/configSchema'
      validator.selfcheck schema, cb
