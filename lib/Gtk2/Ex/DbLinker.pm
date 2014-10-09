
package Gtk2::Ex::DbLinker;
use strict;
use warnings;


our $VERSION     = '0.093';
$VERSION = eval $VERSION;

1;

__END__


=head1 NAME

Gtk2::Ex::DbLinker - Use sql or orm objects to build a gtk2 Gui

=head1 VERSION

version  0.093 but see version at the end of MYMETA.yml to check that I'm correct here...

=head1 INSTALLATION

To install this module type the following:
	perl Makefile.PL
	make
	make test
	make install

On windows use nmake or dmake instead of make.

=head1 DEPENDENCIES

The following modules are required in order to use Gtk2::Ex::Linker

	Test::Simple => 0.44,
	GLib => 1.240,
	Gtk2 => 1.240,
	Class::Interface => 1.01,
	DateTime::Format::Strptime => 1.5
	Carp => 1.17
	Gtk2::Ex::Dialogs => 0.11
	DBI => 1.631
	Log::Log4perl => 1.41

Install one of Rose::DB::Object or DBIx::Class if you want to use these orm to access your data.

Rose::DB object is required to get example 2_rdb working.
DBIx::Class is required to get example 2_dbc working.

=head1 DESCRIPTION

This module automates the process of tying data from a database to widgets on a Glade-generated form.
All that is required is that you name your widgets the same as the fields in your data source.

Steps for use:

=over

=item * 

Create a DataManager object that contains the rows to display. Use DbiDataManager, RdbDataManager or DbcDataManager depending on how you access the database: sql commands and DBI, DBIx::Class or Rose::DB::Object

=item * 

Create a Gtk2::GladeXML object to construct the Gtk2 windows

=item * 

Create a Gtk2::Ex::DbLinker::Form object that links the data and the windows

=item *

You would then typically connect the buttons to the methods below to handle common actions
such as inserting, moving, deleting, etc.

=back

=head1 EXAMPLES

The examples folder (located in the Gtk2-Ex-DbLinker-xxx folder under cpan/build in your perl folders tree) contains four examples that use a sqlite database of three tables: 

=over

=item *

countries (countryid, country, mainlangid), 

=item *

langues (langid, langue), 

=item *

speaks (langid, countryid) in example2_dbc, file ./data/ex1_1 or (speaksid, langid, countryid) in example2_dbi and 2_rdb, file ./data/ex1

=back

=over

=item *

C<runexample1.pl> runs at the command line, gives a form that uses DBI and sql commands to populate a drop box and a datasheet.

=item *

C<runeexample2_xxx.pl> gives a main form with a bottom navigation bar that displays each record (a country and its main language) one by one. 

A subform displays other(s) language(s) spoken in that country. Each language is displayed one by one and a second navigation bar is used to show these in turn.

For each language, a list gives the others countries where this idiom is spoken. Items from this lists are also add/delete/changed with a third navigation bar.

=item *

C<runeexample2_dbc.pl> uses DBIx::Class. The speaks table primary key is the complete row itself, with the two fields, countryid and langid.

=item *

C<runeexample2_dbi.pl> uses sql commands and DBI. The speaks table primary key is a counter speaksid (primary key) and the two fields, countryid and langid compose an index which does not allow duplicate rows.

=item *

C<runeexample2_rdb.pl> uses Rose::Data::Object. The database is the same as example 2_dbi.

=back

=head1 SUPPORT

Any Gk2::Ex::DbLinker questions or problems can be posted to the the mailing list. To subscribe to the list or view the archives, go here: 
L<http://groups.google.com/group/gtk2-ex-dblinker>. 
You may also send emails to gtk2-ex-dblinker@googlegroups.com. 

The current state of the source can be extract using Mercurial from
L<http://code.google.com/p/gtk2-ex-dblinker/>.

=head1 AUTHOR

FranE<ccedil>ois Rappaz <rappazf@gmail.com>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut


