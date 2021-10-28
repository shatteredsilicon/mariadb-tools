package TablePartitions;
use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;

use DBI;

sub new {
  my ( $class, $pl, $dsn ) = @_;
  my $self = ();
  $self->{dbh} = $dsn->get_dbh(1);
  $self->{pl} = $pl;
  $self->{schema} = $dsn->get('D');
  $self->{name} = $dsn->get('t');
  bless $self, $class;

  $self->_get_partitions();

  if($self->{partition_method} ne 'RANGE') {
    return undef;
  }
  else {
    return $self;
  }
}

sub _get_version {
  my ($self) = @_;
  my $dbh = $self->{dbh};

  my ($version) = $dbh->selectrow_array('SELECT VERSION()');
  my ($major, $minor, $micro, $dist) = $version =~ /^(\d+)\.(\d+)\.(\d+)-(.*)/;
  unless($major) {
    ($major, $minor, $micro) = $version =~ /^(\d+)\.(\d+)\.(\d+)/;
    $dist = '';
  }
  ["$major.$minor", $major, $minor, $micro, $dist];
}

sub _get_partitions {
  my ($self) = @_;
  my $dbh = $self->{dbh};
  my ($release, undef, undef, undef, undef) = $self->_get_version();
  die("Server release not at least 5.1 ($release)") if ($release < 5.1);

  if(1) {
    $self->_get_partitions_by_IS();
  }
}

sub _get_partitions_by_IS {
  my ($self) = @_;
  my $dbh = $self->{dbh};

  my $qtd_schema = $dbh->quote($self->{schema});
  my $qtd_table  = $dbh->quote($self->{name});

  my $sql = "SELECT * FROM `information_schema`.`PARTITIONS` WHERE TABLE_SCHEMA=$qtd_schema AND TABLE_NAME=$qtd_table";

  $self->{pl}->d('SQL:', $sql);

  my $rows = $dbh->selectall_arrayref($sql, { Slice => {} });

  $self->{pl}->es("Table does not have any partitions, or does not exist.")
    and die("Table does not have any partitions, or does not exist")
  unless(scalar @$rows >= 1);

  $self->{partitions} = [];
  $self->{partition_method} = $rows->[0]->{PARTITION_METHOD};
  $self->{partition_expression} = $rows->[0]->{PARTITION_EXPRESSION};
  
  foreach my $r (@$rows) {
    my $p = {
      name => $r->{PARTITION_NAME},
      sub_name => $r->{SUBPARTITION_NAME},
      position => $r->{PARTITION_ORDINAL_POSITION},
      description => $r->{PARTITION_DESCRIPTION},
      sub_position => $r->{SUBPARTITION_ORDINAL_POSITION}
    };
    push @{$self->{partitions}}, $p;
  }
}

sub partitions {
  my ($self) = @_;
  $self->{pl}->d(Dumper($self->{partitions}));
  $self->{partitions}
}

sub first_partition {
  my ($self) = @_;
  $self->{partitions}->[0];
}

sub last_partition {
  my ($self) = @_;
  $self->{partitions}->[-1];
}

sub method {
  my ($self) = @_;
  $self->{partition_method};
}

sub expression {
  my ($self) = @_;
  $self->{partition_expression};
}

sub expression_column {
  my ($self) = @_;
  my ($col, $fn) = $self->expr_datelike;
  return $col if(defined($col));
  $self->{partition_expression} =~ /^\s*(A-Za-z\-_\$)\(([A-Za-z0-9\-_\$]+)\)/i;
  return $2 if ($1 and $2);
  return $self->{partition_expression};
}

sub expr_datelike {
  my ($self) = @_;
  my %datefuncs = ( 'to_days' => 'from_days', 'month' => 1, 'year' => 'rick_year', 'unix_timestamp' => 'from_unixtime', 'to_seconds' => 'rick_seconds' );
  $self->{partition_expression} =~ /^\s*([A-Za-z\-_\$]+)\(([A-Za-z0-9\-_\$`]+)\)/i;
  if(defined $1 and $datefuncs{lc($1)}) {
    	return ($2, $1, $datefuncs{lc($1)});
  }
  else {
    if ($no_part_func) {
    	return ($2, '', '');
    }
    else {
        return undef;
    }
  }
}

sub match_partitions {
  my ($self, $reg) = @_;
  my %res;
  map { $res{$_->{name}} = {name => $_->{name}, position => $_->{position}, description => $_->{description} } if($_->{name} =~ $reg); } @{$self->{partitions}};
  values %res;
}

sub has_maxvalue_data {
  my ($self) = @_;
  my $dbh = $self->{dbh};
  my $explain_result = undef;
  my $descr = undef;
  my $col = $self->expression_column;
  if ( $self->{partitions}->[-1]->{description} eq 'MAXVALUE' ) {
    $descr = $self->{partitions}->[-2]->{description};
    if($self->expr_datelike) {
      my (undef, $fn, $cfn) = $self->expr_datelike;
      if($fn) {
        $descr = "$cfn($descr)";
      }
    }
  }
  else {
    return 0; # Can't have maxvalue data since there isn't a partition for that.
  }
  my $sql =
      qq|SELECT COUNT(*) AS cnt
           FROM `$self->{schema}`.`$self->{name}`
         WHERE $col > $descr
        | ;
  $self->{pl}->d('SQL:', $sql);
  eval {
    $explain_result = $dbh->selectrow_hashref($sql);
    $self->{pl}->d(Dumper($explain_result));
  };
  if($EVAL_ERROR) {
    $self->{pl}->es($EVAL_ERROR);
    return undef;
  }
  return $explain_result->{cnt};
}

sub start_reorganization {
  my ($self, $p) = @_;
  die("Need partition name to re-organize") unless($p);
  my $part = undef;
  foreach my $par (@{$self->{partitions}}) {
    $part = $par if($par->{name} eq $p);
  }
  return undef unless($part);
  $self->{re_organizing} =  [];
  push @{$self->{re_organizing}},$part;
  return 1;
}

sub add_reorganized_part {
  my ($self, $name, $desc) = @_;
  return undef unless($self->{re_organizing});
  my ($col, $fn) = $self->expr_datelike;
  push @{$self->{re_organizing}}, {name => $name, description => $desc};
  return 1;
}

sub end_reorganization {
  my ($self, $pretend) = @_;
  return undef unless $self->{re_organizing};
  my $sql = "ALTER TABLE `$self->{schema}`.`$self->{name}` REORGANIZE PARTITION";
  my $orig_part = shift @{$self->{re_organizing}};
  my (undef, $fn) = $self->expr_datelike;
  $sql .= " $orig_part->{name} INTO (";
  while($_ = shift @{$self->{re_organizing}}) {
      $sql .= "\nPARTITION $_->{name} VALUES LESS THAN ";
    if(uc($_->{description}) eq 'MAXVALUE') {
      $sql .= 'MAXVALUE';
    }
    else {
      if($fn) {
        $sql .= "($fn(" . $self->{dbh}->quote($_->{description}) . '))';
      }
      else {
        $sql .= "(" . $_->{description} . ')';
      }
    }
    $sql .= ',';
  }
  chop($sql);
  $sql .= "\n)";
  $self->{pl}->d("SQL: $sql");
  eval {
    unless($pretend) {
      $self->{dbh}->do($sql);
      $self->_get_partitions();
    }
  };
  if($EVAL_ERROR) {
    $self->{pl}->e("Error reorganizing partition $orig_part->{name}: $@");
    return undef;
  }
  $self->{re_organizing} = 0;
  return 1;
}

sub add_range_partition {
  my ($self, $name, $description, $pretend) = @_;
  if($self->method ne 'RANGE') {
    $self->{pl}->m("Unable to add partition to non-RANGE partition scheme.");
    return undef;
  }
  for my $p (@{$self->{partitions}}) {
    if($p->{description} eq 'MAXVALUE') {
      $self->{pl}->m("Unable to add new partition when a catchall partition ($p->{name}) exists.");
      return undef;
    }
  }
  my (undef, $fn, $cfn) = $self->expr_datelike;
  my $qtd_desc = $self->{dbh}->quote($description);
  if (!$no_part_func) {
     $self->{pl}->d("SQL: ALTER TABLE `$self->{schema}`.`$self->{name}` ADD PARTITION (PARTITION $name VALUES LESS THAN ($fn(($qtd_desc)))");
  }
  else {
     $self->{pl}->d("SQL: ALTER TABLE `$self->{schema}`.`$self->{name}` ADD PARTITION (PARTITION $name VALUES LESS THAN ($description))");
  }
  eval {
    unless($pretend) {
      if (!$no_part_func) {
          $self->{dbh}->do("ALTER TABLE `$self->{schema}`.`$self->{name}` ADD PARTITION (PARTITION $name VALUES LESS THAN ($fn($qtd_desc)))");
          $self->_add_part($name, "to_days($qtd_desc)");
      }
      else {
          $self->{dbh}->do("ALTER TABLE `$self->{schema}`.`$self->{name}` ADD PARTITION (PARTITION $name VALUES LESS THAN ($description))");
          $self->_add_part($name, "($description)");
      }
    }
  };
  if($EVAL_ERROR) {
    $self->{pl}->e("Error adding partition: $@");
    return undef;
  }
  return 1;
}

sub drop_partition {
  my ($self, $name, $pretend) = @_;
  if($self->method ne 'RANGE') {
    $self->{pl}->m("Unable to drop partition from non-RANGE partition scheme.");
    return undef;
  }
  $self->{pl}->d("SQL: ALTER TABLE `$self->{schema}`.`$self->{name}` DROP PARTITION $name");
  eval {
    unless($pretend) {
      $self->{dbh}->do("ALTER TABLE `$self->{schema}`.`$self->{name}` DROP PARTITION $name");
      $self->_del_part($name);
    }
  };
  if($EVAL_ERROR) {
    $self->{pl}->e("Error dropping partition: $@");
    return undef;
  }

  return 1;
}

sub desc_from_datelike {
  my ($self, $name) = @_;
  my ($desc, $fn, $cfn) = $self->expr_datelike;

  if($self->method ne 'RANGE') {
    $self->{pl}->d("Only makes sense for RANGE partitioning.");
    return undef;
  }
  if (!$no_part_func and !$fn) {
      return undef;
  }

  for my $p (@{$self->{partitions}}) {
    if($p->{name} eq $name) {
      $desc = $p->{description};
      last;
    }
  }

  if ($no_part_func) {
  	my ($ds) = $self->{dbh}->selectrow_array("SELECT FROM_UNIXTIME($desc)");
  	return $ds;
  }
  if ($cfn eq "rick_year") {
  	my ($ds) = $self->{dbh}->selectrow_array("SELECT '$desc-01-01'");
  	return $ds;
  }
  if ($cfn eq "rick_seconds") {
  	my ($ds) = $self->{dbh}->selectrow_array("SELECT TIMESTAMPADD(SECOND, $desc - 86400, '0000-01-01 00:00:00')");
  	return $ds;
  }
  else {
  	$self->{pl}->d("SQL: SELECT $cfn($desc)");
  	my ($ds) = $self->{dbh}->selectrow_array("SELECT $cfn($desc)");
  	return $ds;
  }
}

sub _add_part {
  my ($self, $name, $desc) = @_;
  my ($d) = $self->{dbh}->selectrow_array("SELECT $desc");
  push @{$self->{partitions}}, {name => $name, description => $d, position => undef};
}

sub _del_part {
  my ($self, $name) = @_;
  my @replace = ();
  foreach my $p (@{$self->{partitions}}) {
    unless($p->{name} eq $name) {
      push @replace, $p;
    }
  }
  $self->{partitions} = \@replace;
}

1;
