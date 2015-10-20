chai = require 'chai'
expect = chai.expect

validator = require 'alinex-validator'

check = require '../../lib/check'

describe "Controller", ->

  describe "configuration", ->

    it "should has correct validator rules", ->
      validator.selfcheck 'check.controller', check.controller
