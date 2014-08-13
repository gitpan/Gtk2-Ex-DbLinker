package Gtk2::Ex::DbLinker::RdbDataManager;
use  Gtk2::Ex::DbLinker;
our $VERSION = $Gtk2::Ex::DbLinker::VERSION;

use Class::Interface;

&implements('Gtk2::Ex::DbLinker::AbDataManager');

use strict;
use warnings;
use  Carp;
#use Data::Dumper;

$Class::Interface::CONFESS = 1;


sub new {
	 my ( $class, $req ) = @_;
	my $self = {
		page => $$req{pate} || 1,
		rec_per_page => $$req{rec_per_page} || 1,
		data => $$req{data},
		meta => $$req{meta},
		primary_keys => $$req{primary_keys},
	 	ai_primary_keys => $$req{ai_primary_keys},

	 };
	 $self->{log} = Log::Log4perl->get_logger("Gtk2::Ex::DbLinker::RdbDataManager");

	

	 bless $self, $class;
	 $self->_init_pos;
	$self->_init;
	 return $self;
}

sub query{
	my ($self, $data) =  @_;
		$self->{data} = $data;
	$self->{log}->debug("query " . ($self->{cols} ? @{$self->{cols}} : " cols undef "));
	#try to initiate cols as long as it's not done (the array referer by $self->{cols} is empty)
	#the line defined cols the first time a row is fetched
	# print Dumper($self->{cols});
	$self->_init_pos;
	$self->_init if ( @{$self->{cols}} == 0);
	# $self->{log}->debug("query : " . @$data[0]->noti ) if (scalar @$data > 0);
	foreach my $r (@{$self->{data}}){
		foreach my $f (@{$self->{cols}}){
			$self->{log}->debug( $f . " : " . ($r->{$f} ? $r->{$f} : ""));
		}
	}


} 

sub set_row_pos{
	my ($self, $pos) = @_;
	my $found=1;
	# $self->{log}->debug("new_row is " . ($self->{new_row} ? " defined" : " undefined"));
	if ( ! defined ($self->{row}->{pos})){ 
		$self->{log}->debug("RdbDataManager : not data");
		$found = 0;
	} elsif ($pos <= $self->{row}->{last_row} + 1 && $pos >=0) {
		$self->{row}->{pos}= $pos; #if pos is last_row + 1 we are inserting a new row
		#this row is created with new_row
		#this row will be pushed on the row array on save
		#and saved to the database with row->save
	#} elsif ($pos == $self->{row}->{last_row} + 1) {
	#	$self->{row}->{pos} =  $pos;
		
	} else { $found = 0; croak(" position outside rows limits ");}
	# $self->{log}->debug("set_row_pos current pos: " . $self->{row}->{pos} . " new pos : " . $pos . " last: " . $self->{row}->{last_row} . " count : " . scalar @{ $self->{data}} );

	return $found;

}

sub get_row_pos{
	my ($self) = @_;
	return $self->{row}->{pos};
}

sub set_field{
	my ($self, $id, $value) = @_;
	my $pos =  $self->{row}->{pos};
	my $row;
	$self->{log}->debug("set_field: " . $id . " pos: " . $pos . " value : " . ($value ? $value : ""));
	if ($pos >= $self->row_count) {
		$row = $self->{new_row};
	} else {
		$row = $self->{data}[$pos];
	}
	my $m = $self->{fieldSetter}->{$id};
	$row->$m($value); # or warn(__PACKAGE__ . " no method found to set value " . $value . " in the column " . $id . " entries are ".  join(" ", keys %{ $self->{fieldSetter} }));
}

sub get_field{
	my ($self, $id) = @_;
	my $pos =  $self->{row}->{pos};
	my $row = $self->{data}[$pos];
	my $m = $self->{fieldGetter}->{$id};
	# $self->{log}->debug("get_field " . $id . " " . $m);
	return $row->$m() or die(__PACKAGE__ . " no method found to get value from the column " . $id);;

}

sub save{
	my $self = shift;
	my $row;
	if ($self->{new_row}){
		$self->{log}->debug("Linker::RdbDataManager save new row " );
		$row = $self->{new_row};
		push @{$self->{data}}, $row;
		my $last = $self->row_count-1;
		$self->{row} = {pos => $last, last_row => $last};	
	
	} else {
		$self->{log}->debug("Linker::RdbDataManager save at " . $self->{row}->{pos} );
		my $pos = $self->{row}->{pos};
		$row =  $self->{data}[$pos];
	}
	$self->{log}->debug("saving and unsetting new row");
	$row->save or carp("can't save ...\n");
	$self->{new_row} = undef;
}
sub new_row {
	my ($self ) = @_;
	#return if ($self->{new_row});
	my $class =  $self->{class};
	my $row = $class->new;
	$self->{new_row} = $row;
	$self->{row}->{pos} = $self->{row}->{last_row} + 1;
	#$self->{log}->debug("new_row: " . Dumper($row));
	
}

sub delete{
	my $self = shift;
	$self->{log}->debug("Linker::RdbDataManager delete at " . $self->{row}->{pos} );
	my $pos = $self->{row}->{pos};
	if (defined $pos) { # if ($pos) is false when $pos is 0
		my $row =  $self->{data}[$pos];
		if ( ! $row->delete ) {croak(" can't delete row at pos " . $pos )};

		splice @{$self->{data}}, $pos, 1;
		if ($self->row_count == 0){
			$self->{row} = {pos => undef, last_row => undef};
		} else {
			$self->next;
			$self->{row} = {pos => $pos, last_row => $self->row_count-1};
		}
	}

}

sub next{
	my $self = shift;
	$self->_move(1);
}

sub previous{	
	my $self = shift;
	$self->_move(-1);
}

sub last{
	my $self = shift;
	$self->_move(undef, $self->row_count() -1);
}

sub first {
	my $self = shift;
	$self->_move(undef, 0);
}

sub row_count{
	my $self = shift;
	my $hr =  $self->{row};
	my $count = scalar @{$self->{data}};
	$self->{log}->debug("row_count last pos : " . ($hr->{last_row} ? $hr->{last_row}  : -1) . " count: " . $count);
	return $count;

}

sub get_field_names {
	my $self = shift;
	return @{$self->{cols}};

}

#field type : fieldtype return by the database
#param : the field name
sub get_field_type {
	my ($self, $id) = @_;
	#return $fieldtype{$self->{fieldsDBType}->{$id}};
	return $self->{fieldsDBType}->{$id};

}

sub get_primarykeys {
	my $self = shift;
	my @pk;
        @pk =	@{ $self->{primary_keys} } if ($self->{primary_keys});
	return @pk;

}

sub get_autoinc_primarykeys {
	my $self = shift;
	my @pk;
      	@pk =	@{$self->{ai_primary_keys}} if ($self->{ai_primary_keys});
	return @pk;
}

sub _init_pos {
	my $self = shift;
	 my $first = $self->{data}[0];
	 if ($first) {
		my  $count = scalar @{$self->{data}};
		$self->{row} = {pos=>0, last_row => $count -1 };
	} else {
		$self->{row} = {pos => undef, last_row => undef};
	}

}

sub _init {
	my $self = shift;
	my $meta = $self->{meta};
	$self->{class} =  $meta->class;
	$self->{log}->debug("Class: ". $self->{class});
	$self->{primary_keys} = [];
	$self->{cols} = [];

	foreach my $id ($meta->column_names){
		my $c =	$meta->column($id);

		my $method =  $c->method_name('get')  || $c->method_name('get_set') or die();
		$self->{fieldGetter}->{$id} = $method;
		$self->{log}->debug("get method for field ". $id . " : " . $method);
		$method =  $c->method_name('set')  || $c->method_name('get_set') or die();
		$self->{fieldSetter}->{$id} = $method;
		my (@pk, @apk);
		push @{$self->{cols}}, $id;
		if ($c->is_primary_key_member) {
			$self->{log}->debug("found pk " . $id);
		       push @pk, $id;
			if ($c->type eq "serial"){
				$self->{log}->debug("found auto inc pk " . $id);
				push @apk, $id;
		        }
		}
		# don't override user defined values
		$self->{primary_keys} = \@pk unless ($self->{primary_keys});
=for comment
		if ( $self->{ai_primary_keys}) {
			$self->{log}->debug("ai_primary_keys already given");
		} else  {
			$self->{log}->debug("stores newly found ai_pk");
			$self->{ai_primary_keys} = \@apk;
		}
=cut
		$self->{ai_primary_keys} = \@apk unless ($self->{ai_primary_keys});
		
		$self->{log}->debug("Rdb_dman_init: field " . $id . " type: " . $c->type);
		$self->{fieldsDBType}->{$id}= $c->type;
	}
}

sub _move {
	  my ( $self, $offset, $absolute ) = @_;
	$self->{log}->debug("move offset: " . ($offset?$offset:"") . " abs: " . ( defined $absolute?$absolute:""));
	if (defined $absolute) { 
		$self->{row}->{pos} = $absolute;
	} else   {
        	$self->{row}->{pos} += $offset;
	}
	# Make sure we loop around the recordset if we go out of bounds.
        if ( $self->{row}->{pos} < 0 ) {
	     $self->{row}->{pos} =0;
        } elsif ( $self->{row}->{pos} > $self->row_count() - 1 ) {
	      $self->{row}->{pos} =  $self->row_count() - 1;
      }
     return $self->{row}->{pos};

}

1;

__END__

=pod

=head1 NAME

Gtk2::Ex::DbLinker::RdbDataManager - a module that get data from a database using Rose::DB::Objects

=head1 VERSION

See Version in L<Gtk2::Ex::DbLinker>

=head1 SYNOPSIS

	use Gtk2 -init;
	use Gtk2::GladeXML;
	use Gtk2::Ex:Linker::RdbDataManager; 
	my $builder = Gtk2::Builder->new();
	$builder->add_from_file($path_to_glade_file);

Instanciation of a RdbManager object is a two step process:

=over

=item *

use a Rose::DB::Object::Manager derived object to get a array of Rose::DB::Object derived rows. 

	 my $data = Rdb::Mytable::Manager->get_mytable(query => [ pk_field => {ge => 0}], sort_by => 'field2' );

=item * 

Pass this object to the RdbDataManager constructor with a Rose::DB::Object::Metatdata derived object

 	my $rdbm = Gtk2::Ex::DbLinker::RdbDataManager->new({data => $data,
 		meta => Rdb::Mytable->meta,
	});

=back

To link the data with a Gtk window, the Gtk entries id in the glade file have to be set to the names of the database fields

	  $self->{linker} = Gtk2::Ex::DbLinker::Form->new({ 
		    data_manager => $rdbm,
		    builder =>  $builder,
		    rec_spinner => $self->{dnav}->get_object('RecordSpinner'),
  	    	    status_label=>  $self->{dnav}->get_object('lbl_RecordStatus'),
		    rec_count_label => $self->{dnav}->get_object("lbl_recordCount"),
	    });

To add a combo box in the form, the first field given in fields array will be used as the return value of the combo. 
noed is the Gtk2combo id in the glade file and the field's name in the table that received the combo values.
	 
	my $dman = Gtk2::Ex::DbLinker::RdbDataManager->new({data => Rdb::Combodata::Manager->get_combodata(sort_by => 'name' ), meta => Rdb::Combodata->meta });

	$self->{linker}->add_combo({
    	data_manager => $dman,
    	id => 'comboid',
	fields => ["id", "name"],
      });

And when all combos or datasheets are added:

      $self->{linker}->update;
  
To change a set of rows in a subform, use and on_changed event of the primary key in the main form and call

		$self->{subform_a}->on_pk_changed($new_primary_key_value);

In the subform a module:

	sub on_pk_changed {
		 my ($self,$value) = @_;
		my $data =  Rdb::Mytable::Manager->get_mytable(query => [pk_field => {eq => $value}]);
		$self->{subform_a}->get_data_manager->query($data);
		$self->{subform_a}->update;
		

=head1 DESCRIPTION

This module fetch data from a dabase using Rose::DB::Object derived objects. 

A new instance is created using an array of objects issue by a Rose::DB::Object::Manager child and this instance is passed to a Gtk2::Ex::DbLinker::Form object or by Gtk2::Ex::DbLinker::Datasheet objet constructor.

=head1 METHODS

=head2 constructor

The parameters are passed in a hash reference with the keys C<data> and C<meta>.
The value for C<data> is a reference to an array of Rose::SB::Object::Manager derived objects. The value for C<meta> is the corresponding metadata object.

		my $data = Rdb::Mytable::Manager->get_mytable(query => [pk_field => {eq => $value }]);
		my $dman = Gtk2::Ex::DbLinker::RdbDataManager->new({data=> $data, meta => Rdb::Mytable->meta });

Array references of primary key names and auto incremented primary keys may also be passed using  C<primary_keys>, C<ai_primary_keys> as hash keys. If not given the RdbDataManager uses the metadata to have these.

=head2 C<query( $data );>

To display an other set of rows in a form, call the query method on the datamanager instance for this form with a new array of Rose::DB::Object derived objects.

	my $data =  Rdb::Mytable::Manager->get_mytable(query => [pk_field => {eq => $value}]);
	$self->{form_a}->get_data_manager->query($data);
	$self->{form_a}->update;

The methods belows are used by the Form module and you should not have to use them directly.


=head2 C<new_row();>

=head2 C<save();>

=head2 C<delete();>

=head2 C<set_row_pos( $new_pos ); >

change the current row for the row at position C<$new_pos>.

=head2 C<get_row_pos();>

Return the position of the current row, first one is 0.

=head2 C<set_field ( $field_id, $value);>

Sets $value in $field_id. undef as a value will set the field to null.

=head2 C<get_field ( $field_id );>

Return the value of a field or undef if null.

=head2 C<get_field_type ( $field_id );>

Return one of varchar, char, integer, date, serial, boolean.

=head2 C<row_count();>

Return the number of rows.

=head2 C<get_field_names();>

Return an array of the field names.

=head2 C<get_primarykeys()>;
	
Return an array of primary key(s) (auto incremented or not).

=head2 C<get_autoinc_primarykeys()>;
	
Return an array of primary key(s).

=head1 SUPPORT

Any Gk2::Ex::DbLinker questions or problems can be posted to the the mailing list. To subscribe to the list or view the archives, go here: 
L<http://groups.google.com/group/gtk2-ex-dblinker>. 
You may also send emails to gtk2-ex-dblinker@googlegroups.com. 

The current state of the source can be extract using Mercurial from
L<http://code.google.com/p/gtk2-ex-dblinker/>.

=head1 AUTHOR

FranE<ccedil>ois Rappaz <rappazf@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014 by F. Rappaz.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Gtk2::Ex::DbLinker::Forms>

L<Gtk2::Ex::DbLinker::Datasheet>

L<Rose::DB::Object>
  
=head1 CREDIT

John Siracusa and the powerfull Rose::DB::Object ORB.

=cut

