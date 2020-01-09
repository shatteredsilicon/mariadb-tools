# ###########################################################################
# EndOfScope package
# ###########################################################################

package B::Hooks::EndOfScope; # git description: 0.23-2-ga391106
# ABSTRACT: Execute code after a scope finished compilation
# KEYWORDS: code hooks execution scope

use strict;
use warnings;

our $VERSION = '0.24';

use 5.006001;

BEGIN {
  use Module::Implementation 0.05;
  Module::Implementation::build_loader_sub(
    implementations => [ 'XS', 'PP' ],
    symbols => [ 'on_scope_end' ],
  )->();
}

use Sub::Exporter::Progressive 0.001006 -setup => {
  exports => [ 'on_scope_end' ],
  groups  => { default => ['on_scope_end'] },
};

1;

# ###########################################################################
# End EndOfScope package
# ###########################################################################

