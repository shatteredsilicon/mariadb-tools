package Timespec;
use strict;
use warnings FATAL => 'all';
use DateTime;
use DateTime::Format::Strptime;
use Carp;

sub parse {
  my ($class, $str, $ref) = @_;
  if(not defined $ref) {
    $ref = DateTime->now(time_zone => 'local');
  }
  else {
    $ref = $ref->clone();
  }
  my $fmt_local = DateTime::Format::Strptime->new(pattern => '%F %T',
                                                  time_zone => 'local');
  my $fmt_tz = DateTime::Format::Strptime->new(pattern => '%F %T %O');
  $fmt_tz->parse_datetime($str);
  if($str =~ /^([-+]?)(\d+)([hdwmqy])(?:(?:\s|\.)(startof))?$/) {
    my ($spec, $amt) = ($3, $2);
    my %cv = ( 'h' => 'hours', 'd' => 'days', 'w' => 'weeks', 'm' => 'months', 'y' => 'years' );
    if($4) {
      if($cv{$spec}) {
        $_ = $cv{$spec};
        s/s$//;
        $ref->truncate(to => $_);
      }
      else { # quarters
        $ref->truncate(to => 'day');
        $ref->subtract(days => $ref->day_of_quarter()-1);
      }
    }

    if($spec eq 'q') {
      $spec = 'm';
      $amt *= 3;
    }

    if($1 eq '-') {
      $ref->subtract($cv{$spec} => $amt);
    }
    if($1 eq '+' or $1 eq '') {
      $ref->add($cv{$spec} => $amt);
    }
    return $ref;
  }
  elsif($str eq 'now') {
    return DateTime->now(time_zone => 'local');
  }
  elsif($str =~ /^(\d+)$/) {
    return DateTime->from_epoch(epoch => $1);
  }
  elsif($_ = $fmt_tz->parse_datetime($str)) {
    return $_;
  }
  elsif($_ = $fmt_local->parse_datetime($str)) {
    return $_;
  }
  else {
    croak("Unknown or invalid Timespec [$str] supplied.");
  }
}


1;
