package Gtk2::Ex::DbLinker::Form;
use  Gtk2::Ex::DbLinker;
our $VERSION = $Gtk2::Ex::DbLinker::VERSION;

use strict;
use warnings;
use Glib qw/TRUE FALSE/;
use Carp;
use DateTime::Format::Strptime;

my %fieldtype = (
varchar => "Glib::String" ,
char =>"Glib::String" ,
integer => "Glib::Int",
boolean =>  "Glib::Boolean",
date => "Glib::String",
serial=> "Glib::Int",
text => "Glib::String",

);
my %signals = (
	'GtkCalendar' => 'day_selected',
	'GtkToggleButton' => 'toggled',
	'GtkTextView' => 'changed',
	'GtkComboBoxEntry' => 'changed',
	'GtkComboBox' => 'changed',
	'GtkCheckButton' => 'toggled',
	'GtkEntry' => 'changed',
	'GtkSpinButton' => 'value_changed'
);


#
#coderef to place the value of record x in each field, combo, toggle...
#
my %setter = (
	'GtkEntry' => \&_set_entry,
	'GtkToggleButton' => \&_set_check,
	'GtkComboBox' => \&_set_combo,
	'GtkComboBoxEntry' => \&_set_combo,
	'GtkCheckButton' => \&_set_check,
	'GtkSpinButton' => \&_set_spinbutton,
	'GtkTextView' => \&_set_textentry

);

my %getter = (
	 'GtkEntry' => sub {my $w = shift; return $w->get_text;},
	'GtkToggleButton' => sub { return shift->get_active;},
	'GtkComboBox' => , \&_get_combobox_firstvalue,
	'GtkComboBoxEntry' =>  \&_get_combobox_firstvalue,
	'GtkCheckButton' => sub { return shift->get_active;},
	'GtkSpinButton' => sub { return shift->get_active;},
	'GtkTextView' => sub {return shift->get_child->get_text; },

);



# 	'GtkSpinButton' => \&set_spinbutton,
# sub {return shift->child->get_text; },
# sub {my $c = shift; print "getter_cbe\n"; my $iter = $c->get_active_iter; return $c->get_model->get( $iter ); }
#
sub new {
	my ($class, $req)=@_;

	my $self ={
		dman => $$req{data_manager},
		cols => $$req{datawidgets},
		null_string => $$req{null_string} || "null",
		builder => $$req{builder},
		after_insert => $$req{after_insert},
		rec_spinner => $$req{rec_spinner} || "RecordSpinner",
		status_label => $$req{status_label} || "lbl_RecordStatus",
		rec_count_label => $$req{rec_count_label} || "lblRecordCount",
		on_current =>  $$req{on_current},
		date_formatters => $$req{date_formatters},
		time_zone => $$req{time_zone},
		locale => $$req{locale} || 'fr_CH',
	
	};
	 bless $self, $class;

	 #$self->{cols} = [];
	 $self->_init;
 	my @dates;


	#my %formatters_db;
	#my %formatters_f;
	 # $self->{dates_formatted} = \(keys %{$self->{date_formatters}});
	foreach my $v ( keys %{$self->{date_formatters}}){
		$self->{log}->debug("** " . $v . " **");
		push @dates, $v;
	}
	 $self->{dates_formatted} = \@dates;
 	$self->{dates_formatters} = {};

 	$self->{pos2del} = [];

	return $self;
  
} #new


sub _init {

	my ($self) = @_;
	$self->{painting}=1;
	# get a ref to the Gtk widget used for the record spinner or if the id has been guiven, get the ref via the builder
	$self->{rec_spinner} =(ref $self->{rec_spinner} ? $self->{rec_spinner} : $self->{builder}->get_object( $self->{rec_spinner} ));
	$self->{rec_count_label} = (ref $self->{rec_count_label} ? $self->{rec_count_label} : $self->{builder}->get_object( $self->{rec_count_label} ));
	$self->{status_label} = (ref $self->{status_label} ?  $self->{status_label} : $self->{builder}->get_object( $self->{status_label} ));

	$self->{log} = Log::Log4perl->get_logger("Gtk2::Ex::DbLinker::Form");
	$self->{log}->debug(" ** New Form object ** ");
	$self->{changed} = 0;
	if (! defined $self->{cols}){
		my @col = $self->{dman}->get_field_names;
		$self->{cols} = \@col;
	}

	$self->_bind_on_changed;
	$self->_set_recordspinner;
	$self->{dman}->set_row_pos(0);
}



#dman must contains all the rows 
sub add_combo{
	my ($self, $req)=@_;

	my $combo = {
		dman => $$req{data_manager}, 
		id => $$req{id},
		fields=> $$req{fields},

	};

     my $column_no = 0;
    my @list_def;
    if ( $$req{builder} && (ref $self eq "")){ #static init
	  
	$self = {};
	$self->{builder} = $$req{builder};
	my @cols = $combo->{dman}->get_field_names;
	$self->{cols} = \@cols;
	$self->{log} = Log::Log4perl->get_logger("Gtk2::Ex::DbLinker::Form");
	$self->{log}->debug("cols: " . join(" ", @{$self->{cols}}));        
	 my $w = $self->{builder}->get_object($combo->{id});
	 if ($w)   {
		 my $name = $w->get_name;
 		$self->{datawidgets}->{ $combo->{id} } = $w;
		$self->{datawidgetsName}->{ $combo->{id} }= $name;	
	      } else {
		      croak "no widget found for combo " . $combo->{id};
	      }
    }
    my $w = $self->{datawidgets}->{$combo->{id}};
    die unless ($w); 
    my @col;
    if ( ! defined $combo->{fields}) {
	    #@col    = get_columns($self, $combo->{data}->[0]->meta) if ($combo->{data}->[0]);
	    @col = $combo->{dman}->get_field_names;
	    $self->{log}->debug("add_combo : dman says cols are : " . join(" ", @col));
    } else {
	 @col = @{$combo->{fields}} ;  
    }
    
   croak ("no fields found for combo $combo->{id}") unless(@col);

    foreach my $field ( @col ) {
	#push @list_def, "Glib::String"; 
	my $type =  $combo->{dman}->get_field_type($field);
	$self->{log}->debug("type : " . $type);
	my  $gtype = $fieldtype{ $type };
	push @list_def, $gtype;
        $self->{log}->debug("add_combo: $field $column_no $gtype");
        # Add additional renderers for columns if defined
        # We only want to do this the 1st time ( renderers_setup flag ), otherwise we get lots of renderers 
        	if ( $column_no > 0 && ! $combo->{renderers_setup} ) {
			
             		$self->{log}->debug("new renderer for $column_no");
            		my $renderer = Gtk2::CellRendererText->new;
		            $w->pack_start( $renderer, FALSE );
			    # $self->{log}->debug("add_combo: " . $field . " set text for " . $column_no);
			    # done below with the entrycompletion setup
			    # $w->set_attributes( $renderer, 'text' => $column_no );
            
        	}
        	$column_no ++;
	}
    	$combo->{renderers_setup} = 1;

	my $model = Gtk2::ListStore->new( @list_def );
	$self->{log}->debug(join(" ", @list_def));
	my $i;
	 my $last = $combo->{dman}->row_count -1 ;
	 
	 for  ($i = 0; $i <= $last; $i++) {
		#$row = $d->column_accessor_value_pairs;
		
		$combo->{dman}->set_row_pos($i);
		 my @model_row;
        	my $column = 0;
        	push @model_row, $model->append;
        
        	foreach my $field ( @col ) {
			#push @model_row, $column, $row->{$field};
		  my $value =  $combo->{dman}->get_field($field);
		  #$self->{log}->debug("add_combo: " . $value);
		   push @model_row, $column++, $value;
		   #$column ++;
        	}
		#$self->{log}->debug("row : " . join(" ", @model_row));
	        $model->set( @model_row );
	}
	$self->{log}->debug("add_combo: " . $i . " rows added");

	$w->set_model($model);

	if ($self->{datawidgetsName}->{$combo->{id}} eq "GtkComboBoxEntry" ){
		#if ( ! $self->{combos_set}->{$combo->{id}} ) {
			$w->set_text_column( 1 );
		#$self->{combos_set}->{ $combo->{id} } = TRUE;
		  #}
		   my $entrycompletion = Gtk2::EntryCompletion->new;
		  $entrycompletion->set_minimum_key_length( 1 );
		  $entrycompletion->set_model( $model );
		  $entrycompletion->set_text_column( 1 );
		  $w->get_child->set_completion( $entrycompletion );
	
	}


} #sub



sub _display_data {
	my ($self, $pos ) = @_;
	#  $self->{log}->debug( "display_data for row at pos " . $pos );

	my $dman = $self->{dman};

	$self->{pos} = $pos;

	$dman->set_row_pos($pos) unless ($pos<0);

	$self->{painting}=1;
	#foreach my $id (keys %{$self->{datawidgets}}){
	foreach my $id (@{$self->{cols}}) {
		
		my $w = $self->{datawidgets}->{$id};
		my $name = $self->{datawidgetsName}->{$id};
		my $x;
		#my $row = $self->{data}[$pos];
	
		if ($pos < 0) {
			$x= undef;	
		} else {
			#$x = $row->$id() if ($row);
			$x = $dman->get_field($id);
					if (ref $x) {
						# my @set = $row->$id(); 
						my @set = $dman->get_field($id);
						$x = join(',', @set);
							$self->{log}->debug( "id: " . $id . " gtkname : " . $name . " ref value: " . ($x?ref($x):"") .  " value: " . ($x?$x:"") . " type : ". $self->{dman}->get_field_type($id) );

					}

		}
	
		# $w->signal_handler_block()

		if ( $id ~~ @{$self->{dates_formatted}}){
			#$x = $self->_dateformatter($self->{date_formatters}->{$id}, $x);
			if ( defined $x){
				#my $ff = $self->{dates_formatters_f}->{$id};
				#my $fdb = $self->{dates_formatters_db}->{$id};
				# $self->{log}->debug("display_data formatted received date: ". $x);
				$x = $self->_format_date(0, $id, $x);


			}
		}

		$setter{$name}($self, $w, $x) if($name && $setter{$name});
	}
	#$self->{pos}= $pos;
   my $first = ($pos < 0 ? 0 : 1);
  
   $self->_set_record_status_label;
   $self->_set_rs_range($first);
   $self->{on_current}() if ($self->{on_current});
   $self->{painting}=0;
   $self->{changed}=0;

}


sub undo{
	my $self = shift;
	 $self->{changed}=0;
	 $self->{pos2del}= [];
	 $self->_display_data( $self->{pos}  );

	  if ($self->{rec_spinner}){
		$self->{rec_spinner}->signal_handler_block( $self->{rs_value_changed_signal} );
       		$self->{rec_spinner}->set_value($self->{pos} + 1);
	        $self->{rec_spinner}->signal_handler_unblock( $self->{rs_value_changed_signal} );
	}
}

sub insert {
	my $self = shift;
	$self->{log}->debug("insert");
	# my $row = $self->{data}[0]->new;

	#$self->{pos} = $self->{count} + 1;
	#afficher des champs vides
	$self->_display_data(-1);
	#data_manager->new_row is called when apply is cliked
	   if ($self->{rec_spinner}){
		  #	my $last = $self->{dman}->row_count;
		$self->{rec_spinner}->signal_handler_block( $self->{rs_value_changed_signal} );
        	$self->{rec_spinner}->set_value(0);
	        $self->{rec_spinner}->signal_handler_unblock( $self->{rs_value_changed_signal} );
		 
    
    	} 

}

sub delete {
	my $self = shift;
	$self->{log}->debug("Linker::Main delete at " . $self->{dman}->get_row_pos );
	#my $pos = $self->{pos};
	#my $row =  $self->{data}[$pos];
	#$row->delete;
	#$self->next;
	$self->{changed} = 1;
	# $self->{dman}->delete;
	push @{$self->{pos2del}}, $self->{dman}->get_row_pos;
	#$self->set_rs_range(1);
	$self->_set_record_status_label;


}



sub apply{
	my $self = shift;
	my $row;
	#we are adding a new record if $pos < 0
	$self->{log}->debug("apply: pos : " . $self->{pos} );
	if ($self->{pos}<0){
		#my $class =  $self->{class};
		#$row = $class->new;
		 $self->{dman}->new_row;
			#push @{$self->{data}}, $row;
			 # $self->{count} ++;
		 $self->{log}->debug("New row");
		 # $self->{dman}->set_row_pos($self->{dman}->row_count);
		
	}

	# deleting a (or some) record	
	for my $p (@{$self->{pos2del}}){
		$self->{dman}->set_row_pos($p);
		$self->{dman}->delete;
	}
	$self->{log}->debug("items in pos2del: " . scalar @{ $self->{pos2del} } );
	if (scalar @{$self->{pos2del}}){
		$self->{pos2del} = [];
		$self->{changed} = 0;
		# $self->set_record_status_label;
		$self->{rec_spinner}->set_value(1) if ($self->{rec_spinner});
		return;
	}
	#updating a new or an existing record
	#foreach widget in the form, get the value from the widget and place it in the field unless it's a primary key 
	#with an autogenerated value
	my @pk;
	$self->{log}->debug("cols: " . join(" ", @{$self->{cols}}));
	foreach my $id (@{$self->{cols}}){
		if (exists  $self->{datawidgets}->{$id}){
			my $w = $self->{datawidgets}->{$id};
			$self->{log}->debug($self->{datawidgetsName}->{$id});
			my $coderef = $getter{ $self->{datawidgetsName}->{$id} };
			
			my $v  = &$coderef( $w );
		
			$self->{log}->debug("apply id: $id value: ".  ($v?$v:""));

			@pk = $self->{dman}->get_autoinc_primarykeys;

			if ($id ~~ @pk)  {
				$self->{log}->debug("not done because it's a auto incremented pk");
			} else {
		
				$v = ($v eq "" ? undef : $v);
				$self->{log}->debug($id  . ": value undef") unless ( defined $v);	
				if ( defined $v && ( $id ~~ @{$self->{dates_formatted}})){
					#my $ff = $self->{dates_formatters_f}->{$id};
				
					#my $date = $ff->parse_datetime($v);
					$v = $self->_format_date(1, $id, $v);
				
					# $v = $self->{dates_formatters_db}->{$id}->format_datetime($date);
					#$v = $self->dateformatter('%Y-%m-%d', $date);
				}

				if ($self->{pos} < -1 ) {
					$self->{log}->debug("current row pos: " . $self->{dman}->get_row_pos);
				# $self->{log}->debug("last row pos: " . $self->{dman}->row_count -1);
				# $self->{dman}->set_row_pos($self->{dman}->get_row_count);
					$self->{dman}->set_field($id, $v);
				} else {
			
					$self->{dman}->set_field($id, $v);
				}
				 $self->{log}->debug("done");
			} # not in @pk
	   }	# if exists
	   else {
		$self->{log}->debug($id . " not in data");
	   }
	} #foreach
	#$row->save;
	$self->{dman}->save;
	# $self->{log}->debug("nofm: " . $row->nofm);
	# $self->set_rs_range;

	#if we were adding a row, put it at the end of the array, and display all the values in the form
	#ie the value from the user or default value from the database.
	my %pk_val;	


	for my $pk (@pk) {
		$self->{log}->debug("Primary Key: " . $pk);
		my $value = $self->{dman}->get_field($pk);
		#if (my $ref = eval { $row->can( $pk ) }) {
			#$value = $row->$ref();

			$pk_val{$pk} = $value;
		#}
	}
			#push @pk_val, $id
		
	if ($self->{after_insert}){
		my $coderef = $self->{after_insert};
		&$coderef(undef, \%pk_val );
	}
	if ($self->{pos}<0){
		my $last = $self->{dman}->row_count -1;
		$self->{log}->debug("last is " . $last );
		$self->_display_data( $last );
		 if ($self->{rec_spinner}){
		  #	my $last = $self->{dman}->row_count;
			$self->{rec_spinner}->signal_handler_block( $self->{rs_value_changed_signal} );
        		$self->{rec_spinner}->set_value($last+1);
	        	$self->{rec_spinner}->signal_handler_unblock( $self->{rs_value_changed_signal} );
    		}
       	} else {
		$self->{changed}=0;
	
	}
	$self->_set_record_status_label;
}

sub next{
	my $self = shift;
	$self->_display_data($self->{dman}->next);
}

sub previous {
	my $self = shift;
	#$self->move(-1);
	$self->_display_data($self->{dman}->previous);
}
 
sub first{
	my $self = shift;
	# $self->move(undef, 0);
	$self->_display_data($self->{dman}->first);
}

sub last {
	my $self = shift;
	#$self->move(undef, $self->count() -1);
	$self->_display_data($self->{dman}->last);
}



#bind an onchanged sub with each modification of the datafields
sub _bind_on_changed {
	my $self = shift;
# my @cols = $self->{dman}->get_field_names;
 foreach my $id ( @{$self->{cols}} ){
	 my $w = $self->{builder}->get_object($id);
	 $self->{log}->debug("bind_on_changed looking for widget " . $id);
	 if ($w)   {
		 my $name = $w->get_name;
 		$self->{datawidgets}->{$id} = $w;
		$self->{datawidgetsName}->{$id}= $name;
		$self->{log}->debug("bind  $name $id with self->changed \n");
		$w->signal_connect_after( $signals{$name} => sub{ $self->_changed( $id )});
	} else {$self->{log}->debug(" ... not found ");}
   }
 
}



# Associe une fonction sur value_changed du record_spinner qui appelle move avec abs: valeur lue dans l'etiquette du recordspinner
# Place 
sub _set_recordspinner {
	my $self = shift;
	$self->{log}->debug("set_recordspinner");

    # die unless($self->{rec_spinner});
 my $coderef;
    if ( $self->{rec_spinner} ) {
#	    The return type of the signal_connect() function is a tag that identifies your callback function. 
#	    You may have as many callbacks per signal and per object as you need, and each will be executed in turn, 
#	    in the order they were attached. 
        $coderef  = $self->{rec_spinner}->signal_connect_after(	value_changed => sub {
			my $pos = $self->{rec_spinner}->get_text -1;
		        $self->{log}->debug("rs_value changed will move to " . $pos);	
			$self->{rec_spinner}->signal_handler_block( $coderef );
			#$self->move( undef, $pos);
			$self->{dman}->set_row_pos($pos);
			$self->_display_data($pos);
                        $self->{rec_spinner}->signal_handler_unblock( $coderef );
                        return TRUE;
                    } 
              );
	      $self->{rs_value_changed_signal}= $coderef;
	      $self->{log}->debug("recordspinner set");
    }

}



sub _set_rs_range {
    my ( $self, $first ) = @_;

    # Convenience function that sets the min / max value of the record spinner
    	$self->{log}->debug("set_rs_range  first : " . $first);
    if ( $self->{rec_spinner} ) {
	    my $ad = $self->{rec_spinner}->get_adjustment;
	    $self->{log}->debug("adj lower : ". $ad->lower);
	 if ($first < $ad->lower){ $ad->lower($first); $self->{rec_spinner}->set_adjustment( $ad ); }
        $self->{rec_spinner}->signal_handler_block( $self->{rs_value_changed_signal} );
        $self->{rec_spinner}->set_range( $first, $self->{dman}->row_count );
        $self->{rec_spinner}->signal_handler_unblock( $self->{rs_value_changed_signal} );
    }
    $self->{rec_count_label}->set_text(" / " . $self->{dman}->row_count);
    return TRUE;
    
}

sub _set_entry {
	my ($self, $w, $x) = @_;
	if (defined $x){
	$self->{log}->debug("set_entry: " . $x);
		$w->set_text( $x ) ;
	} else {
		$self->{log}->debug("set_entry: text entry undef " . $w->get_name) ;
		$w->set_text("");
	}

}

sub _set_textentry {
	my ($self, $w, $x) = @_;
 	$self->{log}->debug("set_textentry text entry undef") if (undef $x);
	$w->get_buffer->set_text($x || "");

}

sub _set_combo {
	my ($self, $w, $x) = @_;
	$self->{log}->debug("set_combo value " . ($x ? $x : " undef") . " widget: ". ref $w );
	my $m = $w->get_model;
	my $iter = $m->get_iter_first;
	 
        if ( ref $w eq "Gtk2::ComboBoxEntry" ) {
             $w->get_child->set_text( "" );
	}
            
        my $match_found = 0;
            
        while ( $iter ) {
           if ( ( defined $x ) && ( $x eq $m->get( $iter, 0 ) ) ) {
                        $match_found = 1;
                        $w->set_active_iter( $iter );
                        last;
                }
                $iter = $m->iter_next( $iter );
        }
           if ( ! $match_found && $x ) {
                $self->{log}->debug( "Failed to set " . ref $w . " to $x\n" );
	}
            	

}


sub _set_check {
	my ($self, $w, $x) = @_;
	$w->set_active( $x );
}

sub _get_combobox_firstvalue  {
	my ($c) = @_; 
	print "getter_cb\n"; 
	my $iter = $c->get_active_iter; 
	return ($iter ? $c->get_model->get( $iter,0) : undef ); 
}


sub _set_spinbutton {
	my ($self, $w, $x) = @_;
	if ($self->getID($w) eq $self->getID($self->{rec_spinner})) {$self->{log}->debug("Found record_spinner... leaving"); return;}
	$w->set_value( $x || 0 );


}


sub _changed {
	 my ( $self, $fieldname ) = @_;
	 # $self->{log}->debug("self->changed for $fieldname");
	if (! $self->{painting}){
	    $self->{changed}=1;
	    $self->_set_record_status_label;
    	}
	return FALSE;


}


sub _set_record_status_label {

    my $self = shift;
    
    # $self->{log}->debug("set_record_satus_label changed is " . $self->{changed});
    
    if ( $self->{status_label} ) {
        if ( $self->{data_lock} ) {
             $self->{status_label}->set_markup( "<b><i><span color='red'>Locked</span></i></b>" );
        } elsif ($self->{changed}) {
			  
            $self->{status_label}->set_markup( "<b><span color='red'>Changed</span></b>" );
            
	} else {
            $self->{status_label}->set_markup( "<b><span color='blue'>Synchronized</span></b>" );
        }
    }
}

sub set_widget_value {
	my ($self, $wid, $x) = @_;
	$self->{log}->debug("set_widget_value: " . $wid . " to " . $x); 
	my $w = $self->{builder}->get_object($wid);
	if ($w) {
		my $coderef = $setter{ $self->{datawidgetsName}->{$wid} };
		&$coderef($self, $w, $x ); 
	}

}

sub get_widget_value {
	my ($self, $wid) = @_;
	my $x;
	$self->{log}->debug("get_widget_value: " . $wid);
	my $w = $self->{builder}->get_object($wid);
	$self->{log}->debug("no widget found") unless ($w);
	if ($w && $self->{datawidgetsName}) {
		my $coderef = $getter{ $self->{datawidgetsName}->{$wid} };
		$x  = &$coderef( $w ); 
	}

	return ($x ? $x: "");
}


sub update{
	my ($self) =  @_;
	my @col = $self->{dman}->get_field_names;
	$self->{log}->debug("query " . (@col ? join(" " , @col) : " cols undef "));
	if ( $self->{dman}->row_count > 0) {
		$self->_display_data(0); 
	} else {
		$self->_display_data(-1)
	}
}

#parameter $in_db is 0 or 1 : 
# 0 we are reading from the db, and the format to use are at the pos 0 and 1 in the array of format for the field
# 1 we are writing to the db and the format are to use in a revers order
# $id is the field id
# $v the date string from the form (if in_db is 1) or from the db (if in_db is 0)
sub _format_date{
	my ($self, $in_db, $id,  $v) = @_;
	$self->{log}->debug("format_date received date: ". $v);
	my ($pos1, $pos2 ) = ( $in_db ? (1, 0) : (0, 1));
	my $format =  $self->{date_formatters}->{$id}->[$pos1];
	my $f = $self->_get_dateformatter($format);
	my $dt = $f->parse_datetime($v) or croak($f->errstr);
	$self->{log}->debug("format_date:  date time object ymd: " . $dt->ymd);
	$format = $self->{date_formatters}->{$id}->[$pos2];
	$f = $self->_get_dateformatter($format);
	my $r = $f->format_datetime($dt)  or croak($f->errstr);
	$self->{log}->debug("format_date formatted date: ". $r);

	return $r;	

	
}
# create a formatter if none is found in the hash for the corresponding formatting string and store it for later use, and return it or
# return an existing formatter 
sub _get_dateformatter {
	my ($self, $format) = @_;
	my %hf = %{$self->{dates_formatters}};
	my $f;
	if (exists $hf{$format}){
		$self->{log}->debug("get_dateformatter : return an existing formatter for " . $format);
		$f = $hf{$format};
	} else {
		$self->{log}->debug("get_dateformatter: new formatter for " . $format);
		$f = new DateTime::Format::Strptime(
                             pattern         => $format,
                                locale      => $self->{locale},
                                time_zone       => $self->{time_zone},
                                on_error        =>'undef',
                        );  
		$hf{$format} = $f;
	
	}
	$self->{dates_formatters} = \%hf;
	return $f;
}

sub get_data_manager{
	return shift->{dman};
}

1;

__END__


=head1 NAME

Gtk2::Ex::DbLinker::Form - a module that display data from a database in glade generated Gtk2 interface

=head1 VERSION

See Version in L<Gtk2::Ex::DbLinker>

=head1 SYNOPSIS

	use My::DbLinker::Form;
	use Rdb::Coll::Manager;
	use Rdb::Biblio::Manager;
	use Gtk2::Ex::DbLinker::RdbDataManager;
	use Gtk2 -init;
	use Gtk2::GladeXML;

	 my $builder = Gtk2::Builder->new();
	 $builder->add_from_file($path_to_glade_file);

	my $data = Rdb::Coll::Manager->get_coll(query => [noti => {eq => $self->{noti}}]);
	my $dman = Linker::RdbDataManager->new({data=> $data, meta => Rdb::Coll->meta });

		$self->{form_coll} = Gtk2::Ex::DbLinker::Form->new({
		data_manager => $dman,
		#meta => Rdb::Coll->meta,
		builder => 	$builder,
	  	rec_spinner => $self->{dnav}->get_object('RecordSpinner'),
	    	status_label=>  $self->{dnav}->get_object('lbl_RecordStatus'),
		rec_count_label => $self->{dnav}->get_object("lbl_recordCount"),
		on_current =>  sub {on_current($self)},
		date_formatters => {datecorr => "%d-%m-%Y",  },
	    });

To display new rows on a bound subform, connect the on_changed event to the field of the primary key in the main form.
In this sub, call a sub to synchonize the form:

In the main form:

    sub on_nofm_changed {
        my $widget = shift;
	my $self = shift;
	my $pk_value = $widget->get_text();
	$self->{subform_a}->synchronize_with($pk_value);
	...
	}

In the subform_a module
	
    sub synchronize_with {
	my ($self,$value) = @_;
	my $data = Rdb::Product::Manager->get_product(with_objects => ['seller_product'], query => ['seller_product.no_seller' => {eq => $value}]);
	$self->{subform_a}->get_data_manager->query($data);	
	$self->{subform_a}->update;
     }

=head2 Dealing with many to many relationship 

It's the sellers and products situation where a seller sells many products and a product is selled by many sellers.
One way is to have a insert statement that insert a new row in the linking table (say transaction) each time a new row is added in the product table.

An other way is to create a data manager for the transaction table

With DBI

	$dman = Linker::DbiDataManager->new({ dbh => $self->{dbh}, sql =>{select =>"no_seller, no_product", from => "transaction", where => ""}});

With Rose::DB::Object

	$data = Rdb::Transaction::Manager->get_transaction(query=> [no_seller => {eq => $current_seller }]);

	$dman = Linker::RdbDataManager->new({data => $data, meta=> Rdb::Transaction->meta});

And keep a reference of this for latter

      $self->{linking_data} = $dman;

If you want to link a new row in the table product with the current seller, create a method that is passed and array of primary key values for the current seller and the new product.

	sub update_linking_table {
	   	my ( $self, $keysref) = @_;
   		my @keys = keys %{$keysref};
		my $f =  $self->{main_form};
		my $dman = $self->{main_abo}->{linking_data};
		$dman->new_row;
		foreach my $k (@keys){
			my $value = ${$keysref}{$k};
			$dman->set_field($k, $value );
		}
		$dman->save;
	}

This method is to be called when a new row has been added to the product table:

	sub on_newproduct_applied_clicked {
		my $button = shift;
	 	my $self = shift;
    		my $main = $f->{main_form};
    		$self->{product}->apply;
		my %h;
		$h{no_seller}= $main->{no_seller};
		$h{no_product}= $self->{abo}->get_widget_value("no_product");
    		$self->update_linking_table(\%h);
	}

You may use the same method to delete a row from the linking table

	my $data = Rdb::Transaction::Manager->get_transaction(query=> [no_seller => {eq => $seller }, no_product=>{eq => $product } ] );
	$f->{linking_data}->query($data);
	$f->{linking_data}->delete;

=head1 DESCRIPTION

his module automates the process of tying data from a database to widgets on a Glade-generated form.
All that is required is that you name your widgets the same as the fields in your data source.

Steps for use:

=over

=item * 

Create a xxxDataManager object that contains the rows to display

=item * 

Create a Gtk2::GladeXML object (the form widget)

=item * 

Create a Gtk2::Ex::DbLinker::Form object that links the data and your form

=item *

You would then typically connect the buttons to the methods below to handle common actions
such as inserting, moving, deleting, etc.

=back

=head1 METHODS

=head2 constructor

The C<new();> method expects a hash reference of key / value pairs

=over

=item * 

C<data_manager> a instance of a xxxDataManager object

=item *

C<builder> a Gtk2::GladeXML builder


=back

The following keys are optional

=over

=item *

C<datawidgets> a reference to an array of id in the glade file that will display the fields

=item * 

C<rec_spinner> the name of a GtkSpinButton to use as the record spinner or a reference to this widget. The default is to use a
widget called RecordSpinner.

=item *

C<rec_count_label>  name (default to "lblRecordCount") or a reference to a label that indicate the position of the current row in the rowset

=item *  

C<status_label> name (default to "lbl_RecordStatus") or a reference to a label that indicate the changed or syncronized flag of the current row

=item *

C<on_current> a reference to sub that will be called when moving to a new record

=item * 

C<date_formatters> a reference to an hash of Gtk2Entries id (keys), and format strings  that follow Rose::DateTime::Util (value) to display formatted Date

=back

=head2 C<add_combo( {	data_manager =E<gt> $dman, 	id =E<gt> 'noed',  fields =E<gt> ["id", "nom"], }); >

Once the constructor has been called, combo designed in the glade file received their rows with this method. 
The parameter is a hash reference, and the key and value are

=over

=item * 

C<data_manager> a dataManager instance that holds  the rows of the combo

=item *

C<id> the id of the widget in the glade file

=item *

C<fields> an array reference holdings the names of fields in the combo (this parameter is needed with RdbDataManager only)

=back

=head2 C< Gtk2::Ex::DbLinker::Form->add_combo({	data_manager =E<gt> $combodata, id =E<gt> 'countryid',	builder =E<gt> $builder,   }); >

This method can also be called as a class method, when the underlying form is not bound to any table. You need to pass the Gtk2::Builder object as a supplemental parameter.

=head2 C<update();>

Reflect in the user interface the changes made after the data manager has been queried, or on the form creation

=head2 C<get_data_manager();>

Returns the data manager to be queried

=head2 C<get_widget_value ( $widget_id );>

Returns the value of a data widget from its id

=head2 C<set_widget_value ( $widget_id, $value )>;

Sets the value of a data widget from its id

=head2 Methods applied to a row of data

=over

=item *

C<insert()>;

Displays an empty rows at position 0 in the record_count_label.

=item *

C<delete();>

Marks the current row to be deleted. The delele itself will be done on apply.

=item *

C<apply():>

Save a new row, save changes on an existing row, or delete the row(s) marked for deletion.

=item *

C<undo();>

Revert the row to the original state in displaying the values fetch from the database.

=item *

C<next();>

=item *

C<previous()>;

=item *

C<first();>

=item *

C<last();>

=back

=head1 SUPPORT



=head1 AUTHOR

 FranE<ccedil>ois Rappaz <rappazf@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2014 by F. Rappaz.  All rights reserved.
This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.


=head1 SEE ALSO

L<Gtk2::Ex::DBI>

=head1 CREDIT

Daniel Kasak
All this Linker things should have been included in his modules...

=cut

1;

