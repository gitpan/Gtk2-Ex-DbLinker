 use strict;
use warnings;

 use DBI;
 use lib "./Gtk2-Ex-Linker/lib/";
use Gtk2::Ex::Linker::DbiDataManager;


use Log::Log4perl;
  Log::Log4perl->init("log.conf"); 

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
        f_schema         => undef,
        f_dir            => "data",
        f_dir_search     => [],
        f_ext            => ".csv/r",
        f_lock           => 2,
        f_encoding       => "utf8",

        csv_eol          => "\r\n",
        csv_sep_char     => ";",
        csv_quote_char   => '',
        csv_escape_char  => '"',
        csv_class        => "Text::CSV_XS",
        csv_null         => 1,
        csv_tables       => {
            info => { f_file => "info.csv" }
            },

        RaiseError       => 1,
        PrintError       => 1,
        FetchHashKeyName => "NAME_lc",
        }) or die $DBI::errstr;

 my $query = "SELECT * FROM countries ORDER BY country";

 my $sth   = $dbh->prepare ($query);
    $sth->execute ();
    while (my $row = $sth->fetchrow_hashref) {
        print "Found result row: id = ", $row->{countryid},
              ", name = ", $row->{country}, "\n";
        }
    $sth->finish ();
 
    $query = "SELECT langue FROM langues inner join speaks on langues.langid = speaks.langid inner join countries on speaks.countryid = countries.countryid";
#$query = "Select country from countries inner join speaks on  countries.countryid = speaks.countryid";
    #
     $query = "SELECT langue FROM langues, countries, speaks where speaks.langid = langues.langid and speaks.countryid = countries.countryid and countries.country = 'Switzerland' order by langue";

    # (langueid) inner countries using (countryid) WHERE country = 'Switzerland' ORDER BY langue
    $sth   = $dbh->prepare ($query);
    $sth->execute ();
    while (my $row = $sth->fetchrow_hashref) {
        print $row->{langue}, "\n";
        }
    $sth->finish ();

    my $dman = Gtk2::Ex::Linker::DbiDataManager->new({
			dbh => $dbh,
			sql => { pass_through => "select countryid, country from countries order by country"},
			primary_keys => ["countryid"],
		});

	 $dman = Gtk2::Ex::Linker::DbiDataManager->new({
			dbh => $dbh,
			sql => { 
				pass_through => "select countryid, country from countries where countryid = 0",
				select => "countryid, country",
			       	from => "countries",
			       	order_by => "country",
			},
			primary_keys => ["countryid"],
		});
