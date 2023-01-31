# Cassandra-Reaper

Reaper is an open source tool that aims to schedule and orchestrate repairs of Apache Cassandra clusters.

It improves the existing nodetool repair process by:

Splitting repair jobs into smaller tunable segments.
Handling back-pressure through monitoring running repairs and pending compactions.
Adding ability to pause or cancel repairs and track progress precisely.
Reaper ships with a REST API, a command line tool and a web UI.

Reaper is running on config-database by default.

### Known issues:
---------------

On start reaper creates tables in reaper_db keyspace on cassandra storage. Sometimes for different reasons it may cause some corruptions on table then reaper report the errors like

```
[main] i.c.ReaperApplication - Storage is not ready yet, trying again to connect shortly... 
java.lang.IllegalArgumentException: A health check named cassandra.contrail_database already exists
```

The root error is upward and is something like:
```
Error during migration of script 021_sidecar_mode.cql while executing 'CREATE TABLE IF NOT EXISTS node_metrics_v2...
```

or:
```
Column family ID mismatch`
```

The only way to resolve it - is to run cqlsh to cassandra and
```
DROP KEYSPACE reaper_db ;
```

wait until keyspace is dropped
```
DESC KEYSPACES
```

and restart the configdb cassandra containers.
