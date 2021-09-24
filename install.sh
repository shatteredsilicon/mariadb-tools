#!/bin/bash
## This rudimentary script combines build processes for MariaDB-Tools and backup-manager.

## Reusables
URL="https://github.com/mariadb-corporation/mariadb-tools"

echo "Welcome to the MariaDB Tools Build Script!"
echo "Starting Perl Tools Build..."


## Prep and build the perl binaries.
perl Makefile.PL
if [ $? ]; then
  make install;
else
  echo "Failed to create Makefile. Please ensure Makefile.PL is readable. Stopping build..."
  exit 2
fi

## Success?
if [ $? ]; then
  echo "Perl Tools Complete. Moving on to shell utilities..."
else
  echo "An unaccounted for error occurred during the *make install* execution. Please see the above output for more information."
  exit
fi

## Local build of MariaDB-Backup-Manager as defined by Rick Pizzi.
git submodule sync                                                                                  ## Download the mariadb-backup-manager repository.
pushd internal-linked-projects/mariadb-backup-manager                                               ## new working directory from inside the repo
cat backup_manager.common backup_manager.packaged backup_manager.main > mariadb-backup-manager      ## thanks Rick.
chmod 755 mariadb-backup-manager                                                                    ## thanks Rick.
if [ $? ]; then
  echo "\033[0;31;40mWARN: Could not change permissions for backup-manager. This could prevent the tool from being utilized.
  echo "\033[0;31;40mCheck *internal-linked-projects/mariadb-backup-manager/mariadb-backup-manager* permissions before continuing"
fi
popd

## Consolidate
mv internal-linked-projects/mariadb-backup-manager/mariadb-backup-manager bin/

echo "Tools are available for use in `cwd`/bin."
echo "For support or to report an issue with these tools, please visit: $URL"
