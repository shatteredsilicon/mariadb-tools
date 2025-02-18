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
use Time::HiRes qw(time);

use PerconaTest;
use Sandbox;
use Data::Dumper;
require "$trunk/bin/mariadb-parted";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave1_dbh = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave1_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave1';
}

my $output;
my $rows;
my $cnf  = "/tmp/12345/configs/mariadb-client.cnf";
my $cmd  = "$trunk/bin/mariadb-parted";
my $drycmd = "$cmd --dryrun";

chdir "$ENV{PERCONA_TOOLKIT_BRANCH}/t/mariadb-parted/samples/";
$sb->_d("Prepping master with test-specific schema, will ensure slaves have received downstream...");
$sb->create_dbs($master_dbh, ['test']);
$sb->_d('Loading table schema...');
$sb->load_file('master', 't/mariadb-parted/samples/employees.sql');
$sb->wait_for_slaves();

# ###########################################################################
# These are dry-run tests of various options to test that the correct
# SQL statements are generated.
# ###########################################################################

# main( $r,
    # $dsn,
    # $remote_dsn,
    # $parts,
    # $timespec,
    # $requested_dt,
    # $email_log,
    # @partitions)

# Test help
$sb->_d('Starting -h');
$output = `$drycmd -h`;
# $sb->_d($output);
like($output,
   qr/.*Usage.*/,
   'Printed Help!'
);

# Test logfile
# $sb->_d('Starting -L');
# $output = output(sub {pdb_parted::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--for-update --purge)) });
# like($output, qr/SELECT .*? FOR UPDATE/, '--for-update');

# ###########################################################################
# These are online tests that check various options.
# ###########################################################################

# Test --why-quit and --statistics output
# $sb->load_file('master', 't/mariadb-archiver/samples/tables1-4.sql');
# $output = output(sub {pt_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--purge --why-quit --statistics)) });
# like($output, qr/Started at \d/, 'Start timestamp');
# like($output, qr/Source:/, 'source');
# like($output, qr/SELECT 4\nINSERT 0\nDELETE 4\n/, 'row counts');
# like($output, qr/Exiting because there are no more rows/, 'Exit reason');

# # Test basic functionality with OPTIMIZE
# $sb->load_file('master', 't/mariadb-archiver/samples/tables1-4.sql');
# $output = output(sub {pt_archiver::main(@args, qw(--optimize ds --source), "D=test,t=table_1,F=$cnf", qw(--purge)) });
# is($output, '', 'OPTIMIZE did not fail');

# # Test an empty table
# $sb->load_file('master', 't/mariadb-archiver/samples/tables1-4.sql');
# $output = `/tmp/12345/use -N -e "delete from test.table_1"`;
# $output = output(sub {pt_archiver::main(@args, '--source', "D=test,t=table_1,F=$cnf", qw(--purge)) });
# is($output, "", 'Empty table OK');

# # Test the output
# $sb->load_file('master', 't/mariadb-archiver/samples/tables1-4.sql');
# $output = `$trunk/bin/mariadb-archiver --where 1=1 --source D=test,t=table_1,F=$cnf --purge --progress 2 2>&1 | awk '{print \$3}'`;
# is($output, <<EOF
# COUNT
# 0
# 2
# 4
# 4
# EOF
# ,'Progress output looks okay');

# # Statistics
# $sb->load_file('master', 't/mariadb-archiver/samples/tables1-4.sql');
# $output = output(sub {pt_archiver::main(@args, qw(--statistics --source), "D=test,t=table_1,F=$cnf", qw(--dest t=table_2)) });
# like($output, qr/commit *10/, 'Stats print OK');

# # Test --no-delete.
# $sb->load_file('master', 't/mariadb-archiver/samples/tables1-4.sql');
# $output = output(sub {pt_archiver::main(@args, qw(--no-delete --source), "D=test,t=table_1,F=$cnf", qw(--dry-run --file /tmp/mariadb-archiver-test-no-delete-1)) });
# like($output, qr/> /, '--no-delete implies strict ascending');
# unlike($output, qr/>=/, '--no-delete implies strict ascending');
# $output = output(sub {pt_archiver::main(@args, qw(--no-delete --source), "D=test,t=table_1,F=$cnf", qw(--file /tmp/mariadb-archiver-test-no-delete-2)) });
# $output = `/tmp/12345/use -N -e "select count(*) from test.table_1"`;
# is($output + 0, 4, 'All 4 rows are still there');


# # #############################################################################
# # --sleep
# # #############################################################################
# # This table, gt_n.t1, is nothing special; it just has 19 rows and a PK.
# $sb->load_file('master', 't/mariadb-archiver/samples/gt_n.sql');

# # https://bugs.launchpad.net/percona-toolkit/+bug/979092
# # This shouldn't take more than 3 seconds because it only takes 2 SELECT
# # with limit 10 to get all 19 rows.  It should --sleep 1 between each fetch,
# # not between each row, which is the bug.

# my $t0 = time;
# $output = output(
#    sub { pt_archiver::main(@args, '--source', "D=gt_n,t=t1,F=$cnf",
#       qw(--where 1=1 --purge --sleep 1 --no-check-charset --limit 10)) },
# );
# my $t = time - $t0;

# ok(
#    $t >= 2 && $t <= ($ENV{PERCONA_SLOW_BOX} ? 8 : 4),
#    "--sleep between SELECT (bug 979092)"
# ) or diag($output, "t=", $t);

# # Try again with --bulk-delete.  The tool should work the same.
# $sb->load_file('master', 't/mariadb-archiver/samples/gt_n.sql');
# $t0 = time;
# $output = output(
#    sub { pt_archiver::main(@args, '--source', "D=gt_n,t=t1,F=$cnf",
#       qw(--where 1=1 --purge --sleep 1 --no-check-charset --limit 10),
#       qw(--bulk-delete)) },
# );
# $t = time - $t0;

# ok(
#    $t >= 2 && $t <= 3.5,
#    "--sleep between SELECT --bulk-delete (bug 979092)"
# ) or diag($output, "t=", $t);

# # #############################################################################
# # Bug 903387: mariadb-archiver doesn't honor b=1 flag to create SQL_LOG_BIN statement
# # #############################################################################
# SKIP: {
#    $sb->load_file('master', "t/mariadb-archiver/samples/bulk_regular_insert.sql");
#    $sb->wait_for_slaves();

#    my $original_rows  = $slave1_dbh->selectall_arrayref("SELECT * FROM bri.t ORDER BY id");
#    my $original_no_id = $slave1_dbh->selectall_arrayref("SELECT c,t FROM bri.t ORDER BY id");
#    is_deeply(
#       $original_no_id,
#       [
#          ['aa', '11:11:11'],
#          ['bb', '11:11:12'],
#          ['cc', '11:11:13'],
#          ['dd', '11:11:14'],
#          ['ee', '11:11:15'],
#          ['ff', '11:11:16'],
#          ['gg', '11:11:17'],
#          ['hh', '11:11:18'],
#          ['ii', '11:11:19'],
#          ['jj', '11:11:10'],
#       ],
#       "Bug 903387: slave has rows"
#    );

#    $output = output(
#       sub { pt_archiver::main(
#          '--source', "D=bri,L=1,t=t,F=$cnf,b=1",
#          '--dest',   "D=bri,t=t_arch",
#          qw(--where 1=1 --replace --commit-each --bulk-insert --bulk-delete),
#          qw(--limit 10)) },
#    );

#    $rows = $master_dbh->selectall_arrayref("SELECT c,t FROM bri.t ORDER BY id");
#    is_deeply(
#       $rows,
#       [
#          ['jj', '11:11:10'],
#       ],
#       "Bug 903387: rows deleted on master"
#    ) or diag(Dumper($rows));

#    $rows = $slave1_dbh->selectall_arrayref("SELECT * FROM bri.t ORDER BY id");
#    is_deeply(
#       $rows,
#       $original_rows,
#       "Bug 903387: slave still has rows"
#    ) or diag(Dumper($rows));
# }
#############################################################################
# Done.
#############################################################################
$sb->wipe_clean($master_dbh);
ok($sb->ok(), "Sandbox servers") or BAIL_OUT(__FILE__ . " broke the sandbox");

done_testing;
