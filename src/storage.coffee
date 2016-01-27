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

# Configuration
# -------------------------------------------------
cleanupInterval =
  minute: 1800*1000 # every half hour
  hour: 3600*1000 # every hour
  day: 24*3600*1000 # every day
  week: 7*24*3600*1000 # every week
  month: 24*24*3600*1000 # every 24 days (maximum for setTimeout)


# Initialized Data
# -------------------------------------------------
# This will be set on init
monitor = null  # require './index'
conf = null
mode = {}


# Initialize database
# -------------------------------------------------
exports.init = (setup, cb) ->
  mode = setup
  monitor ?= require './index'
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?.database? and not mode.try
  debug "Initialize database store..."
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    drop conf, db, (err) ->
      return cb err if err
      create conf, db, (err) ->
        cleanup interval for interval in ['minute', 'hour', 'day', 'week', 'month']
        cb err


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
  queries =
    controller: (cb) -> db.exec """
      CREATE TABLE IF NOT EXISTS #{prefix}controller (
        controller_id SERIAL PRIMARY KEY,
        name VARCHAR(32) UNIQUE NOT NULL
      )
      """, cb
    check: ['controller', (cb) -> db.exec """
      CREATE TABLE IF NOT EXISTS #{prefix}check (
        check_id SERIAL PRIMARY KEY,
        controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
        sensor VARCHAR(16) NOT NULL,
        name VARCHAR(120),
        category VARCHAR(8) NOT NULL
      )
      """, cb]
    idx_check: ['check', (cb) -> db.exec """
      DO $$
      BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM   pg_class c
            JOIN   pg_namespace n ON n.oid = c.relnamespace
            WHERE  c.relname = 'idx_#{prefix}check'
            AND    n.nspname = 'public'
            ) THEN
            CREATE UNIQUE INDEX idx_#{prefix}check ON #{prefix}check (controller_id, sensor, name);
        END IF;
      END$$;
      """, cb]
    intervalType: (cb) -> db.exec """
      DO $$
      BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = '#{prefix}interval') THEN
            CREATE TYPE #{prefix}interval AS ENUM ('minute', 'hour', 'day', 'week', 'month');
          END IF;
      END$$;
      """, cb
    statusType: (cb) -> db.exec """
      DO $$
      BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = '#{prefix}status') THEN
            CREATE TYPE #{prefix}status AS ENUM ('ok', 'warn', 'fail');
          END IF;
      END$$;
      """, cb
    statusSensor: ['statusType', 'check', (cb) -> db.exec """
      CREATE TABLE IF NOT EXISTS #{prefix}status_check (
        check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
        change TIMESTAMP WITH TIME ZONE,
        status #{prefix}status NOT NULL,
        comment VARCHAR(120)
      )
      """, cb]
    statusController: ['statusType', 'controller', (cb) -> db.exec """
      CREATE TABLE IF NOT EXISTS #{prefix}status_controller (
        controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
        change TIMESTAMP WITH TIME ZONE,
        status #{prefix}status NOT NULL
      )
      """, cb]
    report: ['controller', (cb) -> db.exec """
      CREATE TABLE IF NOT EXISTS #{prefix}report (
        report_id SERIAL PRIMARY KEY,
        controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
        date TIMESTAMP WITH TIME ZONE,
        report TEXT NOT NULL
      )
      """, cb]
  monitor = require './index'
  # add sensor tables
  async.each monitor.listSensor(), (name, cb) ->
    monitor.getSensor name, (err, sensor) ->
      return cb err if err
      sql = """
        CREATE TABLE IF NOT EXISTS #{prefix}sensor_#{name} (
          check_id INTEGER REFERENCES #{prefix}check ON DELETE CASCADE,
          interval #{prefix}interval NOT NULL,
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
    console.error chalk.red err if err
    # add actor tables
    async.each monitor.listActor(), (name, cb) ->
      monitor.getActor name, (err, actor) ->
        return cb err if err
        sql = """
          CREATE TABLE IF NOT EXISTS #{prefix}actor_#{name} (
            controller_id INTEGER REFERENCES #{prefix}controller ON DELETE CASCADE,
            runAt TIMESTAMP WITH TIME ZONE
          """
        for k, v of actor.meta.values
          type = switch v.type
            when 'integer', 'byte' then 'BIGINT'
            when 'float', 'percent', 'interval' then 'FLOAT'
            when 'date' then 'TIMESTAMP WITH TIME ZONE'
            else 'VARCHAR(100)'
          sql += ", \"#{k.toLowerCase()}\" #{type}"
        sql += ")"
        queries["actor_#{name}"] = ['controller', (cb) -> db.exec sql, cb]
        cb()
    , (err) ->
      console.error chalk.red err if err
      # run all sql queries
      async.auto queries, db.conf.pool?.limit ? 10, cb


# Get or register controller
# -------------------------------------------------
exports.controller = (name, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?.database? and not mode.try
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
  return cb() unless conf.storage?.database? and not mode.try
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
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?.database? and not mode.try
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    async.each ['minute', 'hour', 'day', 'week', 'month'], (interval, cb) -> # 'quarter', 'year'
      period = moment(date).startOf(interval).toDate()
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
            "\"#{k}\" = (\"#{k}\" * _c  + ?) / (_c+1)"
          else
            "\"#{k}\" = ?"
        .join ', '
        .toLowerCase()
        db.exec """
          UPDATE #{prefix}sensor_#{sensor}
          #{set}
          WHERE check_id=? AND interval=? AND period=?
          """
        , (Object.keys(value).map (k) -> value[k]).concat([checkID, interval, period])
        , (err, num, id) ->
          cb err, id
    , cb

exports.actions = (controllerID, actor, meta, date, value, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?.database? and not mode.try
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    db.exec """
      INSERT INTO #{prefix}actor_#{actor}
      (controller_id, runAt, "#{Object.keys(value).join('", "').toLowerCase()}")
      VALUES (?, ?, ?, 1#{string.repeat ', ?', Object.keys(value).length})
      """
    , [controllerID, date].concat(Object.keys(value).map (k) -> value[k])
    , (err, num, id) ->
      cb err, id


# Add status on change
# -------------------------------------------------
exports.statusCheck = (checkID, date, status, comment, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?.database? and not mode.try
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    # check if same status is already set
    db.value """
      SELECT status FROM #{prefix}status_check
      WHERE check_id=$1 ORDER BY change DESC
      """, [checkID], (err, oldStatus) ->
      return cb err if err
      return cb() if status is oldStatus
      # insert
      db.exec """
        INSERT INTO #{prefix}status_check
        (check_id, change, status, comment) VALUES (?, ?, ?, ?)
        """
      , [checkID, date, status, comment]
      , cb

exports.statusController = (controllerID, date, status, cb) ->
  conf ?= config.get '/monitor'
  return cb() unless conf.storage?.database? and not mode.try
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    return cb err if err
    # check if same status is already set
    db.value """
      SELECT status FROM #{prefix}status_controller
      WHERE controller_id=$1 ORDER BY change DESC
      """, [controllerID], (err, oldStatus) ->
      return cb err if err
      return cb null, 0 if status is oldStatus
      # insert
      db.exec """
        INSERT INTO #{prefix}status_controller
        (controller_id, change, status) VALUES (?, ?, ?)
        """
      , [controllerID, date, status]
      , cb


# Cleanup old data
# -------------------------------------------------
# This is triggered by timeouts of itself, started on storage initialization.
# See the configuration at the top of this file.
cleanup = (interval) ->
  setTimeout cleanup, cleanupInterval[interval], interval
  # run the cleanup
  prefix = conf.storage.prefix
  database.instance conf.storage.database, (err, db) ->
    num = conf.storage.cleanup[interval]
    debug "remove #{interval} entries older than #{num} #{interval}s"
    # for each sensor
    time = moment().subtract(num, interval).toDate()
    async.each monitor.listSensor(), (sensor, cb) ->
      db.exec "DELETE FROM #{prefix}sensor_#{sensor} WHERE interval=? AND period<?"
      , [interval, time]
      , cb
    , (err) ->
      console.error chalk.red.bold err if err
