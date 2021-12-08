
*******************
CENTOS INSTALL ISSUES
*******************

When a fresh system is installing MariaDB-Tools, there are occasions where users
are presented with errors similar to the following:

.. code-block:: shell

    Error: Package: mariadb-tools-6.0.1rc-1.x86_64 (/mariadb-tools-6.0.1rc-1.x86_64)
           Requires: perl(DateTime::Format::Strptime) >= 1.54
    You could try using --skip-broken to work around the problem
    You could try running: rpm -Va --nofiles --nodigest    

This is printed during installation when `epel-release` has not been installed first.
Despite our best efforts to find ways for pre-install inclusion, we currently must ask
that you install this package PRIOR to the install of mariadb-tools.

** CentOS/RHEL

.. code-block:: shell

    # Ensure packages are up-to-date
    yum update
    #
    # install epel
    yum install epel-release
    # install mariadb-tools
    yum install mariadb-tools

