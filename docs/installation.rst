.. _install:

==========================
Installing MariaDB Tools
==========================

MariaDB provides packages for most popular 64-bit Linux distributions:

* Debian 7 ("wheezy")
* Debian 8 ("jessie")
* Ubuntu 14.04 LTS (Trusty Tahr)
* Ubuntu 16.04 LTS (Xenial Xerus)
* Ubuntu 16.10 (Yakkety Yak)
* Ubuntu 17.04 (Zesty Zapus)
* Red Hat Enterprise Linux or CentOS 6 (Santiago)
* Red Hat Enterprise Linux or CentOS 7 (Maipo)

.. note:: MariaDB Tools should work on other DEB-based and RPM-based systems
   (for example, Oracle Linux and Amazon Linux AMI),
   but it is tested only on those listed above.

It is recommended to install MariaDB software from official repositories:

1. Configure repositories as described in
   `MariaDB Enterprise Documentation
   <https://mariadb.com/docs/deploy/installation/#install-repository>`_.

#. Install MariaDB Tools using the corresponding package manager:

   * For Debian or Ubuntu::

      sudo apt-get install MariaDB-Tools

   * For RHEL or CentOS::

      sudo yum install MariaDB-Tools

Alternative Install Methods
===========================

You can also download the packages from the
`MariaDB Customer Portal <https://customers.mariadb.com>`_
and install it using tools like ``dpkg`` and ``rpm``,
depending on your system.

If you want to download a specific tool, use the following address:
http://tools.mariadb.com/get

For example, to download the ``mariadb-summary`` tool, run::

 wget tools.mariadb.com/get/mariadb-summary

