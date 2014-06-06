
use strict;
use warnings;
use Gtk2 -init;
use Dbc::Schema;

#use lib "../lib/";

use Log::Log4perl;
  Log::Log4perl->init("log_ex2.conf"); 


use Forms::Langues2_dbc;




=for comment
my $dbh = DBI->connect ("dbi:SQLite:dbname=$dbfile","","", {  
		RaiseError       => 1,
        PrintError       => 1,
        }) or die $DBI::errstr;
=cut

sub get_schema {
	my  $file = shift;
	my $dsn = "dbi:SQLite:dbname=$file";
	#$globals->{ConnectionName}= $conn->{Name};
        my $s =  Dbc::Schema->connect(
            	$dsn,
	
        );
	return $s;
}



sub load_main_w {
   
	Forms::Langues2_dbc->new({gladefolder => "./Forms", schema => get_schema("./data/ex1_1") });

}

   &load_main_w;
    Gtk2->main;

