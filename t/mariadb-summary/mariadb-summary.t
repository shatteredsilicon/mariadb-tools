#!/usr/bin/env perl

BEGIN {
   die "The MARIADB_TOOLS_BRANCH environment variable is not set.\n"
      unless $ENV{MARIADB_TOOLS_BRANCH} && -d $ENV{MARIADB_TOOLS_BRANCH};
   unshift @INC, "$ENV{MARIADB_TOOLS_BRANCH}/lib";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use PerconaTest;

my ($tool) = $PROGRAM_NAME =~ m/([\w-]+)\.t$/;

use Test::More tests => 2;

for my $i (2..3) {
   ok(
      no_diff(
         sub { print `$trunk/bin/mariadb-summary --read-samples "$trunk/t/mariadb-summary/samples/Linux/00$i/" | tail -n+3` },
         "t/mariadb-summary/samples/Linux/output_00$i.txt"),
      "--read-samples samples/Linux/00$i works",
   );
}

exit;
