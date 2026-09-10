# SQLite (vendored)

`sqlite3.c` and `sqlite3.h` are the official SQLite **amalgamation**, copied
here unmodified.

* Version: **3.53.4**
* Source: <https://sqlite.org/2026/sqlite-amalgamation-3530400.zip>
* Licence: public domain (SQLite has no licence to comply with)

## Why it is vendored

`b1air-daemon`, `b1air-shell` and `b1air-polkit-agent` all use SQLite for the
FocusTime screen-time database. Linking the system `libsqlite3` made the whole
desktop depend on whichever version the distribution happened to ship, and on
that package being installed at all. The amalgamation is exactly what upstream
publishes for building SQLite into a program, so the binaries now carry their
own copy and `sqlite` is no longer in the installer's package list.

## Build flags

Set in `src/Makefile` and `src/shell/CMakeLists.txt`:

| Flag | Why |
| --- | --- |
| `SQLITE_THREADSAFE=1` | Upstream's default; the daemon touches the DB from more than one place. |
| `SQLITE_OMIT_LOAD_EXTENSION=1` | Nothing loads extensions, and not having the entry point is one less thing to reach. |
| `SQLITE_DQS=0` | Double-quoted strings are identifiers, not string literals — the standard behaviour, and it turns a typo'd column name into an error instead of a silent string. |
| `SQLITE_DEFAULT_MEMSTATUS=0` | Skips allocation bookkeeping nothing reads. |
| `SQLITE_LIKE_DOESNT_MATCH_BLOBS` | Upstream-recommended; faster `LIKE`. |
| `SQLITE_MAX_EXPR_DEPTH=0` | Removes a depth check the queries here never approach. |

The file is compiled with `-w`: the amalgamation is not warning-clean under the
`-Wall -Wextra` this project holds its own code to, and upstream's warnings are
not ours to audit on every build.

## Updating

Download a newer amalgamation, replace both files, rebuild. There is nothing
else to change — no patches are applied.
