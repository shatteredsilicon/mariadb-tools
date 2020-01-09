# ###########################################################################
# autoclean package
# ###########################################################################

use strict;
use warnings;

package namespace::autoclean; # git description: 0.28-24-g964adcf
# ABSTRACT: Keep imports out of your namespace
# KEYWORDS: namespaces clean dirty imports exports subroutines methods development

our $VERSION = '0.29';

use B::Hooks::EndOfScope 0.12;
use List::Util qw( first );
use namespace::clean 0.20;

sub import {
    my ($class, %args) = @_;

    my $subcast = sub {
        my $i = shift;
        return $i if ref $i eq 'CODE';
        return sub { $_ =~ $i } if ref $i eq 'Regexp';
        return sub { $_ eq $i };
    };

    my $runtest = sub {
        my ($code, $method_name) = @_;
        local $_ = $method_name;
        return $code->();
    };

    my $cleanee = exists $args{-cleanee} ? $args{-cleanee} : scalar caller;

    my @also = map $subcast->($_), (
        exists $args{-also}
        ? (ref $args{-also} eq 'ARRAY' ? @{ $args{-also} } : $args{-also})
        : ()
    );

    my @except = map $subcast->($_), (
        exists $args{-except}
        ? (ref $args{-except} eq 'ARRAY' ? @{ $args{-except} } : $args{-except})
        : ()
    );

    on_scope_end {
        my $subs = namespace::clean->get_functions($cleanee);
        my $method_check = _method_check($cleanee);

        my @clean = grep {
          my $method = $_;
          ! first { $runtest->($_, $method) } @except
            and ( !$method_check->($method)
              or first { $runtest->($_, $method) } @also)
        } keys %$subs;

        namespace::clean->clean_subroutines($cleanee, @clean);
    };
}

sub _method_check {
    my $package = shift;
    if (
      (defined &Class::MOP::class_of and my $meta = Class::MOP::class_of($package))
    ) {
        my %methods = map +($_ => 1), $meta->get_method_list;
        $methods{meta} = 1
          if $meta->isa('Moose::Meta::Role') && Moose->VERSION < 0.90;
        return sub { $_[0] =~ /^\(/ || $methods{$_[0]} };
    }
    else {
        my $does = $package->can('does') ? 'does'
                 : $package->can('DOES') ? 'DOES'
                 : undef;
        require Sub::Identify;
        return sub {
            return 1 if $_[0] =~ /^\(/;
            my $coderef = do { no strict 'refs'; \&{ $package . '::' . $_[0] } };
            my $code_stash = Sub::Identify::stash_name($coderef);
            return 1 if $code_stash eq $package;
            return 1 if $code_stash eq 'constant';
            # TODO: consider if we really need this eval
            return 1 if $does && eval { $package->$does($code_stash) };
            return 0;
        };
    }
}

1;

# ###########################################################################
# End autoclean package
# ###########################################################################
