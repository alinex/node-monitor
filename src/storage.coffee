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


exports.init = (conf, cb) ->
  debug "Initialize database store..."
  return cb() unless conf.storage?
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    prefix = conf.storage.prefix
    async.eachSeries [
      """
      CREATE TABLE IF NOT EXISTS #{prefix}controller (
        controller_id SERIAL PRIMARY KEY,
        name VARCHAR(32) UNIQUE NOT NULL
      )
      """
    ,
      """
      CREATE TABLE IF NOT EXISTS #{prefix}check (
        check_id SERIAL PRIMARY KEY,
        controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
        category VARCHAR(5) NOT NULL,
        sensor VARCHAR(10) NOT NULL,
        name VARCHAR(80) NOT NULL,
        INDEX (controller_id, sensor, name)
      )
      """
    ,
      """
      CREATE TABLE IF NOT EXISTS #{prefix}value (
        value_id SERIAL PRIMARY KEY,
        check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
        name VARCHAR(80) NOT NULL,
        INDEX (check_id, name)
      )
      """
#    - type (string)
#    - unit (string)
    ,
      """
      CREATE TABLE IF NOT EXISTS #{prefix}report (
        report_id SERIAL PRIMARY KEY,
        value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
        date TIMESTAMP WITH TIME ZONE,
        report TEXT NOT NULL
      )
      """
    ], (sql, cb) -> db.exec sql, cb
    , (err) ->
      return cb err if err
      async.each [
        """
        CREATE TABLE IF NOT EXISTS #{prefix}value_minute (
          value_minute_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          timerange VARCHAR(18) NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL,
          INDEX (value_id, timerange)
        )
        """
      ,
        """
        CREATE TABLE IF NOT EXISTS #{prefix}value_minute (
          value_minute_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          timerange VARCHAR(18) NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL,
          INDEX (value_id, timerange)
        )
        """
      ,
        """
        CREATE TABLE IF NOT EXISTS #{prefix}value_quarter (
          value_minute_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          timerange VARCHAR(18) NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL,
          INDEX (value_id, timerange)
        )
        """
      ,
        """
        CREATE TABLE IF NOT EXISTS #{prefix}value_hour (
          value_minute_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          timerange VARCHAR(18) NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL,
          INDEX (value_id, timerange)
        )
        """
      ,
        """
        CREATE TABLE IF NOT EXISTS #{prefix}value_day (
          value_minute_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          timerange VARCHAR(18) NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL,
          INDEX (value_id, timerange)
        )
        """
      ,
        """
        CREATE TABLE IF NOT EXISTS #{prefix}value_week (
          value_minute_id SERIAL PRIMARY KEY,
          value_id INTEGER REFERENCES #{prefix}value ON DELETE CASCADE,
          timerange VARCHAR(18) NOT NULL,
          num INTEGER NOT NULL,
          min NUMERIC NOT NULL,
          avg NUMERIC NOT NULL,
          max NUMERIC NOT NULL,
          last VARCHAR(120) NOT NULL,
          INDEX (value_id, timerange)
        )
        """
      ,
        """
        CREATE TYPE IF NOT EXISTS statusType AS ENUM ('ok', 'warn', 'fail');
        CREATE TABLE IF NOT EXISTS #{prefix}status (
          controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
          check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
          change TIMESTAMP WITH TIME ZONE,
          status statusType NOT NULL
        )
        """
      ,
        """
        CREATE TABLE IF NOT EXISTS #{prefix}report (
          controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
          date TIMESTAMP WITH TIME ZONE,
          report TEXT NOT NULL
        )
        """
      ], (sql, cb) -> db.exec sql, cb
      , cb
