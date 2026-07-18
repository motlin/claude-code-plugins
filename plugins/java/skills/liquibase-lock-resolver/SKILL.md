---
name: liquibase-lock-resolver
description: Diagnose Liquibase change-log lock failures in Maven tests and remove only stale H2 database files from build output directories before rerunning the affected tests. Use when failures contain "Could not acquire change log lock", "Currently locked by", or `liquibase.exception.LockException`.
---

# Resolve Liquibase Test Locks

Follow the Maven CLI skill whenever invoking Maven.

## Confirm the failure

Inspect the failing output and confirm a Liquibase lock signature. Do not delete files for an unrelated database, migration, or connectivity failure.

Determine the narrowest Maven module and test command that reproduces the failure.

## Find disposable H2 files

Search recursively for H2 files only beneath Maven `target/` directories. Typical names end in `.mv.db`, `.trace.db`, `.lock.db`, or `.db`.

Review the exact paths before deletion. Exclude source trees, checked-in fixtures, databases outside `target/`, and unrelated build artifacts.

## Remove the stale databases

Delete only the reviewed H2 paths, using the environment's safe file-removal facility when available. Report every removed file. Do not remove an entire `target/` directory unless the user separately asks for a clean build.

## Verify the resolution

Rerun the narrowest affected Maven test with the current module's upstream dependencies included when necessary. Do not use offline mode.

If no H2 files exist or the lock recurs, investigate instead of broadening deletion. Check for a still-running test JVM, concurrent builds sharing a database path, a non-H2 JDBC URL, or cleanup missing from the test lifecycle. Report the remaining cause and safe next action.
