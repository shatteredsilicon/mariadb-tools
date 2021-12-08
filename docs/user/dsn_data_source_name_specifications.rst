
*************************************
DSN (DATA SOURCE NAME) SPECIFICATIONS
*************************************

MariaDB Tools use DSNs to specify how to create a DBD connection to
a MariaDB server.  A DSN is a comma-separated string of \ ``key=value``\  parts, like:

.. code-block:: perl

   h=host1,P=3306,u=bob

The standard key parts are shown below, but some tools add additional key
parts.  See each tool's documentation for details.

Some tools do not use DSNs but still connect to MariaDB using options like
\ ``--host``\ , \ ``--user``\ , and \ ``--password``\ .  Such tools uses these options to
create a DSN automatically, behind the scenes.

Other tools uses both DSNs and options like the ones above.  The options
provide defaults for all DSNs that do not specify the option's corresponding
key part.  For example, if DSN \ ``h=host1``\  and option \ ``--port=12345``\  are
specified, then the tool automatically adds \ ``P=12345``\  to DSN.

ESCAPING VALUES
===============

DSNs are usually specified on the command line, so shell quoting and escaping
must be taken into account.  Special characters, like asterisk (\ ``\*``\ ), need
to be quoted and/or escaped properly to be passed as literal characters in
DSN values.

Since DSN parts are separated by commas, literal commas in DSN values must
be escaped with a single backslash (\ ``\``\ ).  And since a backslash is
the escape character for most shells, two backslashes are required to pass
a literal backslash.  For example, if the username is literally \ ``my,name``\ ,
it must be specified as \ ``my\\,name``\  on most shells.  This applies to DSNs
and DSN-related options like \ ``--user``\ .

KEY PARTS
=========

Many of the tools add more parts to DSNs for special purposes, and sometimes
override parts to make them do something slightly different.  However, all the
tools support at least the following:

A
 
 Default character set for the connection (\ ``SET NAMES``\ ).
 
 Enables character set settings in Perl and MariaDB.  If the value is \ ``utf8``\ ,
 sets Perl's binmode on STDOUT to utf8, passes the \ ``mysql_enable_utf8``\  option
 to DBD::mysql, and runs \ ``SET NAMES 'utf8'``\  after connecting to MariaDB.  Other
 values set binmode on STDOUT without the utf8 layer and run \ ``SET NAMES``\  after
 connecting to MariaDB.
 
 Unfortunately, there is no way from within Perl itself to specify the client
 library's character set.  \ ``SET NAMES``\  only affects the server; if the client
 library's settings don't match, there could be problems.  You can use the
 defaults file to specify the client library's character set, however.  See the
 description of the F part below.
 

D
 
 Default database to use when connecting.  Tools may \ ``USE``\  a different
 databases while running.
 

F
 
 Defaults file for the MariaDB client library (the C client library used by
 DBD::mysql, \ *not MariaDB Tools itself*\ ).  All tools all read the
 \ ``[client]``\  section within the defaults file.  If you omit this, the standard
 defaults files will be read in the usual order.  "Standard" varies from system
 to system, because the filenames to read are compiled into the client library.
 On Debian systems, for example, it's usually \ ``/etc/mysql/server.cnf``\  then
 \ ``~/.my.cnf``\ .  If you place the following in \ ``~/.my.cnf``\ , you won't have
 to specify your MariaDB username and password on the command line:
 
 
 .. code-block:: perl
 
    [client]
    user=your_user_name
    pass=secret
 
 
 Omitting the F part is usually the right thing to do.  As long as you have
 configured your \ ``~/.my.cnf``\  correctly, that will result in tools connecting
 automatically without needing a username or password.
 
 You can also specify a default character set in the defaults file.  Unlike the
 "A" part described above, this will actually instruct the client library
 (DBD::mysql) to change the character set it uses internally, which cannot be
 accomplished any other way.
 

h
 
 MariaDB hostname or IP address to connect to.
 

L
 
 Explicitly enable LOAD DATA LOCAL INFILE.
 
 For some reason, some vendors compile libmysql without the
 --enable-local-infile option, which disables the statement.  This can
 lead to weird situations, like the server allowing LOCAL INFILE, but 
 the client throwing exceptions if it's used.
 
 However, as long as the server allows LOAD DATA, clients can easily
 re-enable it; see `https://dev.mysql.com/doc/refman/5.0/en/load-data-local.html <https://dev.mysql.com/doc/refman/5.0/en/load-data-local.html>`_
 and `http://search.cpan.org/~capttofu/DBD-mysql/lib/DBD/mysql.pm <http://search.cpan.org/~capttofu/DBD-mysql/lib/DBD/mysql.pm>`_.
 This option does exactly that.
 

p
 
 MariaDB password to use when connecting.
 

P
 
 Port number to use for the connection.  Note that the usual special-case
 behaviors apply: if you specify \ ``localhost``\  as your hostname on Unix systems,
 the connection actually uses a socket file, not a TCP/IP connection, and thus
 ignores the port.
 

S
 
 MariaDB socket file to use for the connection (on Unix systems).
 

u
 
 MariaDB username to use when connecting, if not current system user.
 

BAREWORD
========

Many of the tools will let you specify a DSN as a single word, without any
\ ``key=value``\  syntax.  This is called a 'bareword'.  How this is handled is
tool-specific, but it is usually interpreted as the "h" part.  The tool's
\ ``--help``\  output will tell you the behavior for that tool.

PROPAGATION
===========

Many tools will let you propagate values from one DSN to the next, so you don't
have to specify all the parts for each DSN.  For example, if you want to specify
a username and password for each DSN, you can connect to three hosts as follows:

.. code-block:: perl

  h=host1,u=fred,p=wilma host2 host3

This is tool-specific.

