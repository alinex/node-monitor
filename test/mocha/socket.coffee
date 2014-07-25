chai = require 'chai'
expect = chai.expect
require('alinex-error').install()

SocketSensor = require '../../lib/sensor/socket'

describe "Socket connection sensor", ->

  it "should be initialized", ->
    socket = new SocketSensor {}
    expect(socket).to.have.property 'config'

  it "should connect to webserver", (done) ->
    socket = new SocketSensor
      host: '193.99.144.80'
      port: 80
    socket.run (err) ->
      expect(err).to.not.exist
      expect(socket.result).to.exist
      expect(socket.result.date).to.exist
      expect(socket.result.status).to.equal 'ok'
      expect(socket.result.data).to.exist
      expect(socket.result.message).to.not.exist
      done()

  it "should connect to webserver by hostname", (done) ->
    socket = new SocketSensor
      host: 'heise.de'
      port: 80
    socket.run (err) ->
      expect(err).to.not.exist
      expect(socket.result).to.exist
      expect(socket.result.date).to.exist
      expect(socket.result.status).to.equal 'ok'
      expect(socket.result.data).to.exist
      expect(socket.result.message).to.not.exist
      done()

  it "should fail to connect to wrong port", (done) ->
    @timeout 5000
    socket = new SocketSensor
      host: '193.99.144.80'
      port: 1298
    socket.run (err) ->
      expect(err).to.exist
      expect(socket.result).to.exist
      expect(socket.result.date).to.exist
      expect(socket.result.status).to.equal 'fail'
      expect(socket.result.data).to.exist
      expect(socket.result.message).to.exist
      done()

  it "should fail to connect to wrong host", (done) ->
    @timeout 5000
    socket = new SocketSensor
      host: 'unknownsubdomain.nonexisting.host'
      port: 80
    socket.run (err) ->
      expect(err).to.exist
      expect(socket.result).to.exist
      expect(socket.result.date).to.exist
      expect(socket.result.status).to.equal 'fail'
      expect(socket.result.data).to.exist
      expect(socket.result.message).to.exist
      done()
