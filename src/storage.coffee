# Storage Management
# =================================================

# Node Modules
# -------------------------------------------------

# include base modules
debug = require('debug')('monitor:storage')
chalk = require 'chalk'
# include alinex modules
config = require 'alinex-config'
async = require 'alinex-async'
database = require 'alinex-database'
# include classes and helpers

conf = null

exports.init = (cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?
  debug "Initialize database store..."
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    drop conf, db, (err) ->
      return cb err if err
      create conf, db, cb

drop = (conf, db, cb) ->
  async.eachSeries [
    "DROP SCHEMA public CASCADE"
    "CREATE SCHEMA public"
  ], (sql, cb) ->
    db.exec sql, cb
  , cb

create = (conf, db, cb) ->
  # check if tables are installed
  prefix = conf.storage.prefix
  db.value "SELECT * FROM pg_tables WHERE schemaname='public'"
  , (err, num) ->
    return cb err if err or num
    limit = config.get("/database/#{conf.storage.database}/pool/limit") ? 5
    async.auto
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
          sensor VARCHAR(10) NOT NULL,
          name VARCHAR(80) NOT NULL,
          category VARCHAR(5) NOT NULL
        )
        """, cb]
      idx_check: ['check', (cb) -> db.exec """
        CREATE UNIQUE INDEX idx_#{prefix}check ON #{prefix}check (controller_id, sensor, name)
        """, cb]
      value: ['check', (cb) -> db.exec """
        CREATE TABLE #{prefix}value (
          value_id SERIAL PRIMARY KEY,
          check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
          name VARCHAR(80) NOT NULL
        )
        """, cb]
      idx_value: ['value', (cb) -> db.exec """
        CREATE UNIQUE INDEX idx_#{prefix}value ON #{prefix}value (check_id, name)
        """, cb]
      value_minute: ['value', (cb) -> db.exec """
        CREATE TABLE #{prefix}value_minute (
          value_minute_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          period TIMESTAMP WITH TIME ZONE NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL
        )
        """, cb]
      idx_value_minute: ['value_minute', (cb) -> db.exec """
        CREATE UNIQUE INDEX idx_#{prefix}value_minute ON #{prefix}value_minute (value_id, period)
        """, cb]
      value_hour: ['value', (cb) -> db.exec """
        CREATE TABLE #{prefix}value_hour (
          value_hour_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          period TIMESTAMP WITH TIME ZONE NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL
        )
        """, cb]
      idx_value_hour: ['value_hour', (cb) -> db.exec """
        CREATE UNIQUE INDEX idx_#{prefix}value_hour ON #{prefix}value_hour (value_id, period)
        """, cb]
      value_day: ['value', (cb) -> db.exec """
        CREATE TABLE #{prefix}value_day (
          value_day_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          period DATE NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL
        )
        """, cb]
      idx_value_day: ['value_day', (cb) -> db.exec """
        CREATE UNIQUE INDEX idx_#{prefix}value_day ON #{prefix}value_day (value_id, period)
        """, cb]
      value_week: ['value', (cb) -> db.exec """
        CREATE TABLE #{prefix}value_week (
          value_week_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          period DATE NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL
        )
        """, cb]
      idx_value_week: ['value_week', (cb) -> db.exec """
        CREATE UNIQUE INDEX idx_#{prefix}value_week ON #{prefix}value_week (value_id, period)
        """, cb]
      statusType: (cb) -> db.exec """
        CREATE TYPE statusType AS ENUM ('ok', 'warn', 'fail')
        """, cb
      status: ['statusType', 'controller', 'check', (cb) -> db.exec """
        CREATE TABLE #{prefix}status (
          controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
          check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
          change TIMESTAMP WITH TIME ZONE,
          status statusType NOT NULL
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
    , cb

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

exports.value = (check, name, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    db.value """
      SELECT value_id FROM #{prefix}value WHERE check_id=$1 AND name=$2
      """, [check, name], (err, value) ->
      return cb err, value if err or value
      debug "register value #{name} for check_id #{check}"
      db.exec """
        INSERT INTO #{prefix}value
        (check_id, name) VALUES ($1, $2)
        RETURNING check_id
        """, [check, name], (err, num, id) ->
        cb err, id

exports.results = (valueID, meta, date, value, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    m = moment date
    async.each ['minute', 'hour', 'day', 'week', 'month'], (interval, cb) -> # 'quarter', 'year'
      period = m.startOf(interval)
      db.value """
        SELECT COUNT(*) FROM #{prefix}value_#{interval} WHERE value_id=$1 AND period=$2
        """, [valueID, period], (err, value) ->
        return cb err if err
        # insert
        unless value
          debug "add value_id #{valueID} for #{interval} #{period}"
          db.exec """
            INSERT INTO #{prefix}value_#{interval}
            (value_id, period, num) VALUES ($1, $2, 1)
            RETURNING check_id
            """, [valueID, period], (err, num, id) ->
            cb err, id
############################### add data
        # update
############################### create update statement
    , cb
