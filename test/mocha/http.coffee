chai = require 'chai'
expect = chai.expect
require('alinex-error').install()

HttpSensor = require '../../lib/sensor/http'

describe "Http request sensor", ->

  it "should be initialized", ->
    http = new HttpSensor {}
    expect(http).to.have.property 'config'

  it "should connect to webserver", (done) ->
    http = new HttpSensor
      url: 'http://heise.de'
    http.run (err) ->
      expect(err).to.not.exist
      expect(http.result).to.exist
      expect(http.result.date).to.exist
      expect(http.result.status).to.equal 'ok'
      expect(http.result.data).to.exist
      expect(http.result.message).to.not.exist
      done()

  it "should fail for non-existent webserver", (done) ->
    http = new HttpSensor
      url: 'http://nonexistentsubdomain.unknown.site'
    http.run (err) ->
      expect(err).to.exist
      expect(http.result).to.exist
      expect(http.result.date).to.exist
      expect(http.result.status).to.equal 'fail'
      expect(http.result.data).to.exist
      expect(http.result.message).to.exist
      done()

  it "should fail for wrong protocol", (done) ->
    http = new HttpSensor
      url: 'ftp://heise.de'
    http.run (err) ->
      expect(err).to.exist
      expect(http.result).to.exist
      expect(http.result.date).to.exist
      expect(http.result.status).to.equal 'fail'
      expect(http.result.data).to.exist
      expect(http.result.message).to.exist
      done()

  it "should fail for non-existing page", (done) ->
    http = new HttpSensor
      url: 'http://heise.de/page-which-does-not-exit-on-this-server'
    http.run (err) ->
      expect(err).to.exist
      expect(http.result).to.exist
      expect(http.result.date).to.exist
      expect(http.result.status).to.equal 'fail'
      expect(http.result.data).to.exist
      expect(http.result.message).to.exist
      done()
