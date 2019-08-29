# MariaDB Toolkit

*MariaDB Toolkit* is a collection of advanced command-line tools used by
[MariaDB](http://www.mariadb.com/) support staff to perform a variety of
MariaDB and system tasks that are too difficult or complex to perform manually.

These tools are ideal alternatives to private or "one-off" scripts because
they are professionally developed, formally tested, and fully documented.
They are also fully self-contained, so installation is quick and easy and
no libraries are installed.

## Installing

To install all tools, run:

```
perl Makefile.PL
make
make test
make install
```  

You probably need to be root to `make install`.  On most systems, the tools
are installed in /usr/local/bin.  See the INSTALL file for more information.

## Documentation

Run `man mariadb-toolkit` to see a list of installed tools, then `man tool`
to read the embedded documentation for a specific tool.  You can also read
the documentation online at [http://www.percona.com/software/percona-toolkit/](http://www.percona.com/software/percona-toolkit/).


