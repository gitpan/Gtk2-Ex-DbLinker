
use strict;
use warnings;

use DBIx::Class::Schema::Loader qw/ make_schema_at /;
#U:\\docs\\perl\\mod\\hg_Gtk2-Ex-DbLinker\\examples\\
 my $dsn = "dbi:SQLite:dbname=./data/ex1_1;";
  make_schema_at(
      'Dbc::Schema',
      { debug => 1,
        dump_directory => '.',
      },
      [ $dsn, 
        
      ],
  );

  # { loader_class => '::mysql' } # optionally
