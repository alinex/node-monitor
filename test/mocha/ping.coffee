chai = require 'chai'
expect = chai.expect
require('alinex-error').install()

PingSensor = require '../../lib/sensor/ping'

describe "Ping sensor", ->

  it "should be initialized", ->
    ping = new PingSensor {}
    expect(ping).to.have.property 'config'

  it "should return success", (done) ->
    ping = new PingSensor
      host: '193.99.144.80'
    ping.run (err) ->
      expect(err).to.not.exist
      expect(ping.result).to.exist
      expect(ping.result.date).to.exist
      expect(ping.result.status).to.equal 'ok'
      expect(ping.result.data).to.exist
      expect(ping.result.message).to.not.exist
      done()

  it "should succeed with domain name", (done) ->
    ping = new PingSensor
      host: 'heise.de'
    ping.run (err) ->
      expect(err).to.not.exist
      expect(ping.result).to.exist
      expect(ping.result.date).to.exist
      expect(ping.result.status).to.equal 'ok'
      expect(ping.result.data).to.exist
      expect(ping.result.message).to.not.exist
      done()

  it "should send multiple packets", (done) ->
    @timeout 10000
    ping = new PingSensor
      host: '193.99.144.80'
      count: 10
    ping.run (err) ->
      expect(err).to.not.exist
      expect(ping.result).to.exist
      expect(ping.result.date).to.exist
      expect(ping.result.status).to.equal 'ok'
      expect(ping.result.data).to.exist
      expect(ping.result.message).to.not.exist
      done()

  it "should return fail", (done) ->
    ping = new PingSensor
      host: '137.168.111.222'
    ping.run (err) ->
      expect(err).to.exist
      expect(ping.result).to.exist
      expect(ping.result.date).to.exist
      expect(ping.result.status).to.equal 'fail'
      expect(ping.result.data).to.exist
      expect(ping.result.message).to.exist
      done()
