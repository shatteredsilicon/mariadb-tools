.. _install:

==========================
Installing MariaDB Tools
==========================

MariaDB provides packages for most popular 64-bit Linux distributions via the `MariaDB-Tools Repository <https://mariadb.com/kb/en/mariadb-package-repository-setup-and-usage/>`_:

* Debian 9 ("stretch")
* Debian 10 ("buster")
* Debian 11 ("bullseye")
* Ubuntu 18.04 LTS (Bionic Beaver)
* Ubuntu 20.04 LTS (Focal Fossa)
* Ubuntu 21.04 (Hirsute Hippo)
* Ubuntu 21.10 (Impish Indri)
* Red Hat Enterprise Linux or CentOS 7
* Red Hat Enterprise Linux or CentOS 8

.. note:: MariaDB Tools should work on other DEB-based and RPM-based systems
   (for example, Oracle Linux and Amazon Linux AMI),
   but it is tested only on those listed above.

It is recommended to install MariaDB software from official repositories:

1. Configure repositories as described in
   `MariaDB Enterprise Documentation
   <https://mariadb.com/docs/deploy/installation/#install-repository>`_.

#. Install MariaDB Tools using the corresponding package manager:

   * For Debian or Ubuntu::
.. code-block:: shell

      sudo apt-get install MariaDB-Tools

   * For RHEL or CentOS::
.. code-block:: shell

      sudo yum install MariaDB-Tools
      sudo dnf install MariaDB-Tools

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

