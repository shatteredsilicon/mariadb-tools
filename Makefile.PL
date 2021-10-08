use ExtUtils::MakeMaker;

WriteMakefile(
    NAME      => 'mariadb-tools',
    VERSION   => '1.0.0', # PT 3.3.1
    EXE_FILES => [ <bin/*> ],
    MAN1PODS  => {
      'docs/mariadb-tools.pod' => 'blib/man1/mariadb-tools.1p',
      map {
         (my $name = $_) =~ s/^bin.//;
         my $file_name = $_;
         if ( $file_name !~ m/mongo/ ) {
             $_ => "blib/man1/$name.1p";
        }
      } <bin/*>
    },
    MAN3PODS     => {}, # man(3) pages are for C libs
    PREREQ_PM    => {
        DBI           => 1.46,
        DBD::mysql    => 3.0000_0,
    },
);
