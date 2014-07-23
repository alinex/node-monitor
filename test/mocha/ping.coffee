chai = require 'chai'
expect = chai.expect
require('alinex-error').install()

Ping = require '../../lib/sensor/ping'

describe "Ping sensor", ->

  it "should be initialized", ->
    ping = new Ping {}
    expect(ping).to.have.property 'config'

  it "should return success", (done) ->
    ping = new Ping
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
    ping = new Ping
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
    ping = new Ping
      host: '193.99.144.80'
      count: 10
    ping.run (err) ->
      expect(err).to.not.exist
      expect(ping.result).to.exist
      expect(ping.result.date).to.exist
      expect(ping.result.status).to.equal 'ok'
      expect(ping.result.data).to.exist
      expect(ping.result.message).to.not.exist
#      console.log ping
      done()

  it "should return fail", (done) ->
    ping = new Ping
      host: '137.168.111.222'
    ping.run (err) ->
      expect(err).to.exist
      expect(ping.result).to.exist
      expect(ping.result.date).to.exist
      expect(ping.result.status).to.equal 'fail'
      expect(ping.result.data).to.exist
      expect(ping.result.message).to.exist
      done()
