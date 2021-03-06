

use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME         => 'Gtk2::Ex::DbLinker',
    VERSION_FROM => 'lib/Gtk2/Ex/DbLinker.pm', # finds \$VERSION
    AUTHOR       => 'FranE<ccedil>ois Rappaz (rappazf@gmail.com)',
    ABSTRACT_FROM => 'lib/Gtk2/Ex/DbLinker.pm',
    PREREQ_PM    => {
                     'Test::More' => 1,
		     'GLib' => 1.240,
		     'Gtk2' => 1.240,
		      'Class::Interface' => 1.01,
		      'DateTime::Format::Strptime' => 1.5,
		      'Gtk2::Ex::Dialogs' => 0.11,
		      'DBI' => 1.631,
		      'Log::Log4perl' => 1.41,
		     
                    },
	TAR => 'ptar', 
	TARFLAGS => '-c -C -f',
       COMPRESS => q{perl -MIO::Compress::Gzip=gzip,:constants -e"my $$in = $$ARGV[0]; gzip($$in => qq($$in.gz), q(Level) => Z_BEST_COMPRESSION, q(BinModeIn) => 1) or die q(gzip failed); unlink $$in;"},	
		    

);
