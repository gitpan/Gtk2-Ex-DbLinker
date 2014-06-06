package Gtk2::Ex::DbLinker::AbDataManager;
use  Gtk2::Ex::DbLinker;
our $VERSION = $Gtk2::Ex::DbLinker::VERSION;

use Class::Interface;
  
&interface();
use strict;
use warnings;

# use Class::AccessorMaker {page => 1,  rec_per_page => 1 }, "no_new";

sub set_row_pos;

sub get_row_pos;

sub query;

sub set_field;

sub get_field;

sub get_field_type;

sub new_row;

sub save;

sub delete;

sub next;

sub previous;

sub last;

sub first;

sub row_count;

sub get_field_names;

sub get_autoinc_primarykeys;

sub get_primarykeys;

1;

__END__

=pod

=head1 NAME

Gtk2::Ex::DbLinker::AbDataManager - Interface for xxxDataManager modules

=head1 VERSION

See Version in L<Gtk2::Ex::DbLinker>

=head1 METHODS

see the implementing modules for the details

=head1 AUTHOR

FranE<ccedil>ois Rappaz <rappazf@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014 by F. Rappaz.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
