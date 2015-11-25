# Storage Management
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:storage')
chalk = require 'chalk'
moment = require 'moment'
# include alinex modules
config = require 'alinex-config'
async = require 'alinex-async'
database = require 'alinex-database'
{string} = require 'alinex-util'
# include classes and helpers


# General data
# -------------------------------------------------
conf = null

# Initialize database
# -------------------------------------------------
exports.init = (cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?
  debug "Initialize database store..."
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    drop conf, db, (err) ->
      return cb err if err
      create conf, db, cb

# Drop database
# -------------------------------------------------
# This should not be enabled in productive system.
drop = (conf, db, cb) ->
  return cb() # disable function
  async.eachSeries [
    "DROP SCHEMA public CASCADE"
    "CREATE SCHEMA public"
  ], (sql, cb) ->
    db.exec sql, cb
  , cb

# Create database structure
# -------------------------------------------------
create = (conf, db, cb) ->
  # check if tables are installed
  prefix = conf.storage.prefix
  db.value "SELECT * FROM pg_tables WHERE schemaname='public'"
  , (err, num) ->
    return cb err if err or num
    queries =
      controller: (cb) -> db.exec """
        CREATE TABLE #{prefix}controller (
          controller_id SERIAL PRIMARY KEY,
          name VARCHAR(32) UNIQUE NOT NULL
        )
        """, cb
      check: ['controller', (cb) -> db.exec """
        CREATE TABLE #{prefix}check (
          check_id SERIAL PRIMARY KEY,
          controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
          sensor VARCHAR(16) NOT NULL,
          name VARCHAR(120),
          category VARCHAR(8) NOT NULL
        )
        """, cb]
      idx_check: ['check', (cb) -> db.exec """
        CREATE UNIQUE INDEX idx_#{prefix}check ON #{prefix}check (controller_id, sensor, name)
        """, cb]
      intervalType: (cb) -> db.exec """
        CREATE TYPE intervalType AS ENUM ('minute', 'hour', 'day', 'week', 'month')
        """, cb
      statusType: (cb) -> db.exec """
        CREATE TYPE statusType AS ENUM ('ok', 'warn', 'fail')
        """, cb
      status: ['statusType', 'check', (cb) -> db.exec """
        CREATE TABLE #{prefix}status_sensor (
          check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
          change TIMESTAMP WITH TIME ZONE,
          status statusType NOT NULL,
          comment VARCHAR(120)
        )
        """, cb]
      status: ['statusType', 'controller', (cb) -> db.exec """
        CREATE TABLE #{prefix}status_controller (
          controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
          change TIMESTAMP WITH TIME ZONE,
          status statusType NOT NULL,
          comment VARCHAR(120)
        )
        """, cb]
      report: ['controller', (cb) -> db.exec """
        CREATE TABLE #{prefix}report (
          report_id SERIAL PRIMARY KEY,
          controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
          date TIMESTAMP WITH TIME ZONE,
          report TEXT NOT NULL
        )
        """, cb]
        # get list of sensors
    monitor = require './index'
    monitor.listSensors (err, list) ->
      return cb err if err
      async.each list, (name, cb) ->
        monitor.getSensor name, (err, sensor) ->
          return cb err if err
          sql = """
            CREATE TABLE #{prefix}sensor_#{name} (
              check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
              interval intervalType NOT NULL,
              period TIMESTAMP WITH TIME ZONE,
              _c INTEGER NOT NULL
            """
          for k, v of sensor.meta.values
            type = switch v.type
              when 'integer', 'byte' then 'BIGINT'
              when 'float', 'percent', 'interval' then 'FLOAT'
              when 'date' then 'TIMESTAMP WITH TIME ZONE'
              else 'VARCHAR(100)'
            sql += ", \"#{k.toLowerCase()}\" #{type}"
          sql += ")"
          queries["sensor_#{name}"] = ['intervalType', 'check', (cb) -> db.exec sql, cb]
          cb()
      , (err) ->
        # run all sql queries
        async.auto queries, db.conf.pool?.limit ? 10, cb

# Get or register controller
# -------------------------------------------------
exports.controller = (name, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    db.value """
      SELECT controller_id FROM #{prefix}controller WHERE name=$1
      """, name, (err, value) ->
      return cb err, value if err or value
      debug "register controller #{name}"
      db.exec """
        INSERT INTO #{prefix}controller (name) VALUES ($1) RETURNING controller_id
        """, name, (err, num, id) ->
        cb err, id

# Get or register check
# -------------------------------------------------
exports.check = (controller, sensor, name, category, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    db.value """
      SELECT check_id FROM #{prefix}check WHERE controller_id=$1 AND sensor=$2 AND name=$3
      """, [controller, sensor, name], (err, value) ->
      return cb err, value if err or value
      debug "register check #{sensor}:#{name} for controller_id #{controller}"
      db.exec """
        INSERT INTO #{prefix}check
        (controller_id, sensor, name, category) VALUES ($1, $2, $3, $4)
        RETURNING check_id
        """, [controller, sensor, name, category], (err, num, id) ->
        cb err, id

valueTypes = ['integer', 'float', 'interval', 'byte', 'percent']

# Add results
# -------------------------------------------------
exports.results = (checkID, sensor, meta, date, value, cb) ->
  console.log '++++', checkID, sensor, meta, date, value
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    m = moment date
    async.each ['minute', 'hour', 'day', 'week', 'month'], (interval, cb) -> # 'quarter', 'year'
      period = m.startOf(interval).toDate()
      db.value """
        SELECT COUNT(*)::int FROM #{prefix}sensor_#{sensor}
        WHERE check_id=$1 AND interval=$2 AND period=$3
        """, [checkID, interval, period], (err, exists) ->
        return cb err if err
        # insert
        unless exists
          debug "add results to check #{checkID} (#{sensor}) for #{interval}"
          db.exec """
            INSERT INTO #{prefix}sensor_#{sensor}
            (check_id, interval, period, _c, "#{Object.keys(value).join('", "').toLowerCase()}")
            VALUES (?, ?, ?, 1#{string.repeat ', ?', Object.keys(value).length})
            """
          , [checkID, interval, period].concat(Object.keys(value).map (k) -> value[k])
          , (err, num, id) ->
            cb err, id
          return
        # update
        debug "update results to check #{checkID} (#{sensor}) for #{interval}"
        set = "SET _c = _c+1, " + Object.keys(value).map (k) ->
          if meta[k].type in valueTypes
            "\"#{k}\" = (\"#{k}\" * _c  + ?) / _c+1"
          else
            "\"#{k}\" = ?"
        .join ', '
        db.exec """
          UPDATE #{prefix}sensor_#{sensor}
          #{set}
          WHERE check_id=? AND interval=? AND period=?
          """
        , (Object.keys(value).map (k) -> value[k]).concat([checkID, interval, period])
        , (err, num, id) ->
          cb err, id
    , cb
