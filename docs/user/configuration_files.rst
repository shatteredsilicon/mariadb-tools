
*******************
CONFIGURATION FILES
*******************

MariaDB Tools can read options from configuration files.  The
configuration file syntax is simple and direct, and bears some resemblances
to other MariaDB command-line client tools.  The configuration files all follow
the same conventions.

Internally, what actually happens is that the lines are read from the file and
then added as command-line options and arguments to the tool, so just
think of the configuration files as a way to write your command lines.

SYNTAX
======

The syntax of the configuration files is as follows:

\*
 
 Whitespace followed by a hash sign (#) signifies that the rest of the line is a
 comment.  This is deleted.  For example:
 

\*
 
 Whitespace is stripped from the beginning and end of all lines.
 

\*
 
 Empty lines are ignored.
 

\*
 
 Each line is permitted to be in either of the following formats:
 
 
 .. code-block:: perl
 
    option
    option=value
 
 
 Do not prefix the option with \ ``--``\ .  Do not quote the values, even if
 it has spaces; value are literal.  Whitespace around the equals sign is
 deleted during processing.
 

\*
 
 Only long options are recognized.
 

\*
 
 A line containing only two hyphens signals the end of option parsing.  Any
 further lines are interpreted as additional arguments (not options) to the
 program.
 

EXAMPLE
=======

This config file for mariadb-stat,

.. code-block:: perl

   # Config for mariadb-stat
   variable=Threads_connected
   cycles=2  # trigger if problem seen twice in a row
   --
   --user daniel

is equivalent to this command line:

.. code-block:: perl

   mariadb-stat --variable Threads_connected --cycles 2 -- --user daniel

Options after \ ``--``\  are passed literally to mariadb and mariadb-admin.

READ ORDER
==========

The tools read several configuration files in order:

1.
 
 The global MariaDB Tools configuration file,
 \ */etc/mariadb-tools/mariadb-tools.conf*\ .  All tools read this file,
 so you should only add options to it that you want to apply to all tools.
 

2.
 
 The global tool-specific configuration file, \ */etc/mariadb-tools/TOOL.conf*\ ,
 where \ ``TOOL``\  is a tool name like \ ``mariadb-query-digest``\ .  This file is named
 after the specific tool you're using, so you can add options that apply
 only to that tool.
 

3.
 
 The user's own MariaDB Tools configuration file,
 \ *$HOME/.mariadb-tools.conf*\ .  All tools read this file, so you should only
 add options to it that you want to apply to all tools.
 

4.
 
 The user's tool-specific configuration file, \ *$HOME/.TOOL.conf*\ ,
 where \ ``TOOL``\  is a tool name like \ ``mariadb-query-digest``\ .  This file is named
 after the specific tool you're using, so you can add options that apply
 only to that tool.
 

SPECIFYING
==========

There is a special \ ``--config``\  option, which lets you specify which
configuration files MariaDB Tools should read.  You specify a
comma-separated list of files.  However, its behavior is not like other
command-line options.  It must be given \ **first**\  on the command line,
before any other options.  If you try to specify it anywhere else, it will
cause an error.  Also, you cannot specify \ ``--config=/path/to/file``\ ;
you must specify the option and the path to the file separated by whitespace
\ *without an equal sign*\  between them, like:

.. code-block:: perl

   --config /path/to/file

If you don't want any configuration files at all, specify \ ``--config ''``\  to
provide an empty list of files.

