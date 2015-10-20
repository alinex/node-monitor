chai = require 'chai'
expect = chai.expect

validator = require 'alinex-validator'

check = require '../../lib/check'

describe "Monitor", ->

  describe "configuration", ->

    it "should run the selfcheck on the schema", (cb) ->
      validator = require 'alinex-validator'
      schema = require '../../src/configSchema'
      validator.selfcheck schema, cb

