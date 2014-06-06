
use strict;
use warnings;
use Gtk2 -init;
use Dbc::Schema;

#use lib "../lib/";
use DBI;

use Log::Log4perl;
  Log::Log4perl->init("log_ex2.conf"); 


use Forms::Langues2_dbi;


my $dbfile = "./data/ex1";

my $dbh = DBI->connect ("dbi:SQLite:dbname=$dbfile","","", {  
		RaiseError       => 1,
        PrintError       => 1,
        }) or die $DBI::errstr;





sub load_main_w {
   
	Forms::Langues2_dbi->new({gladefolder => "./Forms", dbh => $dbh });

}

   &load_main_w;
    Gtk2->main;

