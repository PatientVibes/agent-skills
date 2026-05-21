---
description: Introspect the chorus databases (Postgres + Oracle) running in chorus-platform via docker exec
argument-hint: [postgres|oracle|awd|chorus] <SQL or backslash-command>
---

Run a database query against one of the chorus databases. The DBs run inside chorus-platform's docker-compose; psql/sqlplus are not installed locally so we shell into the containers.

Request: $ARGUMENTS

## Targets

| Alias | Container | Engine | Connection |
|---|---|---|---|
| `awd` (or `postgres`) | `chorus-platform-awd-postgres-1` | Postgres 15 | `awddb` / user `awdpowner` / pass `awdSecure2024!` (`$DB_PASSWORD`) |
| `chorus` | `chorus-platform-postgres-1` | Postgres 16 | flyway-managed Chorus 25.1.1.2 schema |
| `oracle` | `chorus-platform-dbserver-1` | Oracle Free 23 | PDB `FREEPDB1` / `sys/oracle as sysdba` (or `AWDPOWNER/awd`) |

## Steps

1. **Pick the target** based on the user's first word (`postgres`/`awd`/`chorus`/`oracle`). If ambiguous, ask. Default to `awd` if the request mentions `awddb`, AWDPOWNER tables, or v2-api.

2. **Verify the container is up** with `docker ps --format '{{.Names}}' | grep <container>`. If not running, tell the user — do not try to start it.

3. **Run the query.** Use the patterns below. Always pass `-U <user>` and use `-c '<sql>'` for one-shot queries; for multi-line SQL or `\d`-style commands, pipe via stdin.

   **Postgres (awd / chorus):**
   ```bash
   docker exec chorus-platform-awd-postgres-1 psql -U awdpowner -d awddb -c '\dt'
   docker exec chorus-platform-awd-postgres-1 psql -U awdpowner -d awddb -c "SELECT count(*) FROM cases;"
   docker exec -i chorus-platform-awd-postgres-1 psql -U awdpowner -d awddb <<'SQL'
   SELECT column_name, data_type
   FROM information_schema.columns
   WHERE table_name = 'cases'
   ORDER BY ordinal_position;
   SQL
   ```

   **Oracle (sysdba for schema introspection):**
   ```bash
   docker exec chorus-platform-dbserver-1 sh -c "echo 'select count(*) from awdpowner.cases;' | sqlplus -S sys/oracle@FREEPDB1 as sysdba"
   docker exec chorus-platform-dbserver-1 sh -c "echo \"select column_name, data_type from dba_tab_columns where owner='AWDPOWNER' and table_name='CASES' order by column_id;\" | sqlplus -S sys/oracle@FREEPDB1 as sysdba"
   ```

4. **Treat the user's request as introspection**, not migration. If the SQL is `INSERT`, `UPDATE`, `DELETE`, `DROP`, `TRUNCATE`, `ALTER`, `CREATE`, `GRANT`, or `REVOKE`, **stop and ask first** — show the query and the target and wait for explicit confirmation before running. Read-only queries (`SELECT`, `\d`, `EXPLAIN`, `information_schema` / `dba_*` / `user_*` views) can run without confirmation.

5. **Report cleanly.** Show the query you ran, the result table (truncated to a reasonable width), and a one-line summary. If the result is huge, show the first ~30 rows and total count.

6. **Do not allowlist `psql` or `sqlplus`** — arbitrary SQL allows arbitrary writes. Each `docker exec` invocation will trigger a permission prompt; that's intentional friction.
