
*******************
LOCALE ISSUES
*******************

When a fresh system is utilizing MariaDB-Tools, there are occasions where users
are presented with errors similar to the following:

.. code-block:: shell

    # Taken from a fresh CentOS docker image
    perl: warning: Setting locale failed.
    perl: warning: Please check that your locale settings:
        LANGUAGE = (unset),
        LC_ALL = (unset),
        LC_CTYPE = "UTF-8",
        LANG = "en_US.UTF-8"
    are supported and installed on your system.
    perl: warning: Falling back to a fallback locale ("en_US.UTF-8").

This is printed during perl initialization and can be resolved using the following

** CentOS/RHEL

.. code-block:: shell

    # Ensure packages are up-to-date
    yum update
    #
    # List Known Locales (non-container)
    localectl list-locales
    # List Installed Locales (container)
    locale -a
    #
    # Set Locale! (non-container)
    localectl set-locale LANG=#insert-choice-here
    # Set Locale! (container)
    yum -y install glibc-locale-source # this may NOT be installed on a fresh centos
    localedef -i *locale-code* -f *encoding* *locale-code*.*encoding*
    # (i.e.) localedef -i en_US -f UTF-8 en_US.UTF-8

** Debian

.. code-block:: shell

    # Ensure locales package is installed
    sudo locale-gen *locale-code* *locale-code*.*encoding*
    # sudo locale-gen en_US en_US.UTF-8
    # Use the built-in locale manager.
    sudo dpkg-reconfigure locales

**Ubuntu

.. code-block:: shell
    
    # Update Lists
    sudo apt update
    # Ensure locales package is installed
    sudo apt install locales
    # List Installed Locales
    locale -a
    #
    # Set Locale!
    sudo update-locale LANG=#insert-choice-here