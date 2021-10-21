#!/usr/bin/env perl

BEGIN {
   die "The PERCONA_TOOLKIT_BRANCH environment variable is not set.\n"
      unless $ENV{PERCONA_TOOLKIT_BRANCH} && -d $ENV{PERCONA_TOOLKIT_BRANCH};
   unshift @INC, "$ENV{PERCONA_TOOLKIT_BRANCH}/lib";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use PerconaTest;
use Sandbox;
require "$trunk/bin/mariadb-index-checker";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $output;
my $cnf = "/tmp/12345/configs/mariadb-client.cnf";
my $cmd = "$trunk/bin/mariadb-index-checker -F $cnf -h 127.0.0.1";

$sb->wipe_clean($dbh);
$sb->create_dbs($dbh, ['issue_1192']);

# #############################################################################
# Issue 1192: DROP/ADD leaves structure unchanged
# #############################################################################
$sb->load_file('master', "t/lib/samples/dupekeys/issue-1192.sql", "issue_1192");

ok(
   no_diff(
      "$cmd -d issue_1192 --no-summary",
      "t/mariadb-index-checker/samples/issue_1192.txt",
      sed => ["'s/  (/ (/g'"],
   ),
   "Keys are sorted lc so left-prefix magic works (issue 1192)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
ok($sb->ok(), "Sandbox servers") or BAIL_OUT(__FILE__ . " broke the sandbox");
exit;
