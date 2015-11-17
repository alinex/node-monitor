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


exports.init = (cb) ->
  conf = config.get '/monitor'
  debug "Initialize database store..."
  return cb() unless conf.storage?
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
          category VARCHAR(5) NOT NULL,
          sensor VARCHAR(10) NOT NULL,
          name VARCHAR(80) NOT NULL
        )
        """, cb]
      value: ['check', (cb) -> db.exec """
        CREATE TABLE #{prefix}value (
          value_id SERIAL PRIMARY KEY,
          check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
          name VARCHAR(80) NOT NULL
        )
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
