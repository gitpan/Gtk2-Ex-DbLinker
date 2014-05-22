package Gtk2::Ex::DbLinker::DbcDataManager;
use  Gtk2::Ex::DbLinker;
our $VERSION = $Gtk2::Ex::DbLinker::VERSION;

use Class::Interface;

&implements('Gtk2::Ex::DbLinker::AbDataManager');

use strict;
use warnings;
use  Carp;
use Data::Dumper;

$Class::Interface::CONFESS = 1;


my %fieldtype = (
	tinyint => 'integer',
);


#$self->{rs} holds a RecordSet that is a query def of the data to fetch from the database.
#$self->{data} holds an array ref of array ref of primary key values, in most case this second array will hold one value.
#$self->{current_row} holds a ref to the current row, that comes from  $self->{rs}->find(@{ $self->{data}[$pos] });
#This is called on each set_row_pos( $new_pos ) call

sub new {
	 my ( $class, $req ) = @_;
	my $self = {
		page => $$req{pate} || 1,
		rec_per_page => $$req{rec_per_page} || 1,
		rs => $$req{rs},
		primary_keys => $$req{primary_keys},
		ai_primary_keys => $$req{ai_primary_keys},

	 };
	 $self->{log} = Log::Log4perl->get_logger(__PACKAGE__);

	 bless $self, $class;
	
	$self->_init;
	 $self->_init_pos;

	 return $self;
}

sub query{
	my ($self, $rs) =  @_;
		$self->{rs} = $rs;
	$self->{log}->debug("query " . ($self->{cols} ? @{$self->{cols}} : " cols undef "));
	#try to initiate cols as long as it's not done (the array referer by $self->{cols} is empty)
	#the line defined cols the first time a row is fetched
	# print Dumper($self->{cols});
	$self->_init_pos;
	$self->_init if ( @{$self->{cols}} == 0);
	# $self->{log}->debug("query : " . @$data[0]->noti ) if (scalar @$data > 0);
	foreach my $pkr (@{$self->{data}}){
		# print Dumper($pkr);
		foreach my $pkn (@{$self->{primary_keys}}){
			my $i = 0;
			$self->{log}->debug( "pk name: " . $pkn . " pk value : " . $$pkr[$i++] );
		}
	}


} 

sub set_row_pos{
	my ($self, $pos) = @_;
	my $found=1;
	# $self->{log}->debug("new_row is " . ($self->{new_row} ? " defined" : " undefined"));
	if ( ! defined ($self->{row}->{pos})){ 
		$self->{log}->debug("not data");
		$found = 0;
	} elsif ($pos <= $self->{row}->{last_row} + 1 && $pos >=0) {
		$self->{row}->{pos}= $pos;
		# $self->{log}->debug("set_row at pos : " . $pos . " pk: " . join(" ", @{ $self->{data}[$pos] }) . " class: " . $self->{rs}->result_class);	
		#die Dumper( $self->{data}[$pos] );
		$self->{current_row} =  $self->{rs}->find(@{ $self->{data}[$pos] });
	
		
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
		
		$row = $self->{current_row};
	}

	$row->set_column($id, $value) ; #or die(__PACKAGE__ . " no method found to set value " . $value . " in the column " . $id . " entries are ".  join(" ", keys %{ $self->{fieldSetter} }));
}

sub get_field{
	my ($self, $id) = @_;
	#my $pos =  $self->{row}->{pos};
	#my $row = $self->{rs}->find(@{$self->{data}[$pos]});
	my $row = $self->{current_row};
	# $self->{log}->debug("get_field " . $id . " " . $m);
	return $row->get_column($id); # or die(__PACKAGE__ . " no method found to get value from the column " . $id);;

}

sub save{
	my $self = shift;
	my $row;
	my $result;
	if ($self->{new_row}){
		$self->{log}->debug(" save new row " );
		$row = $self->{new_row};
		#$row->update;
		$result = $row->insert;
		$self->{log}->debug(" insert return ". ($result ? " def": " undef"));
		my @pk_val;
		for my $pk ($row->primary_columns){
			my $pkval =  $row->get_column($pk);
			$self->{log}->debug("pk after insert: " . $pkval);
			push @pk_val, $pkval;
		}
		push @{$self->{data}}, \@pk_val ;
		my $last = $self->row_count-1;
		$self->{row} = {pos => $last, last_row => $last};
		$self->set_row_pos($last);	
	
	} else {
		$self->{log}->debug(" save at " . $self->{row}->{pos} );
		my $pos = $self->{row}->{pos};
		#$row =  $self->{rs}->find(@{$self->{data}[$pos]});
		$row = $self->{current_row};
		$result = $row->update;
	}
	$self->{log}->debug("saving and unsetting new row");
	#$row->save;
	#don't delete new_row is inserting in the db gets wrong
	if ($result) {
		$self->{new_row} = undef;
	}
}
sub new_row {
	my ($self ) = @_;
	#return if ($self->{new_row});
	my $rs =  $self->{rs};
	my %hash   = map { $_, undef } @{$self->{primary_keys}};
	#my %hash   = map { $_, undef } @{$self->{cols}};
	my $row = $rs->new_result(\%hash);
	$self->{new_row} = $row;
	$self->{row}->{pos} = $self->{row}->{last_row} + 1;
	$self->{log}->debug("new_row");
	
}

sub delete{
	my $self = shift;
	$self->{log}->debug(" delete at " . $self->{row}->{pos} );
	my $pos = $self->{row}->{pos};
	if ( defined $pos) {
		# my $row = $self->{rs}->find( @{$self->{data}[$pos]} );
		my $row = $self->{current_row};
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

sub get_autoinc_primarykeys {
	my $self = shift;
	return @{$self->{ai_primary_keys}};
}

sub get_primarykeys {
	my $self = shift;
	return @{$self->{primary_keys}};
}

sub _init_pos {
	my $self = shift;
	 my $rs = $self->{rs};
	 my @data;
	 
	 my @pks = $rs->search(undef, {columns => $self->{primary_keys} });

	for my $pk (@pks){
		my @pkv;
		#$self->{log}->debug(join(" ", @{$self->{primary_keys}}));

		for my $pkname (@{ $self->{primary_keys} }){
			#$self->{log}->debug("pk name : " . $pkname . " value : " . $pk->get_column($pkname));
			push @pkv, $pk->get_column($pkname);
			
		}

		push @data, \@pkv;
	}
	$self->{data} = \@data;


#$self->{data}= \@pks;
	
	my $count = scalar @{ $self->{data} };
	 if ($count > 0) {
		
		$self->{row} = {pos=>0, last_row => $count -1 };
	} else {
		$self->{row} = {pos => undef, last_row => undef};
	}

}

sub _init {
	my $self = shift;
	my $rs = $self->{rs};
	my $table = $rs->result_source;
	$self->{class} =  $rs->result_class;
	my @pk;
	if (! defined $self->{primary_keys}) {	
		@pk = $table->primary_columns;
		$self->{primary_keys} = \@pk;
	}
	die ("no pk") if (scalar @pk == 0);
	my @apk;
	if (! defined $self->{ai_primary_keys}) {
		foreach my $c (@pk){
			my $href = $table->column_info($c);
			if ($href->{is_auto_increment}){
				push @apk, $c;
			}
		}
		$self->{ai_primary_keys} =  \@apk;
	}

	my @cols = $table->columns;
	$self->{cols} = \@cols;

	foreach my $id (@{$self->{cols}}){
		my $type =  $table->column_info($id)->{data_type};
		$type = ( exists $fieldtype{$type} ? $fieldtype{$type} : $type);
		$self->{log}->debug("Dbc_dman_init: field " . $id . " type: " . $type);
		$self->{fieldsDBType}->{$id}=  $type;
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
      #set $self->{current_row} with the call below
      $self->set_row_pos( $self->{row}->{pos} );
     return $self->{row}->{pos};

}

1;

__END__

=pod

=head1 NAME

Gtk2::Ex::DbLinker::DbcDataManager - a module used by Form and Datasheet that get data from a database using DBIx::Class objects

=head1 VERSION

See Version in L<Gtk2::Ex::DbLinker>

=head1 SYNOPSIS

	use Gtk2 -init;
	use Gtk2::GladeXML;
	use Gtk2::Ex:Linker::DbcDataManager; 

	my $builder = Gtk2::Builder->new();
	$builder->add_from_file($path_to_glade_file);

	use My::Schema;
	use Gtk2::Ex::DbLinker::DbcDataManager;

Instanciation of a DbcManager object is a two step process:

=over

=item *

use a ResultSet object from the table(s) you want to display
	
	 my $rs = $self->{schema}->resultset('Jrn'); 

=item * 

Pass this object to the DbcDataManager constructor 

	 my $dbcm = Linker::DbcDataManager->new({ rs => $rs});

=back

To link the data with a Gtk window, the Gtk entries id in the glade file have to be set to the names of the database fields

	  $self->{linker} = Linker::Form->new({ 
		    data_manager => $dbcm,
		    builder =>  $builder,
		    rec_spinner => $self->{dnav}->get_object('RecordSpinner'),
  	    	    status_label=>  $self->{dnav}->get_object('lbl_RecordStatus'),
		    rec_count_label => $self->{dnav}->get_object("lbl_recordCount"),
	    });

To add a combo box in the form, the first field given in fields array will be used as the return value of the combo. 
noed is the Gtk2combo id in the glade file and the field's name in the table that received the combo values.
	 
	my $dman = Linker::DbcDataManager->new({rs => $self->{schema}->resultset('Ed')->search_rs( undef, {order_by => ['nom']} ) } );


	$self->{linker}->add_combo({
    	data_manager => $dman,
    	id => 'noed',
	fields => ["id", "nom"],
      });

And when all combos or datasheets are added:

      $self->{linker}->update;
  
To change a set of rows in a subform, use and on_changed event of the primary key in the main form and call

		$self->{subform_a}->on_pk_changed($new_primary_key_value);

In the subform a module:

	sub on_pk_changed {
		 my ($self,$value) = @_;
		# get a new ResultSet object and pass it to query
		my $rs = $self->{schema}->resultset('Table')->search_rs({FieldA=> $fieldA_value},  {order_by => 'FieldB'});
		$self->{subform_a}->get_data_manager->query($rs);
		$self->{subform_a}->update;
	}

=head1 DESCRIPTION

This module fetch data from a dabase using DBIx::Class. 



=head1 METHODS

=head2 constructor

The parameters is passed in a hash reference with the key C<rs>.
The value for C<rs> is a DBIx::Class::ResultSet object.

		my $rs = $self->{schema}->resultset("Table")->search_rs(undef, {order_by => 'title'});
		
		my $dman = Gtk2::Ex::DbLinker::DbcDataManager->new({ rs => $rs});



=head2 C<query( $rs );>

To display an other set of rows in a form, call the query method on the datamanager instance for this form with a new DBIx::Class::ResultSet object.

	my $rs = $self->{schema}->resultset('Books')->search_rs({no_title => $value});
	$self->{form_a}->get_data_manager->query($rs);
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
	
Return an array of auto incremented primary key(s).

=head1 AUTHOR

FranE<ccedil>ois Rappaz <rappazf@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014 by FranE<ccedil>ois Rappaz.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Gtk2::Ex::DbLinker::Forms>
L<Gtk2::Ex::DbLinker::Datasheet>
L<DBIx::Class>
  
=head1 CREDIT



=cut

