::: program
mariadb-archiver
:::

# `mariadb-archiver`{.interpreted-text role="program"}

## NAME

`mariadb-archiver`{.interpreted-text role="program"} - Archive rows from
a MariaDB table into another table or a file.

## SYNOPSIS

### Usage

    mariadb-archiver [OPTIONS] --source DSN --where WHERE

`mariadb-archiver`{.interpreted-text role="program"} nibbles records
from a MariaDB table. The \--source and \--dest arguments use DSN
syntax; if COPY is yes, \--dest defaults to the key\'s value from
\--source.

### Examples

Archive all rows from oltp_server to olap_server and to a file:

``` bash
mariadb-archiver --source h=oltp_server,D=test,t=tbl --dest h=olap_server \
  --file '/var/log/archive/%Y-%m-%d-%D.%t'                           \
  --where "1=1" --limit 1000 --commit-each
```

Purge (delete) orphan rows from child table:

``` bash
mariadb-archiver --source h=host,D=db,t=child --purge \
  --where 'NOT EXISTS(SELECT * FROM parent WHERE col=child.col)'
```

## RISKS

`mariadb-archiver`{.interpreted-text role="program"} is mature, proven
in the real world, and well tested, but all database tools can pose a
risk to the system and the database server. Before using this tool,
please:

-   Read the tool\'s documentation
-   Review the tool\'s known \"BUGS\"
-   Test the tool on a non-production server
-   Backup your production server and verify the backups

## DESCRIPTION

`mariadb-archiver`{.interpreted-text role="program"} is the tool I use
to archive tables as described in <http://tinyurl.com/mysql-archiving>.
The goal is a low-impact, forward-only job to nibble old data out of the
table without impacting OLTP queries much. You can insert the data into
another table, which need not be on the same server. You can also write
it to a file in a format suitable for LOAD DATA INFILE. Or you can do
neither, in which case it\'s just an incremental DELETE.

`mariadb-archiver`{.interpreted-text role="program"} is extensible via a
plugin mechanism. You can inject your own code to add advanced archiving
logic that could be useful for archiving dependent data, applying
complex business rules, or building a data warehouse during the
archiving process.

You need to choose values carefully for some options. The most important
are `--limit`{.interpreted-text role="option"},
`--retries`{.interpreted-text role="option"}, and
`--txn-size`{.interpreted-text role="option"}.

The strategy is to find the first row(s), then scan some index
forward-only to find more rows efficiently. Each subsequent query should
not scan the entire table; it should seek into the index, then scan
until it finds more archivable rows. Specifying the index with the \'i\'
part of the `--source`{.interpreted-text role="option"} argument can be
crucial for this; use `--dry-run`{.interpreted-text role="option"} to
examine the generated queries and be sure to EXPLAIN them to see if they
are efficient (most of the time you probably want to scan the PRIMARY
key, which is the default). Even better, examine the difference in the
Handler status counters before and after running the query, and make
sure it is not scanning the whole table every query.

You can disable the seek-then-scan optimizations partially or wholly
with `--no-ascend`{.interpreted-text role="option"} and
`--ascend-first`{.interpreted-text role="option"}. Sometimes this may be
more efficient for multi-column keys. Be aware that
`mariadb-archiver`{.interpreted-text role="program"} is built to start
at the beginning of the index it chooses and scan it forward-only. This
might result in long table scans if you\'re trying to nibble from the
end of the table by an index other than the one it prefers. See
`--source`{.interpreted-text role="option"} and read the documentation
on the `i` part if this applies to you.

## MariaDB Galera Cluster

`mariadb-archiver`{.interpreted-text role="program"} works with MariaDB
Galera Cluster 10.1 and newer, but there are three limitations you
should consider before archiving on a cluster:

Error on commit

> `mariadb-archiver`{.interpreted-text role="program"} does not check
> for error when it commits transactions. Commits on Galera can fail,
> but the tool does not yet check for or retry the transaction when this
> happens. If it happens, the tool will die.

MyISAM tables

> Archiving MyISAM tables works, but MyISAM support in Galera is still
> experimental at the time of this release. There are several known bugs
> with Galera, MyISAM tables, and `AUTO_INCREMENT` columns. Therefore,
> you must ensure that archiving will not directly or indirectly result
> in the use of default `AUTO_INCREMENT` values for a MyISAM table. For
> example, this happens with `--dest`{.interpreted-text role="option"}
> if `--columns`{.interpreted-text role="option"} is used and the
> `AUTO_INCREMENT` column is not included. The tool does not check for
> this!

Non-cluster options

> Certain options may or may not work. For example, if a cluster node is
> not also a slave, then `--check-slave-lag`{.interpreted-text
> role="option"} does not work. And since Galera tables are usually
> InnoDB, but InnoDB doesn\'t support `INSERT DELAYED`, then
> `--delayed-insert`{.interpreted-text role="option"} does not work.
> Other options may also not work, but the tool does not check them,
> therefore you should test archiving on a test cluster before archiving
> on your real cluster.

## OUTPUT

If you specify `--progress`{.interpreted-text role="option"}, the output
is a header row, plus status output at intervals. Each row in the status
output lists the current date and time, how many seconds
`mariadb-archiver`{.interpreted-text role="program"} has been running,
and how many rows it has archived.

If you specify `--statistics`{.interpreted-text role="option"},
`mariadb-archiver`{.interpreted-text role="program"} outputs timing and
other information to help you identify which part of your archiving
process takes the most time.

## ERROR-HANDLING

`mariadb-archiver`{.interpreted-text role="program"} tries to catch
signals and exit gracefully; for example, if you send it SIGTERM (Ctrl-C
on UNIX-ish systems), it will catch the signal, print a message about
the signal, and exit fairly normally. It will not execute
`--analyze`{.interpreted-text role="option"} or
`--optimize`{.interpreted-text role="option"}, because these may take a
long time to finish. It will run all other code normally, including
calling after_finish() on any plugins (see \"EXTENDING\").

In other words, a signal, if caught, will break out of the main
archiving loop and skip optimize/analyze.

## OPTIONS

Specify at least one of `--dest`{.interpreted-text role="option"},
`--file`{.interpreted-text role="option"}, or
`--purge`{.interpreted-text role="option"}.

`--ignore`{.interpreted-text role="option"} and
`--replace`{.interpreted-text role="option"} are mutually exclusive.

`--txn-size`{.interpreted-text role="option"} and
`--commit-each`{.interpreted-text role="option"} are mutually exclusive.

`--low-priority-insert`{.interpreted-text role="option"} and
`--delayed-insert`{.interpreted-text role="option"} are mutually
exclusive.

`--share-lock`{.interpreted-text role="option"} and
`--for-update`{.interpreted-text role="option"} are mutually exclusive.

`--analyze`{.interpreted-text role="option"} and
`--optimize`{.interpreted-text role="option"} are mutually exclusive.

`--no-ascend`{.interpreted-text role="option"} and
`--no-delete`{.interpreted-text role="option"} are mutually exclusive.

DSN values in `--dest`{.interpreted-text role="option"} default to
values from `--source`{.interpreted-text role="option"} if COPY is yes.

::: option
\--analyze

type: string

Run ANALYZE TABLE afterwards on `--source`{.interpreted-text
role="option"} and/or `--dest`{.interpreted-text role="option"}.

Runs ANALYZE TABLE after finishing. The argument is an arbitrary string.
If it contains the letter \'s\', the source will be analyzed. If it
contains \'d\', the destination will be analyzed. You can specify either
or both. For example, the following will analyze both:

``` bash
--analyze=ds
```

See <https://mariadb.com/kb/en/library/analyze-table/> for details on
ANALYZE TABLE.
:::

::: option
\--ascend-first

Ascend only first column of index.

If you do want to use the ascending index optimization (see
`--no-ascend`{.interpreted-text role="option"}), but do not want to
incur the overhead of ascending a large multi-column index, you can use
this option to tell `mariadb-archiver`{.interpreted-text role="program"}
to ascend only the leftmost column of the index. This can provide a
significant performance boost over not ascending the index at all, while
avoiding the cost of ascending the whole index.

See \"EXTENDING\" for a discussion of how this interacts with plugins.
:::

::: option
\--ask-pass

Prompt for a password when connecting to MariaDB.
:::

::: option
\--buffer

Buffer output to `--file`{.interpreted-text role="option"} and flush at
commit.

Disables autoflushing to `--file`{.interpreted-text role="option"} and
flushes `--file`{.interpreted-text role="option"} to disk only when a
transaction commits. This typically means the file is block-flushed by
the operating system, so there may be some implicit flushes to disk
between commits as well. The default is to flush
`--file`{.interpreted-text role="option"} to disk after every row.

The danger is that a crash might cause lost data.

The performance increase I have seen from using
`--buffer`{.interpreted-text role="option"} is around 5 to 15 percent.
Your mileage may vary.
:::

::: option
\--bulk-delete

Delete each chunk with a single statement (implies
`--commit-each`{.interpreted-text role="option"}).

Delete each chunk of rows in bulk with a single `DELETE` statement. The
statement deletes every row between the first and last row of the chunk,
inclusive. It implies `--commit-each`{.interpreted-text role="option"},
since it would be a bad idea to `INSERT` rows one at a time and commit
them before the bulk `DELETE`.

The normal method is to delete every row by its primary key. Bulk
deletes might be a lot faster. **They also might not be faster** if you
have a complex `WHERE` clause.

This option completely defers all `DELETE` processing until the chunk of
rows is finished. If you have a plugin on the source, its
`before_delete` method will not be called. Instead, its
`before_bulk_delete` method is called later.

**WARNING**: if you have a plugin on the source that sometimes doesn\'t
return true from `is_archivable()`, you should use this option only if
you understand what it does. If the plugin instructs
`mariadb-archiver`{.interpreted-text role="program"} not to archive a
row, it will still be deleted by the bulk delete!
:::

::: option
\--\[no\]bulk-delete-limit

default: yes

Add `--limit`{.interpreted-text role="option"} to
`--bulk-delete`{.interpreted-text role="option"} statement.

This is an advanced option and you should not disable it unless you know
what you are doing and why! By default,
`--bulk-delete`{.interpreted-text role="option"} appends a
`--limit`{.interpreted-text role="option"} clause to the bulk delete SQL
statement. In certain cases, this clause can be omitted by specifying
`--no-bulk-delete-limit`. `--limit`{.interpreted-text role="option"}
must still be specified.
:::

::: option
\--bulk-insert

Insert each chunk with LOAD DATA INFILE (implies
`--bulk-delete`{.interpreted-text role="option"}
`--commit-each`{.interpreted-text role="option"}).

Insert each chunk of rows with `LOAD DATA LOCAL INFILE`. This may be
much faster than inserting a row at a time with `INSERT` statements. It
is implemented by creating a temporary file for each chunk of rows, and
writing the rows to this file instead of inserting them. When the chunk
is finished, it uploads the rows.

To protect the safety of your data, this option forces bulk deletes to
be used. It would be unsafe to delete each row as it is found, before
inserting the rows into the destination first. Forcing bulk deletes
guarantees that the deletion waits until the insertion is successful.

The `--low-priority-insert`{.interpreted-text role="option"},
`--replace`{.interpreted-text role="option"}, and
`--ignore`{.interpreted-text role="option"} options work with this
option, but `--delayed-insert`{.interpreted-text role="option"} does
not.

If `LOAD DATA LOCAL INFILE` throws an error in the lines of
`The used command is not allowed with this MariaDB version`, refer to
the documentation for the `L` DSN option.
:::

::: option
\--channel

type: string

Channel name used when connected to a server using replication channels.
Suppose you have two masters, master_a at port 12345, master_b at port
1236 and a slave connected to both masters using channels chan_master_a
and chan_master_b. If you want to run
`mariadb-archiver`{.interpreted-text role="program"} to syncronize the
slave against master_a, `mariadb-archiver`{.interpreted-text
role="program"} won\'t be able to determine what\'s the correct master
since SHOW SLAVE STATUS will return 2 rows. In this case, you can use
\--channel=chan_master_a to specify the channel name to use in the SHOW
SLAVE STATUS command.
:::

::: option
\--charset

short form: -A; type: string

Default character set. If the value is utf8, sets Perl\'s binmode on
STDOUT to utf8, passes the mysql_enable_utf8 option to DBD::mysql, and
runs SET NAMES UTF8 after connecting to MariaDB. Any other value sets
binmode on STDOUT without the utf8 layer, and runs SET NAMES after
connecting to MariaDB.

Note that only charsets as known by MariaDB are recognized; So for
example, \"UTF8\" will work, but \"UTF-8\" will not.

See also `--[no]check-charset`{.interpreted-text role="option"}.
:::

::: option
\--\[no\]check-charset

default: yes

Ensure connection and table character sets are the same. Disabling this
check may cause text to be erroneously converted from one character set
to another (usually from utf8 to latin1) which may cause data loss or
mojibake. Disabling this check may be useful or necessary when character
set conversions are intended.
:::

::: option
\--\[no\]check-columns

default: yes

Ensure `--source`{.interpreted-text role="option"} and
`--dest`{.interpreted-text role="option"} have same columns.

Enabled by default; causes `mariadb-archiver`{.interpreted-text
role="program"} to check that the source and destination tables have the
same columns. It does not check column order, data type, etc. It just
checks that all columns in the source exist in the destination and vice
versa. If there are any differences,
`mariadb-archiver`{.interpreted-text role="program"} will exit with an
error.

To disable this check, specify \--no-check-columns.
:::

::: option
\--check-interval

type: time; default: 1s

If `--check-slave-lag`{.interpreted-text role="option"} is given, this defines how long the tool pauses each

:   time it discovers that a slave is lagging. This check is performed
    every 100 rows.
:::

::: option
\--check-slave-lag

type: string; repeatable: yes

Pause archiving until the specified DSN\'s slave lag is less than
`--max-lag`{.interpreted-text role="option"}. This option can be
specified multiple times for checking more than one slave.
:::

::: option
\--columns

short form: -c; type: array

Comma-separated list of columns to archive.

Specify a comma-separated list of columns to fetch, write to the file,
and insert into the destination table. If specified,
`mariadb-archiver`{.interpreted-text role="program"} ignores other
columns unless it needs to add them to the `SELECT` statement for
ascending an index or deleting rows. It fetches and uses these extra
columns internally, but does not write them to the file or to the
destination table. It *does* pass them to plugins.

See also `--primary-key-only`{.interpreted-text role="option"}.
:::

::: option
\--commit-each

Commit each set of fetched and archived rows (disables
`--txn-size`{.interpreted-text role="option"}).

Commits transactions and flushes `--file`{.interpreted-text
role="option"} after each set of rows has been archived, before fetching
the next set of rows, and before sleeping if `--sleep`{.interpreted-text
role="option"} is specified. Disables `--txn-size`{.interpreted-text
role="option"}; use `--limit`{.interpreted-text role="option"} to
control the transaction size with `--commit-each`{.interpreted-text
role="option"}.

This option is useful as a shortcut to make `--limit`{.interpreted-text
role="option"} and `--txn-size`{.interpreted-text role="option"} the
same value, but more importantly it avoids transactions being held open
while searching for more rows. For example, imagine you are archiving
old rows from the beginning of a very large table, with
`--limit`{.interpreted-text role="option"} 1000 and
`--txn-size`{.interpreted-text role="option"} 1000. After some period of
finding and archiving 1000 rows at a time,
`mariadb-archiver`{.interpreted-text role="program"} finds the last 999
rows and archives them, then executes the next SELECT to find more rows.
This scans the rest of the table, but never finds any more rows. It has
held open a transaction for a very long time, only to determine it is
finished anyway. You can use `--commit-each`{.interpreted-text
role="option"} to avoid this.
:::

::: option
\--config

type: Array

Read this comma-separated list of config files; if specified, this must
be the first option on the command line.
:::

::: option
\--database

short form: -D; type: string

Connect to this database.
:::

::: option
\--delayed-insert

Add the DELAYED modifier to INSERT statements.

Adds the DELAYED modifier to INSERT or REPLACE statements. See
<https://mariadb.com/kb/en/library/insert/> for details.
:::

::: option
\--dest

type: DSN

DSN specifying the table to archive to.

This item specifies a table into which
`mariadb-archiver`{.interpreted-text role="program"} will insert rows
archived from `--source`{.interpreted-text role="option"}. It uses the
same key=val argument format as `--source`{.interpreted-text
role="option"}. Most missing values default to the same values as
`--source`{.interpreted-text role="option"}, so you don\'t have to
repeat options that are the same in `--source`{.interpreted-text
role="option"} and `--dest`{.interpreted-text role="option"}. Use the
`--help`{.interpreted-text role="option"} option to see which values are
copied from `--source`{.interpreted-text role="option"}.

**WARNING**: Using a default options file (F) DSN option that defines a
socket for `--source`{.interpreted-text role="option"} causes
`mariadb-archiver`{.interpreted-text role="program"} to connect to
`--dest`{.interpreted-text role="option"} using that socket unless
another socket for `--dest`{.interpreted-text role="option"} is
specified. This means that `mariadb-archiver`{.interpreted-text
role="program"} may incorrectly connect to `--source`{.interpreted-text
role="option"} when it connects to `--dest`{.interpreted-text
role="option"}. For example:

``` bash
--source F=host1.cnf,D=db,t=tbl --dest h=host2
```

When `mariadb-archiver`{.interpreted-text role="program"} connects to
`--dest`{.interpreted-text role="option"}, host2, it will connect via
the `--source`{.interpreted-text role="option"}, host1, socket defined
in host1.cnf.
:::

::: option
\--dry-run

Print queries and exit without doing anything.

Causes `mariadb-archiver`{.interpreted-text role="program"} to exit
after printing the filename and SQL statements it will use.
:::

::: option
\--file

type: string

File to archive to, with DATE_FORMAT()-like formatting.

Filename to write archived rows to. A subset of MariaDB\'s DATE_FORMAT()
formatting codes are allowed in the filename, as follows:

``` bash
%d    Day of the month, numeric (01..31)
%H    Hour (00..23)
%i    Minutes, numeric (00..59)
%m    Month, numeric (01..12)
%s    Seconds (00..59)
%Y    Year, numeric, four digits
```

You can use the following extra format codes too:

``` bash
%D    Database name
%t    Table name
```

Example:

``` bash
--file '/var/log/archive/%Y-%m-%d-%D.%t'
```

The file\'s contents are in the same format used by SELECT INTO OUTFILE,
as documented in the MariaDB manual: rows terminated by newlines,
columns terminated by tabs, NULL characters are represented by N, and
special characters are escaped by . This lets you reload a file with
LOAD DATA INFILE\'s default settings.

If you want a column header at the top of the file, see
`--header`{.interpreted-text role="option"}. The file is auto-flushed by
default; see `--buffer`{.interpreted-text role="option"}.
:::

::: option
\--for-update

Adds the FOR UPDATE modifier to SELECT statements.

For details, see
<http://dev.mysql.com/doc/en/innodb-locking-reads.html>.
:::

::: option
\--header

Print column header at top of `--file`{.interpreted-text role="option"}.

Writes column names as the first line in the file given by
`--file`{.interpreted-text role="option"}. If the file exists, does not
write headers; this keeps the file loadable with LOAD DATA INFILE in
case you append more output to it.
:::

::: option
\--help

Show help and exit.
:::

::: option
\--high-priority-select

Adds the HIGH_PRIORITY modifier to SELECT statements.

See <https://mariadb.com/kb/en/library/select/> for details.
:::

::: option
\--host

short form: -h; type: string

Connect to host.
:::

::: option
\--ignore

Use IGNORE for INSERT statements.

Causes INSERTs into `--dest`{.interpreted-text role="option"} to be
INSERT IGNORE.
:::

::: option
\--limit

type: int; default: 1

Number of rows to fetch and archive per statement.

Limits the number of rows returned by the SELECT statements that
retrieve rows to archive. Default is one row. It may be more efficient
to increase the limit, but be careful if you are archiving sparsely,
skipping over many rows; this can potentially cause more contention with
other queries, depending on the storage engine, transaction isolation
level, and options such as `--for-update`{.interpreted-text
role="option"}.
:::

::: option
\--local

Do not write OPTIMIZE or ANALYZE queries to binlog.

Adds the NO_WRITE_TO_BINLOG modifier to ANALYZE and OPTIMIZE queries.
See `--analyze`{.interpreted-text role="option"} for details.
:::

::: option
\--low-priority-delete

Adds the LOW_PRIORITY modifier to DELETE statements.

See <https://mariadb.com/kb/en/library/delete/> for details.
:::

::: option
\--low-priority-insert

Adds the LOW_PRIORITY modifier to INSERT or REPLACE statements.

See <https://mariadb.com/kb/en/library/insert/> for details.
:::

::: option
\--max-flow-ctl

type: float

Somewhat similar to \--max-lag but for Galera clusters. Check average
time cluster spent pausing for Flow Control and make tool pause if it
goes over the percentage indicated in the option. Default is no Flow
Control checking. This option is available for Galera versions 5.6 or
higher.
:::

::: option
\--max-lag

type: time; default: 1s

Pause archiving if the slave given by
`--check-slave-lag`{.interpreted-text role="option"} lags.

This option causes `mariadb-archiver`{.interpreted-text role="program"}
to look at the slave every time it\'s about to fetch another row. If the
slave\'s lag is greater than the option\'s value, or if the slave isn\'t
running (so its lag is NULL), pt-table-checksum sleeps for
`--check-interval`{.interpreted-text role="option"} seconds and then
looks at the lag again. It repeats until the slave is caught up, then
proceeds to fetch and archive the row.

This option may eliminate the need for `--sleep`{.interpreted-text
role="option"} or `--sleep-coef`{.interpreted-text role="option"}.
:::

::: option
\--no-ascend

Do not use ascending index optimization.

The default ascending-index optimization causes
`mariadb-archiver`{.interpreted-text role="program"} to optimize
repeated `SELECT` queries so they seek into the index where the previous
query ended, then scan along it, rather than scanning from the beginning
of the table every time. This is enabled by default because it is
generally a good strategy for repeated accesses.

Large, multiple-column indexes may cause the WHERE clause to be complex
enough that this could actually be less efficient. Consider for example
a four-column PRIMARY KEY on (a, b, c, d). The WHERE clause to start
where the last query ended is as follows:

``` bash
WHERE (a > ?)
   OR (a = ? AND b > ?)
   OR (a = ? AND b = ? AND c > ?)
   OR (a = ? AND b = ? AND c = ? AND d >= ?)
```

Populating the placeholders with values uses memory and CPU, adds
network traffic and parsing overhead, and may make the query harder for
MariaDB to optimize. A four-column key isn\'t a big deal, but a
ten-column key in which every column allows `NULL` might be.

Ascending the index might not be necessary if you know you are simply
removing rows from the beginning of the table in chunks, but not leaving
any holes, so starting at the beginning of the table is actually the
most efficient thing to do.

See also `--ascend-first`{.interpreted-text role="option"}. See
\"EXTENDING\" for a discussion of how this interacts with plugins.
:::

::: option
\--no-delete

Do not delete archived rows.

Causes `mariadb-archiver`{.interpreted-text role="program"} not to
delete rows after processing them. This disallows
`--no-ascend`{.interpreted-text role="option"}, because enabling them
both would cause an infinite loop.

If there is a plugin on the source DSN, its `before_delete` method is
called anyway, even though `mariadb-archiver`{.interpreted-text
role="program"} will not execute the delete. See \"EXTENDING\" for more
on plugins.
:::

::: option
\--optimize

type: string

Run OPTIMIZE TABLE afterwards on `--source`{.interpreted-text
role="option"} and/or `--dest`{.interpreted-text role="option"}.

Runs OPTIMIZE TABLE after finishing. See `--analyze`{.interpreted-text
role="option"} for the option syntax and
<https://mariadb.com/kb/en/library/optimize-table/> for details on
OPTIMIZE TABLE.
:::

::: option
\--output-format

type: string

Used with `--file`{.interpreted-text role="option"} to specify the
output format.

Valid formats are:

:   dump: MariaDB dump format using tabs as field separator (default)
    csv : Dump rows using \',\' as separator and optionally enclosing
    fields by \'\"\'. This format is equivalent to FIELDS TERMINATED BY
    \',\' OPTIONALLY ENCLOSED BY \'\"\'.
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
\--plugin

type: string

Perl module name to use as a generic plugin.

Specify the Perl module name of a general-purpose plugin. It is
currently used only for statistics (see `--statistics`{.interpreted-text
role="option"}) and must have `new()` and a `statistics()` method.

The `new( src =` \$src, dst => \$dst, opts => \$o )> method gets the
source and destination DSNs, and their database connections, just like
the connection-specific plugins do. It also gets an OptionParser object
(`$o`) for accessing command-line options (example:
`$o-`get(\'purge\');>).

The `statistics(\%stats, $time)` method gets a hashref of the statistics
collected by the archiving job, and the time the whole job started.
:::

::: option
\--port

short form: -P; type: int

Port number to use for connection.
:::

::: option
\--primary-key-only

Primary key columns only.

A shortcut for specifying `--columns`{.interpreted-text role="option"}
with the primary key columns. This is an efficiency if you just want to
purge rows; it avoids fetching the entire row, when only the primary key
columns are needed for `DELETE` statements. See also
`--purge`{.interpreted-text role="option"}.
:::

::: option
\--progress

type: int

Print progress information every X rows.

Prints current time, elapsed time, and rows archived every X rows.
:::

::: option
\--purge

Purge instead of archiving; allows omitting `--file`{.interpreted-text
role="option"} and `--dest`{.interpreted-text role="option"}.

Allows archiving without a `--file`{.interpreted-text role="option"} or
`--dest`{.interpreted-text role="option"} argument, which is effectively
a purge since the rows are just deleted.

If you just want to purge rows, consider specifying the table\'s primary
key columns with `--primary-key-only`{.interpreted-text role="option"}.
This will prevent fetching all columns from the server for no reason.
:::

::: option
\--quick-delete

Adds the QUICK modifier to DELETE statements.

See <https://mariadb.com/kb/en/library/delete/> for details. As stated
in the documentation, in some cases it may be faster to use DELETE QUICK
followed by OPTIMIZE TABLE. You can use `--optimize`{.interpreted-text
role="option"} for this.
:::

::: option
\--quiet

short form: -q

Do not print any output, such as for `--statistics`{.interpreted-text
role="option"}.

Suppresses normal output, including the output of
`--statistics`{.interpreted-text role="option"}, but doesn\'t suppress
the output from `--why-quit`{.interpreted-text role="option"}.
:::

::: option
\--replace

Causes INSERTs into `--dest`{.interpreted-text role="option"} to be
written as REPLACE.
:::

::: option
\--retries

type: int; default: 1

Number of retries per timeout or deadlock.

Specifies the number of times `mariadb-archiver`{.interpreted-text
role="program"} should retry when there is an InnoDB lock wait timeout
or deadlock. When retries are exhausted,
`mariadb-archiver`{.interpreted-text role="program"} will exit with an
error.

Consider carefully what you want to happen when you are archiving
between a mixture of transactional and non-transactional storage
engines. The INSERT to `--dest`{.interpreted-text role="option"} and
DELETE from `--source`{.interpreted-text role="option"} are on separate
connections, so they do not actually participate in the same transaction
even if they\'re on the same server. However,
`mariadb-archiver`{.interpreted-text role="program"} implements simple
distributed transactions in code, so commits and rollbacks should happen
as desired across the two connections.

At this time I have not written any code to handle errors with
transactional storage engines other than InnoDB. Request that feature if
you need it.
:::

::: option
\--run-time

type: time

Time to run before exiting.

Optional suffix s=seconds, m=minutes, h=hours, d=days; if no suffix, s
is used.
:::

::: option
\--\[no\]safe-auto-increment

default: yes

Do not archive row with max AUTO_INCREMENT.

Adds an extra WHERE clause to prevent
`mariadb-archiver`{.interpreted-text role="program"} from removing the
newest row when ascending a single-column AUTO_INCREMENT key. This
guards against re-using AUTO_INCREMENT values if the server restarts,
and is enabled by default.

The extra WHERE clause contains the maximum value of the auto-increment
column as of the beginning of the archive or purge job. If new rows are
inserted while `mariadb-archiver`{.interpreted-text role="program"} is
running, it will not see them.
:::

::: option
\--sentinel

type: string; default: /tmp/mariadb-archiver-sentinel

Exit if this file exists.

The presence of the file specified by `--sentinel`{.interpreted-text
role="option"} will cause `mariadb-archiver`{.interpreted-text
role="program"} to stop archiving and exit. The default is
/tmp/mariadb-archiver-sentinel. You might find this handy to stop cron
jobs gracefully if necessary. See also `--stop`{.interpreted-text
role="option"}.
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
example, specifying `--set-vars wait_timeout=500` overrides the default
value of `10000`.

The tool prints a warning and continues if a variable cannot be set.
:::

::: option
\--share-lock

Adds the LOCK IN SHARE MODE modifier to SELECT statements.

See <http://dev.mysql.com/doc/en/innodb-locking-reads.html>.
:::

::: option
\--skip-foreign-key-checks

Disables foreign key checks with SET FOREIGN_KEY_CHECKS=0.
:::

::: option
\--sleep

type: int

Sleep time between fetches.

Specifies how long to sleep between SELECT statements. Default is not to
sleep at all. Transactions are NOT committed, and the
`--file`{.interpreted-text role="option"} file is NOT flushed, before
sleeping. See `--txn-size`{.interpreted-text role="option"} to control
that.

If `--commit-each`{.interpreted-text role="option"} is specified,
committing and flushing happens before sleeping.
:::

::: option
\--sleep-coef

type: float

Calculate `--sleep`{.interpreted-text role="option"} as a multiple of
the last SELECT time.

If this option is specified, `mariadb-archiver`{.interpreted-text
role="program"} will sleep for the query time of the last SELECT
multiplied by the specified coefficient.

This is a slightly more sophisticated way to throttle the SELECTs: sleep
a varying amount of time between each SELECT, depending on how long the
SELECTs are taking.
:::

::: option
\--socket

short form: -S; type: string

Socket file to use for connection.
:::

::: option
\--source

type: DSN

DSN specifying the table to archive from (required). This argument is a
DSN. See DSN OPTIONS for the syntax. Most options control how
`mariadb-archiver`{.interpreted-text role="program"} connects to
MariaDB, but there are some extended DSN options in this tool\'s syntax.
The D, t, and i options select a table to archive:

``` bash
--source h=my_server,D=my_database,t=my_tbl
```

The a option specifies the database to set as the connection\'s default
with USE. If the b option is true, it disables binary logging with
SQL_LOG_BIN. The m option specifies pluggable actions, which an external
Perl module can provide. The only required part is the table; other
parts may be read from various places in the environment (such as
options files).

The \'i\' part deserves special mention. This tells
`mariadb-archiver`{.interpreted-text role="program"} which index it
should scan to archive. This appears in a FORCE INDEX or USE INDEX hint
in the SELECT statements used to fetch archivable rows. If you don\'t
specify anything, `mariadb-archiver`{.interpreted-text role="program"}
will auto-discover a good index, preferring a `PRIMARY KEY` if one
exists. In my experience this usually works well, so most of the time
you can probably just omit the \'i\' part.

The index is used to optimize repeated accesses to the table;
`mariadb-archiver`{.interpreted-text role="program"} remembers the last
row it retrieves from each SELECT statement, and uses it to construct a
WHERE clause, using the columns in the specified index, that should
allow MariaDB to start the next SELECT where the last one ended, rather
than potentially scanning from the beginning of the table with each
successive SELECT. If you are using external plugins, please see
\"EXTENDING\" for a discussion of how they interact with ascending
indexes.

The \'a\' and \'b\' options allow you to control how statements flow
through the binary log. If you specify the \'b\' option, binary logging
will be disabled on the specified connection. If you specify the \'a\'
option, the connection will `USE` the specified database, which you can
use to prevent slaves from executing the binary log events with
`--replicate-ignore-db` options. These two options can be used as
different methods to achieve the same goal: archive data off the master,
but leave it on the slave. For example, you can run a purge job on the
master and prevent it from happening on the slave using your method of
choice.

**WARNING**: Using a default options file (F) DSN option that defines a
socket for `--source`{.interpreted-text role="option"} causes
`mariadb-archiver`{.interpreted-text role="program"} to connect to
`--dest`{.interpreted-text role="option"} using that socket unless
another socket for `--dest`{.interpreted-text role="option"} is
specified. This means that `mariadb-archiver`{.interpreted-text
role="program"} may incorrectly connect to `--source`{.interpreted-text
role="option"} when it is meant to connect to `--dest`{.interpreted-text
role="option"}. For example:

``` bash
--source F=host1.cnf,D=db,t=tbl --dest h=host2
```

When `mariadb-archiver`{.interpreted-text role="program"} connects to
`--dest`{.interpreted-text role="option"}, host2, it will connect via
the `--source`{.interpreted-text role="option"}, host1, socket defined
in host1.cnf.
:::

::: option
\--statistics

Collect and print timing statistics.

Causes `mariadb-archiver`{.interpreted-text role="program"} to collect
timing statistics about what it does. These statistics are available to
the plugin specified by `--plugin`{.interpreted-text role="option"}

Unless you specify `--quiet`{.interpreted-text role="option"},
`mariadb-archiver`{.interpreted-text role="program"} prints the
statistics when it exits. The statistics look like this:

``` bash
Started at 2008-07-18T07:18:53, ended at 2008-07-18T07:18:53
Source: D=db,t=table
SELECT 4
INSERT 4
DELETE 4
Action         Count       Time        Pct
commit            10     0.1079      88.27
select             5     0.0047       3.87
deleting           4     0.0028       2.29
inserting          4     0.0028       2.28
other              0     0.0040       3.29
```

The first two (or three) lines show times and the source and destination
tables. The next three lines show how many rows were fetched, inserted,
and deleted.

The remaining lines show counts and timing. The columns are the action,
the total number of times that action was timed, the total time it took,
and the percent of the program\'s total runtime. The rows are sorted in
order of descending total time. The last row is the rest of the time not
explicitly attributed to anything. Actions will vary depending on
command-line options.

If `--why-quit`{.interpreted-text role="option"} is given, its behavior
is changed slightly. This option causes it to print the reason for
exiting even when it\'s just because there are no more rows.

This option requires the standard Time::HiRes module, which is part of
core Perl on reasonably new Perl releases.
:::

::: option
\--stop

Stop running instances by creating the sentinel file.

Causes `mariadb-archiver`{.interpreted-text role="program"} to create
the sentinel file specified by `--sentinel`{.interpreted-text
role="option"} and exit. This should have the effect of stopping all
running instances which are watching the same sentinel file.
:::

::: option
\--txn-size

type: int; default: 1

Number of rows per transaction.

Specifies the size, in number of rows, of each transaction. Zero
disables transactions altogether. After
`mariadb-archiver`{.interpreted-text role="program"} processes this many
rows, it commits both the `--source`{.interpreted-text role="option"}
and the `--dest`{.interpreted-text role="option"} if given, and flushes
the file given by `--file`{.interpreted-text role="option"}.

This parameter is critical to performance. If you are archiving from a
live server, which for example is doing heavy OLTP work, you need to
choose a good balance between transaction size and commit overhead.
Larger transactions create the possibility of more lock contention and
deadlocks, but smaller transactions cause more frequent commit overhead,
which can be significant. To give an idea, on a small test set I worked
with while writing `mariadb-archiver`{.interpreted-text role="program"},
a value of 500 caused archiving to take about 2 seconds per 1000 rows on
an otherwise quiet MariaDB instance on my desktop machine, archiving to
disk and to another table. Disabling transactions with a value of zero,
which turns on autocommit, dropped performance to 38 seconds per
thousand rows.

If you are not archiving from or to a transactional storage engine, you
may want to disable transactions so `mariadb-archiver`{.interpreted-text
role="program"} doesn\'t try to commit.
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
\--where

type: string

WHERE clause to limit which rows to archive (required).

Specifies a WHERE clause to limit which rows are archived. Do not
include the word WHERE. You may need to quote the argument to prevent
your shell from interpreting it. For example:

``` bash
--where 'ts < current_date - interval 90 day'
```

For safety, `--where`{.interpreted-text role="option"} is required. If
you do not require a WHERE clause, use `--where`{.interpreted-text
role="option"} 1=1.
:::

::: option
\--why-quit

Print reason for exiting unless rows exhausted.

Causes `mariadb-archiver`{.interpreted-text role="program"} to print a
message if it exits for any reason other than running out of rows to
archive. This can be useful if you have a cron job with
`--run-time`{.interpreted-text role="option"} specified, for example,
and you want to be sure `mariadb-archiver`{.interpreted-text
role="program"} is finishing before running out of time.

If `--statistics`{.interpreted-text role="option"} is given, the
behavior is changed slightly. It will print the reason for exiting even
when it\'s just because there are no more rows.

This output prints even if `--quiet`{.interpreted-text role="option"} is
given. That\'s so you can put `mariadb-archiver`{.interpreted-text
role="program"} in a `cron` job and get an email if there\'s an abnormal
exit.
:::

## DSN OPTIONS

These DSN options are used to create a DSN. Each option is given like
`option=value`. The options are case-sensitive, so P and p are not the
same option. There cannot be whitespace before or after the `=` and if
the value contains whitespace it must be quoted. DSN options are
comma-separated. See the mariadb-tools manpage for full details.

-   a

> copy: no
>
> Database to USE when executing queries.

-   A

> dsn: charset; copy: yes
>
> Default character set.

-   b

> copy: no
>
> If true, disable binlog with SQL_LOG_BIN.

-   D

> dsn: database; copy: yes
>
> Database that contains the table.

-   F

> dsn: mysql_read_default_file; copy: yes
>
> Only read default options from the given file

-   h

> dsn: host; copy: yes
>
> Connect to host.

-   i

> copy: yes
>
> Index to use.

-   L

> copy: yes
>
> Explicitly enable LOAD DATA LOCAL INFILE.
>
> For some reason, some vendors compile libmysql without the
> \--enable-local-infile option, which disables the statement. This can
> lead to weird situations, like the server allowing LOCAL INFILE, but
> the client throwing exceptions if it\'s used.
>
> However, as long as the server allows LOAD DATA, clients can easily
> re-enable it; See
> <https://mariadb.com/kb/en/library/load-data-infile/> and
> <http://search.cpan.org/~capttofu/DBD-mysql/lib/DBD/mysql.pm>. This
> option does exactly that.
>
> Although we\'ve not found a case where turning this option leads to
> errors or differing behavior, to be on the safe side, this option is
> not on by default.

-   m

> copy: no
>
> Plugin module name.

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

> dsn: mysql_socket; copy: yes
>
> Socket file to use for connection.

-   t

> copy: yes
>
> Table to archive from/to.

-   u

> dsn: user; copy: yes
>
> User for login if not current user.

## EXTENDING

`mariadb-archiver`{.interpreted-text role="program"} is extensible by
plugging in external Perl modules to handle some logic and/or actions.
You can specify a module for both the `--source`{.interpreted-text
role="option"} and the `--dest`{.interpreted-text role="option"}, with
the \'m\' part of the specification. For example:

``` bash
--source D=test,t=test1,m=My::Module1 --dest m=My::Module2,t=test2
```

This will cause `mariadb-archiver`{.interpreted-text role="program"} to
load the My::Module1 and My::Module2 packages, create instances of them,
and then make calls to them during the archiving process.

You can also specify a plugin with `--plugin`{.interpreted-text
role="option"}.

The module must provide this interface:

new(dbh => \$dbh, db => \$db_name, tbl => \$tbl_name)

> The plugin\'s constructor is passed a reference to the database
> handle, the database name, and table name. The plugin is created just
> after `mariadb-archiver`{.interpreted-text role="program"} opens the
> connection, and before it examines the table given in the arguments.
> This gives the plugin a chance to create and populate temporary
> tables, or do other setup work.

before_begin(cols => \@cols, allcols => \@allcols)

> This method is called just before `mariadb-archiver`{.interpreted-text
> role="program"} begins iterating through rows and archiving them, but
> after it does all other setup work (examining table structures,
> designing SQL queries, and so on). This is the only time
> `mariadb-archiver`{.interpreted-text role="program"} tells the plugin
> column names for the rows it will pass the plugin while archiving.
>
> The `cols` argument is the column names the user requested to be
> archived, either by default or by the `--columns`{.interpreted-text
> role="option"} option. The `allcols` argument is the list of column
> names for every row `mariadb-archiver`{.interpreted-text
> role="program"} will fetch from the source table. It may fetch more
> columns than the user requested, because it needs some columns for its
> own use. When subsequent plugin functions receive a row, it is the
> full row containing all the extra columns, if any, added to the end.

is_archivable(row => \@row)

> This method is called for each row to determine whether it is
> archivable. This applies only to `--source`{.interpreted-text
> role="option"}. The argument is the row itself, as an arrayref. If the
> method returns true, the row will be archived; otherwise it will be
> skipped.
>
> Skipping a row adds complications for non-unique indexes. Normally
> `mariadb-archiver`{.interpreted-text role="program"} uses a WHERE
> clause designed to target the last processed row as the place to start
> the scan for the next SELECT statement. If you have skipped the row by
> returning false from is_archivable(),
> `mariadb-archiver`{.interpreted-text role="program"} could get into an
> infinite loop because the row still exists. Therefore, when you
> specify a plugin for the `--source`{.interpreted-text role="option"}
> argument, `mariadb-archiver`{.interpreted-text role="program"} will
> change its WHERE clause slightly. Instead of starting at \"greater
> than or equal to\" the last processed row, it will start \"strictly
> greater than.\" This will work fine on unique indexes such as primary
> keys, but it may skip rows (leave holes) on non-unique indexes or when
> ascending only the first column of an index.
>
> `mariadb-archiver`{.interpreted-text role="program"} will change the
> clause in the same way if you specify `--no-delete`{.interpreted-text
> role="option"}, because again an infinite loop is possible.
>
> If you specify the `--bulk-delete`{.interpreted-text role="option"}
> option and return false from this method,
> `mariadb-archiver`{.interpreted-text role="program"} may not do what
> you want. The row won\'t be archived, but it will be deleted, since
> bulk deletes operate on ranges of rows and don\'t know which rows the
> plugin selected to keep.
>
> If you specify the `--bulk-insert`{.interpreted-text role="option"}
> option, this method\'s return value will influence whether the row is
> written to the temporary file for the bulk insert, so bulk inserts
> will work as expected. However, bulk inserts require bulk deletes.

before_delete(row => \@row)

> This method is called for each row just before it is deleted. This
> applies only to `--source`{.interpreted-text role="option"}. This is a
> good place for you to handle dependencies, such as deleting things
> that are foreign-keyed to the row you are about to delete. You could
> also use this to recursively archive all dependent tables.
>
> This plugin method is called even if `--no-delete`{.interpreted-text
> role="option"} is given, but not if `--bulk-delete`{.interpreted-text
> role="option"} is given.

before_bulk_delete(first_row => \@row, last_row => \@row)

> This method is called just before a bulk delete is executed. It is
> similar to the `before_delete` method, except its arguments are the
> first and last row of the range to be deleted. It is called even if
> `--no-delete`{.interpreted-text role="option"} is given.

before_insert(row => \@row)

> This method is called for each row just before it is inserted. This
> applies only to `--dest`{.interpreted-text role="option"}. You could
> use this to insert the row into multiple tables, perhaps with an ON
> DUPLICATE KEY UPDATE clause to build summary tables in a data
> warehouse.
>
> This method is not called if `--bulk-insert`{.interpreted-text
> role="option"} is given.

before_bulk_insert(first_row => \@row, last_row => \@row, filename =>
bulk_insert_filename)

> This method is called just before a bulk insert is executed. It is
> similar to the `before_insert` method, except its arguments are the
> first and last row of the range to be deleted.

custom_sth(row => \@row, sql => \$sql)

> This method is called just before inserting the row, but after
> \"before_insert()\". It allows the plugin to specify different
> `INSERT` statement if desired. The return value (if any) should be a
> DBI statement handle. The `sql` parameter is the SQL text used to
> prepare the default `INSERT` statement. This method is not called if
> you specify `--bulk-insert`{.interpreted-text role="option"}.
>
> If no value is returned, the default `INSERT` statement handle is
> used.
>
> This method applies only to the plugin specified for
> `--dest`{.interpreted-text role="option"}, so if your plugin isn\'t
> doing what you expect, check that you\'ve specified it for the
> destination and not the source.

custom_sth_bulk(first_row => \@row, last_row => \@row, sql => \$sql,
filename => \$bulk_insert_filename)

> If you\'ve specified `--bulk-insert`{.interpreted-text role="option"},
> this method is called just before the bulk insert, but after
> \"before_bulk_insert()\", and the arguments are different.
>
> This method\'s return value etc is similar to the \"custom_sth()\"
> method.

after_finish()

> This method is called after `mariadb-archiver`{.interpreted-text
> role="program"} exits the archiving loop, commits all database
> handles, closes `--file`{.interpreted-text role="option"}, and prints
> the final statistics, but before `mariadb-archiver`{.interpreted-text
> role="program"} runs ANALYZE or OPTIMIZE (see
> `--analyze`{.interpreted-text role="option"} and
> `--optimize`{.interpreted-text role="option"}).

If you specify a plugin for both `--source`{.interpreted-text
role="option"} and `--dest`{.interpreted-text role="option"},
`mariadb-archiver`{.interpreted-text role="program"} constructs, calls
before_begin(), and calls after_finish() on the two plugins in the order
`--source`{.interpreted-text role="option"}, `--dest`{.interpreted-text
role="option"}.

`mariadb-archiver`{.interpreted-text role="program"} assumes it controls
transactions, and that the plugin will NOT commit or roll back the
database handle. The database handle passed to the plugin\'s constructor
is the same handle `mariadb-archiver`{.interpreted-text role="program"}
uses itself. Remember that `--source`{.interpreted-text role="option"}
and `--dest`{.interpreted-text role="option"} are separate handles.

A sample module might look like this:

``` bash
package My::Module;

sub new {
   my ( $class, %args ) = @_;
   return bless(\%args, $class);
}

sub before_begin {
   my ( $self, %args ) = @_;
   # Save column names for later
   $self->{cols} = $args{cols};
}

sub is_archivable {
   my ( $self, %args ) = @_;
   # Do some advanced logic with $args{row}
   return 1;
}

sub before_delete {} # Take no action
sub before_insert {} # Take no action
sub custom_sth    {} # Take no action
sub after_finish  {} # Take no action

1;
```

## ENVIRONMENT

The environment variable `PTDEBUG` enables verbose debugging output to
STDERR. To enable debugging and capture all output to a file, run the
tool like:

``` bash
PTDEBUG=1 mariadb-archiver ... > FILE 2>&1
```

Be careful: debugging output is voluminous and can generate several
megabytes of output.

## SYSTEM REQUIREMENTS

You need Perl, DBI, DBD::mysql, and some core packages that ought to be
installed in any reasonably new version of Perl.

## AUTHORS

Baron Schwartz

## ACKNOWLEDGMENTS

Andrew O\'Brien

## ABOUT THIS MARIADB TOOL

This tool is part of MariaDB client tools. This MariaDB Tool was forked
from Percona Toolkit\'s pt-archiver in August, 2019. Percona Toolkit was
forked from two projects in June, 2011: Maatkit and Aspersa. Those
projects were created by Baron Schwartz and primarily developed by him
and Daniel Nichter.

## COPYRIGHT, LICENSE, AND WARRANTY

This program is copyright 2019 MariaDB Corporation and/or its
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

`mariadb-archiver`{.interpreted-text role="program"} 6.0.0a
