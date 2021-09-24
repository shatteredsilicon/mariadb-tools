#!/bin/bash
## This rudimentary script combines build processes for MariaDB-Tools and backup-manager.

## Reusables
URL="https\:\/\/github.com\/mariadb-corporation\/mariadb-tools"

echo "Welcome to the MariaDB Tools Build Script!"
echo "Starting Shell Tools Build..."

## Local build of MariaDB-Backup-Manager as defined by Rick Pizzi.
git submodule sync                                                                                  ## Download the mariadb-backup-manager repository.
pushd internal-linked-projects/backup-manager                                                       ## new working directory from inside the repo
cat backup_manager.common backup_manager.packaged backup_manager.main > mariadb-backup-manager      ## thanks Rick.
chmod 755 mariadb-backup-manager                                                                    ## thanks Rick.
if [[ $? -gt 0 ]]; then
  echo "\033[0;31;40mWARN: Could not change permissions for backup-manager. This could prevent the tool from being utilized."
  echo "\033[0;31;40mCheck *internal-linked-projects/mariadb-backup-manager/mariadb-backup-manager* permissions before continuing"
fi
popd

## Consolidate
mv internal-linked-projects/backup-manager/mariadb-backup-manager bin/

## Checkpoint!
echo "Shell Tools complete. Beginning Perl tools...."

## Prep and build the perl binaries.
perl Makefile.PL
echo perl status: $?
if [[ $? -eq 0 ]]; then
  make
else
  echo "Failed to create Makefile. Please ensure Makefile.PL is readable. Stopping build..."
  exit 2
fi

## Success?
if [[ $? -eq 0 ]]; then
  echo "Perl Tools Complete. "
else
  echo "An unaccounted for error occurred during the *make install* execution. Please see the above output for more information."
  exit
fi

make install

echo "Tools are available for use your perl bin location."
echo "For support or to report an issue with these tools, please visit: $URL"
