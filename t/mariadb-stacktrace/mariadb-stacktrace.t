#!/usr/bin/env perl

BEGIN {
   die "The PERCONA_TOOLKIT_BRANCH environment variable is not set.\n"
      unless $ENV{PERCONA_TOOLKIT_BRANCH} && -d $ENV{PERCONA_TOOLKIT_BRANCH};
   unshift @INC, "$ENV{PERCONA_TOOLKIT_BRANCH}/lib";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use PerconaTest;
use Test::More;

my $sample = "$trunk/t/mariadb-stacktrace/samples";

opendir my $dh, $sample or die "Error opening $sample: $OS_ERROR";
while ( my $file = readdir $dh ) {
   next unless -f "$sample/$file" && "$sample/$file" =~ m/\.in$/;
   (my $outfile = $file) =~ s/\.in/.out/;
   ok(
      no_diff(
         "$trunk/bin/mariadb-stacktrace $sample/$file",
         "t/mariadb-stacktrace/samples/$outfile",
      ),
      "$file"
   ) or diag($test_diff);
}
closedir $dh;

ok(
   no_diff(
      "$trunk/bin/mariadb-stacktrace -l 2 $sample/stacktrace003.in",
      "t/mariadb-stacktrace/samples/stacktrace003-limit2.out",
   ),
   "Limit 2 (stacktrace003-limit2.out)"
) or diag($test_diff);

done_testing;
