::: program
mariadb-kill
:::

# `mariadb-kill`{.interpreted-text role="program"}

## NAME

`mariadb-kill`{.interpreted-text role="program"} - Kill MariaDB queries
that match certain criteria.

## SYNOPSIS

### Usage

    mariadb-kill [OPTIONS] [DSN]

`mariadb-kill`{.interpreted-text role="program"} kills MariaDB
connections. `mariadb-kill`{.interpreted-text role="program"} connects
to MariaDB and gets queries from SHOW PROCESSLIST if no FILE is given.
Else, it reads queries from one or more FILE which contains the output
of SHOW PROCESSLIST. If FILE is -, `mariadb-kill`{.interpreted-text
role="program"} reads from STDIN.

Kill queries running longer than 60s:

``` bash
mariadb-kill --busy-time 60 --kill
```

Print, do not kill, queries running longer than 60s:

``` bash
mariadb-kill --busy-time 60 --print
```

Check for sleeping processes and kill them all every 10s:

``` bash
mariadb-kill --match-command Sleep --kill --victims all --interval 10
```

Print all login processes:

``` bash
mariadb-kill --match-state login --print --victims all
```

See which queries in the processlist right now would match:

``` bash
mariadb -e "SHOW PROCESSLIST" > proclist.txt
mariadb-kill --test-matching proclist.txt --busy-time 60 --print
```

## RISKS

`mariadb-kill`{.interpreted-text role="program"} is mature, proven in
the real world, and well tested, but all database tools can pose a risk
to the system and the database server. Before using this tool, please:

-   Read the tool\'s documentation
-   Review the tool\'s known \"BUGS\"
-   Test the tool on a non-production server
-   Backup your production server and verify the backups

## DESCRIPTION

`mariadb-kill`{.interpreted-text role="program"} captures queries from
SHOW PROCESSLIST, filters them, and then either kills or prints them.
This is also known as a \"slow query sniper\" in some circles. The idea
is to watch for queries that might be consuming too many resources, and
kill them.

For brevity, we talk about killing queries, but they may just be printed
(or some other future action) depending on what options are given.

Normally `mariadb-kill`{.interpreted-text role="program"} connects to
MariaDB to get queries from SHOW PROCESSLIST. Alternatively, it can read
SHOW PROCESSLIST output from files. In this case,
`mariadb-kill`{.interpreted-text role="program"} does not connect to
MariaDB and `--kill`{.interpreted-text role="option"} has no effect. You
should use `--print`{.interpreted-text role="option"} instead when
reading files. The ability to read a file with
`--test-matching`{.interpreted-text role="option"} allows you to capture
SHOW PROCESSLIST and test it later with `mariadb-kill`{.interpreted-text
role="program"} to make sure that your matches kill the proper queries.
There are a lot of special rules to follow, such as \"don\'t kill
replication threads,\" so be careful not to kill something important!

Two important options to know are `--busy-time`{.interpreted-text
role="option"} and `--victims`{.interpreted-text role="option"}. First,
whereas most match/filter options match their corresponding value from
SHOW PROCESSLIST (e.g. `--match-command`{.interpreted-text
role="option"} matches a query\'s Command value), the Time value is
matched by `--busy-time`{.interpreted-text role="option"}. See also
`--interval`{.interpreted-text role="option"}.

Second, `--victims`{.interpreted-text role="option"} controls which
matching queries from each class are killed. By default, the matching
query with the highest Time value is killed (the oldest query). See the
next section, \"GROUP, MATCH AND KILL\", for more details.

Usually you need to specify at least one `--match` option, else no
queries will match. Or, you can specify `--match-all`{.interpreted-text
role="option"} to match all queries that aren\'t ignored by an
`--ignore` option.

## GROUP, MATCH AND KILL

Queries pass through several steps to determine which exactly will be
killed (or printed\--whatever action is specified). Understanding these
steps will help you match precisely the queries you want.

The first step is grouping queries into classes. The
`--group-by`{.interpreted-text role="option"} option controls grouping.
By default, this option has no value so all queries are grouped into one
default class. All types of matching and filtering (the next step) are
applied per-class. Therefore, you may need to group queries in order to
match/filter some classes but not others.

The second step is matching. Matching implies filtering since if a query
doesn\'t match some criteria, it is removed from its class. Matching
happens for each class. First, queries are filtered from their class by
the various `Query Matches` options like
`--match-user`{.interpreted-text role="option"}. Then, entire classes
are filtered by the various `Class Matches` options like
`--query-count`{.interpreted-text role="option"}.

The third step is victim selection, that is, which matching queries in
each class to kill. This is controlled by the
`--victims`{.interpreted-text role="option"} option. Although many
queries in a class may match, you may only want to kill the oldest
query, or all queries, etc.

The forth and final step is to take some action on all matching queries
from all classes. The `Actions` options specify which actions will be
taken. At this step, there are no more classes, just a single list of
queries to kill, print, etc.

`mariadb-kill`{.interpreted-text role="program"} will kill all the
queries matching ANY of the specified criteria (logical OR). For
example, using:

``` bash
--busy-time 114 --match-command 'Query|Execute'
```

will kill all queries having busy-time \> 114 `OR` where the command is
`Query` or `Execute`

If you want to kill only the queries where `busy-time` 114> `AND` the
command is Query or Execute, you need to use \"\--kill-busy-commands:

``` bash
--busy-time 114 --kill-busy-commands 'Query|Execute'
```

## OUTPUT

If only `--kill`{.interpreted-text role="option"} is given, then there
is no output. If only `--print`{.interpreted-text role="option"} is
given, then a timestamped KILL statement if printed for every query that
would have been killed, like:

``` bash
# 2009-07-15T15:04:01 KILL 8 (Query 42 sec) SELECT * FROM huge_table
```

The line shows a timestamp, the query\'s Id (8), its Time (42 sec) and
its Info (usually the query SQL).

If both `--kill`{.interpreted-text role="option"} and
`--print`{.interpreted-text role="option"} are given, then matching
queries are killed and a line for each like the one above is printed.

Any command executed by `--execute-command`{.interpreted-text
role="option"} is responsible for its own output and logging. After
being executed, `mariadb-kill`{.interpreted-text role="program"} has no
control or interaction with the command.

## OPTIONS

Specify at least one of `--kill`{.interpreted-text role="option"},
`--kill-query`{.interpreted-text role="option"},
`--print`{.interpreted-text role="option"},
`--execute-command`{.interpreted-text role="option"} or
`--stop`{.interpreted-text role="option"}.

`--any-busy-time`{.interpreted-text role="option"} and
`--each-busy-time`{.interpreted-text role="option"} are mutually
exclusive.

`--kill`{.interpreted-text role="option"} and
`--kill-query`{.interpreted-text role="option"} are mutually exclusive.

`--daemonize`{.interpreted-text role="option"} and
`--test-matching`{.interpreted-text role="option"} are mutually
exclusive.

This tool accepts additional command-line arguments. Refer to the
\"SYNOPSIS\" and usage information for details.

::: option
\--ask-pass

Prompt for a password when connecting to MariaDB.
:::

::: option
\--charset

short form: -A; type: string

Default character set. If the value is utf8, sets Perl\'s binmode on
STDOUT to utf8, passes the mysql_enable_utf8 option to DBD::mysql, and
runs SET NAMES UTF8 after connecting to MariaDB. Any other value sets
binmode on STDOUT without the utf8 layer, and runs SET NAMES after
connecting to MariaDB.
:::

::: option
\--config

type: Array

Read this comma-separated list of config files; if specified, this must
be the first option on the command line.
:::

::: option
\--create-log-table

Create the `--log-dsn`{.interpreted-text role="option"} table if it does
not exist.

This option causes the table specified by `--log-dsn`{.interpreted-text
role="option"} to be created with the default structure shown in the
documentation for that option.
:::

::: option
\--daemonize

Fork to the background and detach from the shell. POSIX operating
systems only.
:::

::: option
\--database

short form: -D; type: string

The database to use for the connection.
:::

::: option
\--defaults-file

short form: -F; type: string

Only read MariaDB options from the given file. You must give an absolute
pathname.
:::

::: option
\--filter

type: string

Discard events for which this Perl code doesn\'t return true.

This option is a string of Perl code or a file containing Perl code that
gets compiled into a subroutine with one argument: \$event. This is a
hashref. If the given value is a readable file, then
`mariadb-kill`{.interpreted-text role="program"} reads the entire file
and uses its contents as the code. The file should not contain a shebang
(#!/usr/bin/perl) line.

If the code returns true, the chain of callbacks continues; otherwise it
ends. The code is the last statement in the subroutine other than
`return $event`. The subroutine template is:

``` bash
sub { $event = shift; filter && return $event; }
```

Filters given on the command line are wrapped inside parentheses like
like `( filter )`. For complex, multi-line filters, you must put the
code inside a file so it will not be wrapped inside parentheses. Either
way, the filter must produce syntactically valid code given the
template. For example, an if-else branch given on the command line would
not be valid:

``` bash
--filter 'if () { } else { }'  # WRONG
```

Since it\'s given on the command line, the if-else branch would be
wrapped inside parentheses which is not syntactically valid. So to
accomplish something more complex like this would require putting the
code in a file, for example filter.txt:

``` bash
my $event_ok; if (...) { $event_ok=1; } else { $event_ok=0; } $event_ok
```

Then specify `--filter filter.txt` to read the code from filter.txt.

If the filter code won\'t compile, `mariadb-kill`{.interpreted-text
role="program"} will die with an error. If the filter code does compile,
an error may still occur at runtime if the code tries to do something
wrong (like pattern match an undefined value).
`mariadb-kill`{.interpreted-text role="program"} does not provide any
safeguards so code carefully!

It is permissible for the code to have side effects (to alter `$event`).
:::

::: option
\--group-by

type: string

Apply matches to each class of queries grouped by this SHOW PROCESSLIST
column. In addition to the basic columns of SHOW PROCESSLIST (user,
host, command, state, etc.), queries can be matched by `fingerprint`
which abstracts the SQL query in the `Info` column.

By default, queries are not grouped, so matches and actions apply to all
queries. Grouping allows matches and actions to apply to classes of
similar queries, if any queries in the class match.

For example, detecting cache stampedes (see `all-but-oldest` under
`--victims`{.interpreted-text role="option"} for an explanation of that
term) requires that queries are grouped by the `arg` attribute. This
creates classes of identical queries (stripped of comments). So queries
`"SELECT c FROM t WHERE id=1"` and `"SELECT c FROM t WHERE id=1"` are
grouped into the same class, but query c\<\"SELECT c FROM t WHERE
id=3\"\> is not identical to the first two queries so it is grouped into
another class. Then when `--victims`{.interpreted-text role="option"}
`all-but-oldest` is specified, all but the oldest query in each class is
killed for each class of queries that matches the match criteria.
:::

::: option
\--help

Show help and exit.
:::

::: option
\--host

short form: -h; type: string; default: localhost

Connect to host.
:::

::: option
\--interval

type: time

How often to check for queries to kill. If
`--busy-time`{.interpreted-text role="option"} is not given, then the
default interval is 30 seconds. Else the default is half as often as
`--busy-time`{.interpreted-text role="option"}. If both
`--interval`{.interpreted-text role="option"} and
`--busy-time`{.interpreted-text role="option"} are given, then the
explicit `--interval`{.interpreted-text role="option"} value is used.

See also `--run-time`{.interpreted-text role="option"}.
:::

::: option
\--log

type: string

Print all output to this file when daemonized.
:::

::: option
\--log-dsn

type: DSN

Store each query killed in this DSN.

The argument specifies a table to store all killed queries. The DSN
passed in must have the databse (D) and table (t) options. The table
must have at least the following columns. You can add more columns for
your own special purposes, but they won\'t be used by
`mariadb-kill`{.interpreted-text role="program"}. The following CREATE
TABLE definition is also used for `--create-log-table`{.interpreted-text
role="option"}. MAGIC_create_log_table:

``` sql
CREATE TABLE kill_log (
   kill_id     int(10) unsigned NOT NULL AUTO_INCREMENT,
   server_id   bigint(4) NOT NULL DEFAULT '0',
   timestamp   DATETIME,
   reason      TEXT,
   kill_error  TEXT,
   Id          bigint(4) NOT NULL DEFAULT '0',
   User        varchar(16) NOT NULL DEFAULT '',
   Host        varchar(64) NOT NULL DEFAULT '',
   db          varchar(64) DEFAULT NULL,
   Command     varchar(16) NOT NULL DEFAULT '',
   Time        int(7) NOT NULL DEFAULT '0',
   State       varchar(64) DEFAULT NULL,
   Info        longtext,
   Time_ms     bigint(21) DEFAULT '0', # NOTE, TODO: currently not used
   PRIMARY KEY (kill_id)
) DEFAULT CHARSET=utf8
```
:::

::: option
\--password

short form: -p; type: string

Password to use when connecting. If password contains commas they must
be escaped with a backslash: \"exam,ple\"
:::

::: option
\--pid

type: string

Create the given PID file. The tool won\'t start if the PID file already
exists and the PID it contains is different than the current PID.
However, if the PID file exists and the PID it contains is no longer
running, the tool will overwrite the PID file with the current PID. The
PID file is removed automatically when the tool exits.
:::

::: option
\--port

short form: -P; type: int

Port number to use for connection.
:::

::: option
\--query-id

Prints an ID of the query that was just killed. This is equivalent to
the \"ID\" output of pt-query-digest. This allows cross-referencing the
output of both tools.

Example:

``` bash
Query ID 0xE9800998ECF8427E
```

Note that this is a digest (or hash) of the query\'s \"fingerprint\", so
queries of the same form but with different values will have the same
ID. See pt-query-digest for more information.
:::

::: option
\--rds

Denotes the instance in question is on Amazon RDS. By default
`mariadb-kill`{.interpreted-text role="program"} runs the MariaDB
command \"kill\" for `--kill`{.interpreted-text role="option"} and
\"kill query\" `--kill-query`{.interpreted-text role="option"}. On RDS
these two commands are not available and are replaced by function calls.
This option modifies `--kill`{.interpreted-text role="option"} to use
\"CALL mysql.rds_kill(thread-id)\" instead and
`--kill-query`{.interpreted-text role="option"} to use \"CALL
mysql.rds_kill_query(thread-id)\"
:::

::: option
\--run-time

type: time

How long to run before exiting. By default
`mariadb-kill`{.interpreted-text role="program"} runs forever, or until
its process is killed or stopped by the creation of a
`--sentinel`{.interpreted-text role="option"} file. If this option is
specified, `mariadb-kill`{.interpreted-text role="program"} runs for the
specified amount of time and sleeps `--interval`{.interpreted-text
role="option"} seconds between each check of the PROCESSLIST.
:::

::: option
\--sentinel

type: string; default: /tmp/mariadb-kill-sentinel

Exit if this file exists.

The presence of the file specified by `--sentinel`{.interpreted-text
role="option"} will cause all running instances of
`mariadb-kill`{.interpreted-text role="program"} to exit. You might find
this handy to stop cron jobs gracefully if necessary. See also
`--stop`{.interpreted-text role="option"}.
:::

::: option
\--slave-user

type: string

Sets the user to be used to connect to the slaves. This parameter allows
you to have a different user with less privileges on the slaves but that
user must exist on all slaves.
:::

::: option
\--slave-password

type: string

Sets the password to be used to connect to the slaves. It can be used
with \--slave-user and the password for the user must be the same on all
slaves.
:::

::: option
\--set-vars

type: Array

Set the MariaDB variables in this comma-separated list of
`variable=value` pairs.

By default, the tool sets:

``` bash
wait_timeout=10000
```

Variables specified on the command line override these defaults. For
example, specifying `--set-vars wait_timeout=500` overrides the
defaultvalue of `10000`.

The tool prints a warning and continues if a variable cannot be set.
:::

::: option
\--socket

short form: -S; type: string

Socket file to use for connection.
:::

::: option
\--stop

Stop running instances by creating the `--sentinel`{.interpreted-text
role="option"} file.

Causes `mariadb-kill`{.interpreted-text role="program"} to create the
sentinel file specified by `--sentinel`{.interpreted-text role="option"}
and exit. This should have the effect of stopping all running instances
which are watching the same sentinel file.
:::

::: option
\--\[no\]strip-comments

default: yes

Remove SQL comments from queries in the Info column of the PROCESSLIST.
:::

::: option
\--user

short form: -u; type: string

User for login if not current user.
:::

::: option
\--version

Show version and exit.
:::

::: option
\--victims

type: string; default: oldest

Which of the matching queries in each class will be killed. After
classes have been matched/filtered, this option specifies which of the
matching queries in each class will be killed (or printed, etc.). The
following values are possible:

oldest

> Only kill the single oldest query. This is to prevent killing queries
> that aren\'t really long-running, they\'re just long-waiting. This
> sorts matching queries by Time and kills the one with the highest Time
> value.

all

> Kill all queries in the class.

all-but-oldest

> Kill all but the oldest query. This is the inverse of the `oldest`
> value.
>
> This value can be used to prevent \"cache stampedes\", the condition
> where several identical queries are executed and create a backlog
> while the first query attempts to finish. Since all queries are
> identical, all but the first query are killed so that it can complete
> and populate the cache.
:::

::: option
\--wait-after-kill

type: time

Wait after killing a query, before looking for more to kill. The purpose
of this is to give blocked queries a chance to execute, so we don\'t
kill a query that\'s blocking a bunch of others, and then kill the
others immediately afterwards.
:::

::: option
\--wait-before-kill

type: time

Wait before killing a query. The purpose of this is to give
`--execute-command`{.interpreted-text role="option"} a chance to see the
matching query and gather other MariaDB or system information before
it\'s killed.
:::

## QUERY MATCHES

These options filter queries from their classes. If a query does not
match, it is removed from its class. The `--ignore` options take
precedence. The matches for command, db, host, etc. correspond to the
columns returned by SHOW PROCESSLIST: Command, db, Host, etc. All
pattern matches are case-sensitive by default, but they can be made
case-insensitive by specifying a regex pattern like `(?i-xsm:select)`.

See also \"GROUP, MATCH AND KILL\".

::: option
\--busy-time

type: time; group: Query Matches

Match queries that have been running for longer than this time. The
queries must be in Command=Query status. This matches a query\'s Time
value as reported by SHOW PROCESSLIST.
:::

::: option
\--idle-time

type: time; group: Query Matches

Match queries that have been idle/sleeping for longer than this time.
The queries must be in Command=Sleep status. This matches a query\'s
Time value as reported by SHOW PROCESSLIST.
:::

::: option
\--ignore-command

type: string; group: Query Matches

Ignore queries whose Command matches this Perl regex.

See `--match-command`{.interpreted-text role="option"}.
:::

::: option
\--ignore-db

type: string; group: Query Matches

Ignore queries whose db (database) matches this Perl regex.

See `--match-db`{.interpreted-text role="option"}.
:::

::: option
\--ignore-host

type: string; group: Query Matches

Ignore queries whose Host matches this Perl regex.

See `--match-host`{.interpreted-text role="option"}.
:::

::: option
\--ignore-info

type: string; group: Query Matches

Ignore queries whose Info (query) matches this Perl regex.

See `--match-info`{.interpreted-text role="option"}.
:::

::: option
\--\[no\]ignore-self

default: yes; group: Query Matches

Don\'t kill `mariadb-kill`{.interpreted-text role="program"}\'s own
connection.
:::

::: option
\--ignore-state

type: string; group: Query Matches; default: Locked

Ignore queries whose State matches this Perl regex. The default is to
keep threads from being killed if they are locked waiting for another
thread.

See `--match-state`{.interpreted-text role="option"}.
:::

::: option
\--ignore-user

type: string; group: Query Matches

Ignore queries whose user matches this Perl regex.

See `--match-user`{.interpreted-text role="option"}.
:::

::: option
\--match-all

group: Query Matches

Match all queries that are not ignored. If no ignore options are
specified, then every query matches (except replication threads, unless
`--replication-threads`{.interpreted-text role="option"} is also
specified). This option allows you to specify negative matches, i.e.
\"match every query *except*\...\" where the exceptions are defined by
specifying various `--ignore` options.

This option is *not* the same as `--victims`{.interpreted-text
role="option"} `all`. This option matches all queries within a class,
whereas `--victims`{.interpreted-text role="option"} `all` specifies
that all matching queries in a class (however they matched) will be
killed. Normally, however, the two are used together because if, for
example, you specify `--victims`{.interpreted-text role="option"}
`oldest`, then although all queries may match, only the oldest will be
killed.
:::

::: option
\--match-command

type: string; group: Query Matches

Match only queries whose Command matches this Perl regex.

Common Command values are:

``` bash
Query
Sleep
Binlog Dump
Connect
Delayed insert
Execute
Fetch
Init DB
Kill
Prepare
Processlist
Quit
Reset stmt
Table Dump
```

See <https://mariadb.com/kb/en/library/thread-command-values/> for a
full list and description of Command values.
:::

::: option
\--match-db

type: string; group: Query Matches

Match only queries whose db (database) matches this Perl regex.
:::

::: option
\--match-host

type: string; group: Query Matches

Match only queries whose Host matches this Perl regex.

The Host value often time includes the port like \"host:port\".
:::

::: option
\--match-info

type: string; group: Query Matches

Match only queries whose Info (query) matches this Perl regex.

The Info column of the processlist shows the query that is being
executed or NULL if no query is being executed.
:::

::: option
\--match-state

type: string; group: Query Matches

Match only queries whose State matches this Perl regex.

Common State values are:

``` bash
Locked
login
copy to tmp table
Copying to tmp table
Copying to tmp table on disk
Creating tmp table
executing
Reading from net
Sending data
Sorting for order
Sorting result
Table lock
Updating
```

See <https://mariadb.com/kb/en/library/general-thread-states/> for a
full list and description of State values.
:::

::: option
\--match-user

type: string; group: Query Matches

Match only queries whose User matches this Perl regex.
:::

::: option
\--replication-threads

group: Query Matches

Allow matching and killing replication threads.

By default, matches do not apply to replication threads; i.e.
replication threads are completely ignored. Specifying this option
allows matches to match (and potentially kill) replication threads on
masters and slaves.
:::

::: option
\--test-matching

type: array; group: Query Matches

Files with processlist snapshots to test matching options against. Since
the matching options can be complex, you can save snapshots of
processlist in files, then test matching options against queries in
those files.

This option disables `--run-time`{.interpreted-text role="option"},
`--interval`{.interpreted-text role="option"}, and
`--[no]ignore-self`{.interpreted-text role="option"}.
:::

## CLASS MATCHES

These matches apply to entire query classes. Classes are created by
specifying the `--group-by`{.interpreted-text role="option"} option,
else all queries are members of a single, default class.

See also \"GROUP, MATCH AND KILL\".

::: option
\--any-busy-time

type: time; group: Class Matches

Match query class if any query has been running for longer than this
time. \"Longer than\" means that if you specify `10`, for example, the
class will only match if there\'s at least one query that has been
running for greater than 10 seconds.

See `--each-busy-time`{.interpreted-text role="option"} for more
details.
:::

::: option
\--each-busy-time

type: time; group: Class Matches

Match query class if each query has been running for longer than this
time. \"Longer than\" means that if you specify `10`, for example, the
class will only match if each and every query has been running for
greater than 10 seconds.

See also `--any-busy-time`{.interpreted-text role="option"} (to match a
class if ANY query has been running longer than the specified time) and
`--busy-time`{.interpreted-text role="option"}.
:::

::: option
\--query-count

type: int; group: Class Matches

Match query class if it has at least this many queries. When queries are
grouped into classes by specifying `--group-by`{.interpreted-text
role="option"}, this option causes matches to apply only to classes with
at least this many queries. If `--group-by`{.interpreted-text
role="option"} is not specified then this option causes matches to apply
only if there are at least this many queries in the entire SHOW
PROCESSLIST.
:::

::: option
\--verbose

short form: -v

Print information to STDOUT about what is being done.
:::

## ACTIONS

These actions are taken for every matching query from all classes. The
actions are taken in this order: `--print`{.interpreted-text
role="option"}, `--execute-command`{.interpreted-text role="option"},
`--kill"/"--kill-query`{.interpreted-text role="option"}. This order
allows `--execute-command`{.interpreted-text role="option"} to see the
output of `--print`{.interpreted-text role="option"} and the query
before `--kill"/"--kill-query`{.interpreted-text role="option"}. This
may be helpful because `mariadb-kill`{.interpreted-text role="program"}
does not pass any information to `--execute-command`{.interpreted-text
role="option"}.

See also \"GROUP, MATCH AND KILL\".

::: option
\--execute-command

type: string; group: Actions

Execute this command when a query matches.

After the command is executed, `mariadb-kill`{.interpreted-text
role="program"} has no control over it, so the command is responsible
for its own info gathering, logging, interval, etc. The command is
executed each time a query matches, so be careful that the command
behaves well when multiple instances are ran. No information from
`mariadb-kill`{.interpreted-text role="program"} is passed to the
command.

See also `--wait-before-kill`{.interpreted-text role="option"}.
:::

::: option
\--kill

group: Actions

Kill the connection for matching queries.

This option makes `mariadb-kill`{.interpreted-text role="program"} kill
the connections (a.k.a. processes, threads) that have matching queries.
Use `--kill-query`{.interpreted-text role="option"} if you only want to
kill individual queries and not their connections.

Unless `--print`{.interpreted-text role="option"} is also given, no
other information is printed that shows that
`mariadb-kill`{.interpreted-text role="program"} matched and killed a
query.

See also `--wait-before-kill`{.interpreted-text role="option"} and
`--wait-after-kill`{.interpreted-text role="option"}.
:::

::: option
\--kill-busy-commands

type: string; default: Query

group: Actions

Comma sepatated list of commands that will be watched/killed if they ran
for more than `--busy-time`{.interpreted-text role="option"} seconds.
Default: `Query`

By default, `--busy-time`{.interpreted-text role="option"} kills only
`Query` commands but in some cases, it is needed to make
`--busy-time`{.interpreted-text role="option"} to watch and kill other
commands. For example, a prepared statement execution command is
`Execute` instead of `Query`. In this case, specifying
`--kill-busy-commands=Query,Execute` will also kill the prepared
stamente execution.
:::

::: option
\--kill-query

group: Actions

Kill matching queries.

This option makes `mariadb-kill`{.interpreted-text role="program"} kill
matching queries. This requires MariaDB 5.0 or newer. Unlike
`--kill`{.interpreted-text role="option"} which kills the connection for
matching queries, this option only kills the query, not its connection.
:::

::: option
\--print

group: Actions

Print a KILL statement for matching queries; does not actually kill
queries.

If you just want to see which queries match and would be killed without
actually killing them, specify `--print`{.interpreted-text
role="option"}. To both kill and print matching queries, specify both
`--kill`{.interpreted-text role="option"} and
`--print`{.interpreted-text role="option"}.
:::

## DSN OPTIONS

These DSN options are used to create a DSN. Each option is given like
`option=value`. The options are case-sensitive, so P and p are not the
same option. There cannot be whitespace before or after the `=` and if
the value contains whitespace it must be quoted. DSN options are
comma-separated. See the percona-toolkit manpage for full details.

-   A

> dsn: charset; copy: yes
>
> Default character set.

-   D

> dsn: database; copy: yes
>
> Default database.

-   F

> dsn: mysql_read_default_file; copy: yes
>
> Only read default options from the given file

-   h

> dsn: host; copy: yes
>
> Connect to host.

-   p

> dsn: password; copy: yes
>
> Password to use when connecting. If password contains commas they must
> be escaped with a backslash: \"exam,ple\"

-   P

> dsn: port; copy: yes
>
> Port number to use for connection.

-   S

> dsn: mariadb_socket; copy: yes
>
> Socket file to use for connection.

-   u

> dsn: user; copy: yes
>
> User for login if not current user.

-   t

> Table to log actions in, if passed through \--log-dsn.

## ENVIRONMENT

The environment variable `PTDEBUG` enables verbose debugging output to
STDERR. To enable debugging and capture all output to a file, run the
tool like:

``` bash
PTDEBUG=1 mariadb-kill ... > FILE 2>&1
```

Be careful: debugging output is voluminous and can generate several
megabytes of output.

## SYSTEM REQUIREMENTS

You need Perl, DBI, DBD::mysql, and some core packages that ought to be
installed in any reasonably new version of Perl.

## AUTHORS

Cole Busby, Baron Schwartz and Daniel Nichter

## ABOUT THIS MARIADB TOOL

This tool is part of MariaDB client tools. This MariaDB Tool was forked
from Percona Toolkit\'s pt-stalk in August, 2019. Percona Toolkit was
forked from two projects in June, 2011: Maatkit and Aspersa. Those
projects were created by Baron Schwartz and primarily developed by him
and Daniel Nichter.

## COPYRIGHT, LICENSE, AND WARRANTY

This program is copyright 2019-2021 MariaDB Corporation and/or its
affiliates, 2011-2018 Percona LLC and/or its affiliates, 2010-2011 Baron
Schwartz.

THIS PROGRAM IS PROVIDED \"AS IS\" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, version 2; OR the Perl Artistic License. On
UNIX and similar systems, you can issue \`man perlgpl\' or \`man
perlartistic\' to read these licenses.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.

## VERSION

`mariadb-kill`{.interpreted-text role="program"} 6.0.0rc
