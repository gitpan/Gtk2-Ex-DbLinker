package Gtk2::Ex::DbLinker::Datasheet;
use  Gtk2::Ex::DbLinker;
our $VERSION = $Gtk2::Ex::DbLinker::VERSION;

use strict;
use warnings;
use Glib qw/TRUE FALSE/;

#use Data::Dumper;


use constant {
	UNCHANGED	=> 0,
	CHANGED		=> 1,
	INSERTED	=> 2,
	DELETED		=> 3,
	LOCKED		=> 4,
	STATUS_COLUMN	=> 0
};

my %fieldtype = (
	serial		=> "number",
	varchar 	=> "text",
	char 		=> "text",
	integer 	=> "number",
	enum 		=> "text",
	date 		=> "time",
	boolean 	=> "boolean",
	set 		=> "text",
);

#if number is build with GLib::Int there a default 0 value that is added in a new row and that cannot be reset to undef
#auto incremented primary keys are not correct then.
#Putting Glib::String prevents this

my %render = (
	text => [sub { return Gtk2::CellRendererText->new; }, "Glib::String", ],
	hidden => [sub { return Gtk2::CellRendererText->new; }, "Glib::String" ],
	number => [sub { return Gtk2::CellRendererText->new;}, "Glib::String" ],
	toggle => [sub { return Gtk2::CellRendererToggle->new;}, "Glib::Boolean" ],
	combo => [sub {  return Gtk2::CellRendererCombo->new; }, "Glib::String" ],
	progress => [sub { return Gtk2::CellRendererProgress->new;}, "Glib::Int" ],
	status_column => [sub { return Gtk2::CellRendererPixbuf->new;}, "Glib::Int" ],
	image => [sub { return Gtk2::CellRendererPixbuf->new;}, "Glib::Int"],
	boolean => [sub { return Gtk2::CellRendererText->new;}, "Glib::String" ],
	time => [sub { return Gtk2::CellRendererText->new;}, "Glib::String" ],
);


#
# sub return a ref to the xx_edited sub since this coderef is called as $self->xxx_edited
# $self is the first arg received and @_ holds the rest: hence shift->xxx_edited(@_)
#
#$codref = $signal{$cell_ref};
#to use the coderef, a second code ref is passed to signal_connect, signal => sub { $self->$codref(@_)}
#all this to have $self as the first arg in the xxx_edited sub ...
#
my %signals = (
	'Gtk2::CellRendererText' => [ 'edited' , sub { shift->_cell_edited(@_)}],
	'Gtk2::CellRendererToggle' => ['toggled',  sub { shift->_toggle_edited(@_)}],
	'Gtk2::CellRendererCombo' => ['edited', sub { shift->_combo_edited(@_)}],

);

sub new {
	my ($class, $req) = @_;
	# my $self = $class->SUPER::new();
	 my $self ={
		dman => $$req{data_manager},
		treeview => $$req{treeview},
		fields => $$req{fields}, 
		null_string => $$req{null_string} || "null",
	};
	
	 bless $self, $class;

	 $self->{log} = Log::Log4perl->get_logger("Gtk2::Ex::DbLinker::Datasheet");
	 my @cols = $self->{dman}->get_field_names ;
	 # cols holds the field names from the table. Nothing else !
 	$self->{cols} = \@cols;
	$self->{log}->debug("cols: ". join(" ", @cols));
	
	$self->_setup_fields;

	$self->_setup_treeview;

	return $self;
    
}


sub _setup_fields {
	my ($self) = @_;
	
	
	 # If there are no field definitions, then create some from our fieldlist from the database
    	if ( ! $self->{fields} ) {
    	my $no_of_fields = scalar @{$self->{cols}};
        my $field_percentage = $no_of_fields < 8 ? 100 / $no_of_fields : 12.5; # Don't set percentages < 12.5 - doesn't really work so well ...
        for my $field ( @{$self->{cols}} ) {
		my $gtktype = $fieldtype{ $self->{dman}->get_field_type( $field ) };
            push @{$self->{fields}},
            	{
            		name		=> $field,
            		x_percent	=> $field_percentage,
			renderer	=> $gtktype,
            	};
		$self->{log}->debug(" * set field : " . $field . " renderer : " . $gtktype );
           }
    	}

    # Put a _status_column_ at the front of $self->{fieldlist} and also $self->{fields}
    # so we don't have off-by-one BS everywhere
    # unshift @{$self->{cols}}, "_status_column_";
    
    unshift @{$self->{fields}}, {
        name            => "_status_column_",
        renderer        => "status_column",
        header_markup   => ""
    };

        my $column_no;
	   for my $field ( @{$self->{fields}} ) {
		   # $self->{log}->debug("field name : " . $field->{name});
		    
		   $self->{colname_to_number}->{ $field->{name} } = $column_no;

		    if ( ! $field->{renderer} ) {
			    #my $x = ( $fieldtype{ $self->{fieldsType}->{$field->{name}}}  ?  $fieldtype{$self->{fieldsType}->{$field->{name}}} : "text");
			    my $ftype = $self->{dman}->get_field_type( $field->{name} );
			    my $x = ($fieldtype{ $ftype } ? $fieldtype{ $ftype } : "text");
			    $field->{renderer} = $x;
			    $self->{log}->debug("reset renderer for field " . $field->{name} . " to " . $x);
			   

		    }
		    #if ($field->{renderer} eq "combo") { 
		    #    $self->setup_combo($field->{name});
		    #}
 			$self->{log}->debug(" ** set field : " . $field->{name} . " renderer : " . $field->{renderer});
		     $field->{column} = $column_no++;
	   }
	   #setupfields_end
	   #
} # setup_fields

sub _setup_treeview {
	my ($self) = @_;
	   #setuptreeview
	my $treeview_type = "treeview";
 	$self->{status_icon_width}=0;
	# $self->{treeview} = Gtk2::TreeView->new;
	#
	my @apk = $self->{dman}->get_autoinc_primarykeys;
	$self->{log}->debug("auto inc pk: " . join(" " , @apk));

  my $lastcol = scalar  @{$self->{fields}};
  # additional tree columns to hold the displayed values of the combos
  my @combodata;

	if ( $treeview_type eq "treeview" ) {
        	$self->{icons}[UNCHANGED]   = $self->{treeview}->render_icon( "gtk-yes",                    "menu" );
	        $self->{icons}[CHANGED]     = $self->{treeview}->render_icon( "gtk-refresh",                "menu" );
        	$self->{icons}[INSERTED]    = $self->{treeview}->render_icon( "gtk-add",                    "menu" );
	        $self->{icons}[DELETED]     = $self->{treeview}->render_icon( "gtk-delete",                 "menu" );
        	$self->{icons}[LOCKED]      = $self->{treeview}->render_icon( "gtk-dialog-authentication",  "menu" );
        
        	foreach my $icon ( @{$self->{icons}} ) {
            		my $icon_width = $icon->get_width;
		            if ( $icon_width > $self->{status_icon_width} ) {
                			$self->{status_icon_width} = $icon_width;
            		     }
        	}
        
        # Icons don't seem to take up the entire cell, so we need some more room. This will do ...
        $self->{status_icon_width} += 10;
    	}

	 # Now set up the model and columns
    for my $field ( @{$self->{fields}} ) {
	    

    	 my $renderer = $render{$field->{renderer}}[0]();

	 my $cell_ref = ref $renderer;

	  $self->{log}->debug("Setup tv : field name : " . $field->{name} . " ".  $field->{column} . " ref: " . $cell_ref);

	  push @{ $self->{ $treeview_type . "_treestore_def" } },  $render{$field->{renderer}}[1];;

	if ( $field->{renderer} eq "status_column" ) {
		#	$renderer = Gtk2::CellRendererPixbuf->new;
		#
		#$renderer = $render{$field->{renderer}}[0]();

            	$field->{ $treeview_type . "_column" } = Gtk2::TreeViewColumn->new_with_attributes( "", $renderer );
            	$self->{ $treeview_type }->append_column( $field->{ $treeview_type . "_column" } );
	                # Otherwise set fixed width
                $field->{x_absolute} = $self->{status_icon_width};
                $field->{ $treeview_type . "_column" }->set_cell_data_func( $renderer, sub {  
				my ( $tree_column, $renderer, $model, $iter ) = @_; 
 				my $status = $model->get( $iter, STATUS_COLUMN );
				$renderer->set( pixbuf => $self->{icons}[$status] );
    				return FALSE;
			} );
		
	} else {
		#$renderer = Gtk2::CellRendererText->new;
		#$renderer = $render{$field->{renderer}}();
		# no de la col
		$renderer->{column} = $field->{column};
	  	
		if ( $field->{renderer} eq "toggle") {
			
			$renderer->set(activatable => TRUE);
			# $renderer->set( editable => TRUE );
			$field->{ $treeview_type . "_column" } = Gtk2::TreeViewColumn->new_with_attributes($field->{name}, $renderer, 'active' => $field->{column});
		} elsif ($field->{renderer} eq "combo") {
			 
			my $model = $self->_setup_combo($field->{name});
		        $renderer->set(  editable => TRUE, text_column     => 1,	has_entry   => FALSE,  model => $model );
			 $renderer->{col_data} = $lastcol++ ;

			 	push @combodata, "Glib::String";

			$self->{log}->debug("field name with combo renderer: " . $field->{name} );

			#my $fieldtype = $self->{fieldsType}->{$field->{name}};
			 my $fieldtype = $fieldtype{ $self->{dman}->get_field_type( $field->{name} ) };
			  # $self->{log}->debug("combo field type : " . $fieldtype);
			 if ( $fieldtype eq "number"  ) { # serial, intege but not boolean ...
				 # $renderer->{data_type} = "numeric";
				$renderer->{comp} = sub {my ($a, $b, $c) = @_; return ($c ? ($a == $b) : ($a != $b)); };
	            	} else {
				# $renderer->{data_type} = "string";
				$renderer->{comp} = sub {my ($a, $b, $c) = @_; return ( $c ? ($a eq $b) : ($a ne $b)); };
            		}
			$field->{ $treeview_type . "_column" } = Gtk2::TreeViewColumn->new_with_attributes($field->{name}, $renderer, 'text' => $renderer->{col_data} );

		
		}
		else	{
			$self->{log}->debug("field name with txt renderer: " . $field->{name} );
			
			if ($field->{name} ~~ @apk) {
				$self->{log}->debug("not editable because it's a pk");
				$renderer->set( editable => FALSE );
			} else {
				$renderer->set( editable => TRUE );
			}
			$field->{ $treeview_type . "_column" } = Gtk2::TreeViewColumn->new_with_attributes($field->{name}, $renderer, 'text'  => $field->{column});

		}
	
	 	
		# $self->{log}->debug(ref $renderer . " col: " . $field->{column} );

	     if ( $field->{renderer} eq "hidden" ) {
                $field->{ $treeview_type . "_column" }->set_visible( FALSE );
            } else {

		    #$renderer->signal_connect (edited => sub { $self->cell_edited(@_)});
		     if (exists $signals{$cell_ref}) {
			    $self->{log}->debug(" signal : " . $signals{$cell_ref}[0]);
			    my $coderef =  $signals{$cell_ref}[1];
			    # $renderer->signal_connect ( $signals{$cell_ref}[0] => $coderef, $self );
			     $renderer->signal_connect ( $signals{$cell_ref}[0] => sub { $self->$coderef(@_) } );
		    }

		    
	    }
             

	     $self->{ $treeview_type }->append_column( $field->{ $treeview_type . "_column" } );

	      $field->{ $treeview_type . "_column" }->{renderer} = $renderer;


	     if ( exists $field->{custom_render_functions} ) {
     		          # $self->{suppress_gtk2_main_iteration_in_query} = TRUE;
	             $field->{ $treeview_type . "_column" }->{custom_render_functions} = $field->{custom_render_functions};
               }
        
	 
        } #<> status_col    

	$renderer->{on_changed} = $field->{on_changed};

	 my $label = Gtk2::Label->new;
            
            if ( exists $field->{header_markup} ) {
                $label->set_markup( $field->{header_markup} );
            } else {
                $label->set_text( "$field->{name}" );
            }
            
            $label->visible( 1 );
            
            $field->{ $treeview_type . "_column" }->set_widget( $label );


	    if ( exists $field->{ $treeview_type . "_column" }->{custom_render_functions}) {
                $field->{ $treeview_type . "_column" }->set_cell_data_func(
                    $renderer,
                    sub { 
    			my ( $tree_column, $renderer, $model, $iter, @all_other_stuff ) = @_;
    			     $tree_column->{render_value} = $model->get( $iter, $renderer->{column} );
    				foreach my $render_function ( @{$tree_column->{custom_render_functions}} ) {
				        &$render_function( $tree_column, $renderer, $model, $iter, @all_other_stuff );
    				}
			    return FALSE;
		    	}
                );
            }
 
	    	       
	     if ($field->{renderer} eq "combo"){

		       $renderer->signal_connect ( "editing-started" => sub  { $self->_start_editable(@_)}, $renderer  );
		    
	    }
    }# for $field ...

    #add fields for the combodata if any
    for my $v ( @combodata ){
	     push @{ $self->{ $treeview_type . "_treestore_def" } }, $v
    }



} #setup_treeview

#the first field links the data from the table with a value in the list
#the remaining fields are displayed in the combo
# the type of the first field is in ->{fieldsType} the other(s) are supposed to be strings
sub _setup_combo {
	 my ( $self, $fieldname ) = @_;
 
 
    my $column_no = $self->{colname_to_number}->{$fieldname};
    $self->{log}->debug("setup_combo field name : " . $fieldname . " col number :" . $column_no);

    #my @combo = @{$self->{fields}[$column_no]->{data}};
    my $dman = $self->{fields}[$column_no]->{data_manager};
    my $last = $dman->row_count;

    # return unless(@combo);

    my @liste_def;
    
    # my $firstrow = $combo[0];
   
    my @cols; # = $firstrow->meta->column_names;
    if ($self->{fields}[$column_no]->{fieldnames}) {
	    @cols = @{$self->{fields}[$column_no]->{fieldnames}};
    } else {
     	@cols = $dman->get_field_names;
     }

    $self->{log}->debug("setup_combo cols : " . join(" ", @cols));
    # my $rdbtype = $fieldtype{ $self->{fieldsType}->{ $cols[0]  } };
    #  my $rdbtype = $fieldtype{ $self->{dman}->get_field_type ($cols[0] ) };
       my $rdbtype = $fieldtype{ $dman->get_field_type ($cols[0] ) };
    my $first_type =  $render{$rdbtype}[1];
     my $pos = 0;
    foreach my $name (@cols){
	     if ($pos++ == 0) {
		   
		     push @liste_def, $render{$rdbtype}[1];
		     # push @liste_def, "Glib::String";
	    } else {
		    push @liste_def, "Glib::String";
	    }	   
    	
    }

    my $model = Gtk2::ListStore->new( @liste_def );
 
 #foreach  my $row ( @combo ) {
  for (my $row_pos = 0; $row_pos < $last ; $row_pos ++ ) {
        
        my @model_row;
	# $self->{log}->debug("Datasheet setupcombo set row pos " . $row_pos);
	$dman->set_row_pos( $row_pos );

        push @model_row, $model->append;
        $pos = 0 ;
        foreach my $name ( @cols) {
	    
	    #push @model_row, $pos++, $row->$name();
	    push @model_row, $pos++, $dman->get_field($name);
	    # $self->{log}->debug("field: " . $name . " val : ". $row->$name() . " pos: ". $pos);
	    #$pos++;
        }
	# print Dumper(@model_row);
        $model->set( @model_row );
	# $model->set_text_column(1);
  
    }#for
    # @cols = $self->{treeview}->get_columns;
    # $self->{log}->debug("last col is : " . scalar @cols);
    # my $column = $self->{treeview}->get_column($column_no);
    #  my $renderer = ($column->get_cell_renderers)[0];

   return $model;
     
        

 }

 
 sub update {
	my ($self) = @_;
	#my ($self, $data) = @_;

	#keep the value of the hash ref by ->{data} unchanged if 
	# $data is undef
	#$self->{data} = $data if ($data);
	my $treeview_type = "treeview";
	my $last = $self->{dman}->row_count;
	$self->{log}->debug("datasheet query: " . $last . " rows");
	#my $row_pos = 0;
	my $liststore = Gtk2::ListStore->new( @{ $self->{ $treeview_type . "_treestore_def"} } );
	# foreach my $row (@{$self->{data}}){ 
	for (my $i = 0; $i < $last; $i++) {
		$self->{log}->debug("Datasheet query set row pos " . $i);
		$self->{dman}->set_row_pos($i);
 		 my @combo_values;        
	       	my @model_row;
        	my $column = 0;
        
       		for my $field ( @{$self->{fields}} ) {
			if ( $column == 0 ) {
                
		                my $record_status = UNCHANGED;
				# $self->{log}->debug("Col " . $column . " added");
                	         push @model_row, $liststore->append, STATUS_COLUMN, $record_status;
		              
                	} else {
				my $x = "";
				if ( $field->{name} ~~ @{$self->{cols}}) {
					$self->{log}->debug("query: " .  $field->{name} . " row: " . $i );
					
					$x = $self->{dman}->get_field( $field->{name} );
					$self->{log}->debug( $field->{name} . " " . (defined $x ? "x: " . $x : "x undefined"));
					if (defined $x) {
						$self->{log}->debug( $field->{name} . " " . ( $x ne "" ? "x: " . $x : "x zls")); 
						$x = ($x eq $self->{null_string} ? "" : $x);
					}
				


				
				
				} else { $self->{log}->debug("update: " . $field->{name} . " not found in " . join(" ", @{$self->{cols}}));}

			 	
				$self->{log}->debug("field: ". $field->{name} . " col.: " . $column . " value: " . (defined $x?$x:" undef "));

				push @model_row,  $column, $x;
				#die unless defined($x);
				if ($field->{renderer} eq "combo" && defined $x && $x ne "") {
					my @renderers = $field->{ $treeview_type . "_column" }->get_cell_renderers;
					my $combomodel = $renderers[0]->get("model");
					# $self->{log}->debug("data-t: " . $field->{ $treeview_type . "_column" }->{renderer}->{data_type});
					my $value = $self->_combo_value($combomodel, $x,  $field->{ $treeview_type . "_column" }->{renderer}->{comp});
				# push @combo_values, $value;
					push @model_row, $renderers[0]->{col_data}, $value;

				} 
		      } #else
		 $column++;
		} #for each column


		{
                no warnings 'numeric';
	 	$liststore->set( @model_row );
		# use warnings;
		}
         } # foreach row

	 $self->{log}->debug("update done");
	   $self->{changed_signal} = $liststore->signal_connect( "row-changed" => sub { $self->_changed(@_); } );

	$self->{treeview}->set_model($liststore);

	return FALSE;
} #sub 



sub colnumber_from_name {
    
    my ( $self, $fieldname ) = @_;
    return $self->{colname_to_number}->{$fieldname}
    
}

sub undo {
	shift->query;
}

#called by on-change event for each row of the treeview
#added by query

sub _changed {

   my ( $self, $liststore, $treepath, $iter ) = @_;

	$self->{log}->debug("changed\n");
  
	my $model = $self->{treeview}->get_model; 

    # Only change the record status if it's currently unchanged 
    if ( ! $model->get( $iter, STATUS_COLUMN ) ) {
        $model->signal_handler_block( $self->{changed_signal} );
        $model->set( $iter, STATUS_COLUMN, CHANGED );
        $model->signal_handler_unblock( $self->{changed_signal} );
    }
    $self->{changed}= TRUE; 

  
    return FALSE;

}


sub apply {

	my $self = shift;

	#accéder au lignes modifiees: parcourir toutes celles qui sont affichées 
	#et agir selon ce qu'indique la col status
	
	$self->{changed} = FALSE;
	$self->{log}->debug("apply");
    my @iters_to_remove;

     my $model = $self->{treeview}->get_model;

     my $iter = $model->get_iter_first;
  my $row_pos = 0;
  my $row;

    $model->signal_handler_block( $self->{changed_signal} );
    #for all the rows in the datasheet
    while ( $iter ) {
        
        my $status = $model->get( $iter, STATUS_COLUMN );

	 $self->{log}->debug("status : " . $status . " row pos " . $row_pos);
        
	 $self->{dman}->set_row_pos( $row_pos++ );

        # Decide what to do based on status
        if ( $status == UNCHANGED || $status == LOCKED ) {
            $iter = $model->iter_next( $iter );
	    #$row_pos++;
            next;
        }

	if (  $status == INSERTED ) { # new row for the database 
		$self->{dman}->new_row;
	}  #else { # existing row with CHANGED or DELETED
		# $row = ${$self->{data}}[$row_pos++];
		#}
	
       	if ($status == DELETED) {

		#if ($row->delete ) {$self->{log}->debug("deleting current row");} else {$self->{log}->debug("Can't delete");}
		if ( $self->{dman}->delete ) {$self->{log}->debug("deleting current row");} else {$self->{log}->debug("Can't delete");}
		#$row->delete;
		push @iters_to_remove, $iter;
	 } else {  # changed, inserted

		for my $field ( @{$self->{fields}} ) {
			if ( $field->{name} ~~ @{$self->{cols}}){
				my $x =  $model->get( $iter, $self->{colname_to_number}->{ $field->{name} } );
				$self->{log}->debug("Field: "  . $field->{name} . " row_pos " . $row_pos . " value: ". ($x?$x: "undef") );
				$self->{dman}->set_field($field->{name}, $x );
			 } else { $self->{log}->debug("apply : " . $field->{name} . " not found in " . join(" ", @{$self->{cols}}));}

		}
		 $self->{log}->debug("saving...");
		 #$row->save;		 
		 $self->{dman}->save;
	}

      #replace the unchanged icon in the col 0	
      $model->set( $iter, STATUS_COLUMN, UNCHANGED );
      #$row_pos++;
      $iter = $model->iter_next( $iter );

  } #while

    foreach $iter ( @iters_to_remove ) {
        $model->remove( $iter );
    }

        $model->signal_handler_unblock( $self->{changed_signal} );

    return FALSE;

}

sub insert {

 my ( $self,  @columns_and_values ) = @_;
	  my $model = $self->{treeview}->get_model;
          my $iter = $model->append;
	$self->{log}->debug("inserting...");
	# print Dumper(@columns_and_values);
    my @new_record;

      push @new_record,
        $iter,
        STATUS_COLUMN,
        INSERTED;

    if ( @columns_and_values ) {
        push @new_record,
             @columns_and_values;
    }	
	$self->{log}->debug("new rec default values: " . join(" ", @new_record));
      $model->set( @new_record ); 

       $self->{treeview}->set_cursor( $model->get_path($iter), $self->{fields}[0]->{treeview_column}, 0 );

        # Now scroll the scrolled window to the end
    # Using an idle timer is required because gtk needs time to add the new row ...
    #  ... if we don't use an idle timer, we end up scrolling to the 2nd-last row
    
    Glib::Idle->add( sub {
        my $adjustment = $self->{treeview}->get_vadjustment;
        my $upper = $adjustment->upper;
        $adjustment->set_value( $upper - $adjustment->page_increment - $adjustment->step_increment );
    } );
   
    return TRUE;

}

sub delete {

     my $self = shift;
    # We only mark the selected record for deletion at this point
    my @selected_paths = $self->{treeview}->get_selection->get_selected_rows;
    my $model = $self->{treeview}->get_model;
    
    for my $path ( @selected_paths ) {
        my $iter = $model->get_iter( $path );
       
        $model->set( $iter, STATUS_COLUMN, DELETED );
    }
    
    return FALSE;

}

sub _cell_edited {
	 my ($self, $cell, $path_string, $new_text) = @_;
	  my $path = Gtk2::TreePath->new_from_string ($path_string);
  	my $model = $self->{treeview}->get_model;
   	my $col = $cell->{column};
  	my $iter = $model->get_iter($path);

   	$model->set_value ($iter, $col, $new_text); 
	return FALSE;
}

sub _toggle_edited {
     my ($self, $renderer, $text_path, $something) = @_;
     my $column_no = $renderer->{column};
    my $path = Gtk2::TreePath->new ( $text_path );
    my $model = $self->{treeview}->get_model;
    my $iter = $model->get_iter ( $path );
    my $old_value = $model->get( $iter, $renderer->{column} );
    my $new_text = ! $old_value;

     $model->set ( $iter, $renderer->{column}, $new_text );
	return FALSE;
}


#called after a change in the combo
# $combo -> $tree
 sub _combo_edited {
        my  ($self, $renderer, $path_string, $new_text) = @_;
	# return unless ($tree);
	#  treeViewModel[path][columnNumber] = newText
	my $model =  $self->{treeview}->get_model;
	 print("combo_edited " . $new_text . "\n");
					#	$cell->get("model");
#	$model->set ($iter, $cell->{column}, $new_text);
 	my $path = Gtk2::TreePath->new_from_string( $path_string );
	my $citer = $renderer->{combo}->get_active_iter;
	my $cmodel = $renderer->{combo}->get_model;
	my $value = $cmodel->get($citer, 0);
	print("combo_edited value :" . $value . "\n");
	 my $iter = $model->get_iter ( $path );
	$model->set($iter, $renderer->{column}, $value);
	$model->set($iter, $renderer->{col_data}, $new_text);
}

sub _start_editable {
 	my ($self, $cell, $editable, $path, $renderer) = @_;
	 $self->{log}->debug( "start_editable");
	# print Dumper($editable);
	# $maincombo = $editable;
	$renderer->{combo} = $editable;

}
 

 sub _combo_value {
	 my ($self, $combo_model, $id, $comp_ref) = @_;
	 my $iter = $combo_model->get_iter_first();
	 my $key = -1;
	 my $value;
	 
	 # while ($iter && $key != $id){
	  while ( $iter && &$comp_ref($key, $id, 0)){
	    $key = $combo_model->get_value($iter, 0);
	    #  if ($key == $id) {
	      if ( &$comp_ref($key, $id, 1) ) {
					  
		  $value = $combo_model->get_value($iter, 1);
		  $self->{log}->debug( "found : " . $value . " for ". $id);
		  last;
	  }
	   $iter = $combo_model->iter_next( $iter );
         }

	   return $value;

 }

 sub get_data_manager{
	return shift->{dman};
}


1;
__END__

=pod

=head1 NAME

Gtk2::Ex::DbLinker::Datasheet -  a module that display data from a database in a tabular format using a treeview

=head1 VERSION

See Version in L<Gtk2::Ex::DbLinker>

=head1 SYNOPSIS

This display a table having to 6 columns: 3 text entries, 2 combo, 1 toogle, we have to create a dataManager object for each combo, and a dataManager for the table itself. The example here use Rose::DB::Object to access the tables.

This gets the Rose::DB::Object::Manager (we could have use plain sql command, or DBIx::Class object) 

    	my $datasheet_rows = Rdb::Vtlsfm::Manager->get_vtlsfm(sort_by => 'nofm');

This object is used to instanciante a RdbDataManager, that will be used in the datasheet constructor.

      	my $dman = Gtk2::Ex::DbLinker::RdbDataManager->new({data => $datasheet_rows, meta => Rdb::Vtlsfm->meta });

We create the RdbDataManager for the combo rows
     
       	my $biblio_data = Rdb::Biblio::Manager->get_biblio( select => [qw/t1.id t1.nom/], sort_by => 'nom');
	my $dman_combo_biblio = Gtk2::Ex::DbLinker::RdbDataManager->new({data => $biblio_data, meta => Rdb::Biblio->meta});


	my $ed_data =  Rdb::Ed::Manager->get_ed( sort_by => 'nom');
	my $dman_combo_ed = Gtk2::Ex::DbLinker::RdbDataManager->new({ 
					     		data =>$ed_data,
						        meta => Rdb::Ed->meta,
							});

We create the Datasheet object with the columns description

	my $treeview = Gtk2::TreeView->new();

	$self->{datasheet} = Gtk2::Ex::DbLinker::Datasheet->new({
		treeview => $treeview,
		fields => [{name=>"nofm", renderer=>"text"},
			{name=>"reroid"}, 
			{name=>"url", renderer=>"text", custom_render_functions => [sub {display_url (@_, $self);},]},
			{name => 'biblio', renderer => 'combo', data_manager => $dman_combo_biblio, fieldnames=>["id", "nom"]},
			{name => 'ed', renderer => 'combo', 
				     data_manager=> $dman_combo_ed,
					fieldnames=>["id", "nom"]}, 
			{name => 'idle', renderer => 'toggle'},
				],
		data_manager => $dman,		
	});

To change a set of rows in the table when we navigate between records for example. The primary key of the current record is hold in $primarykey_value :

	  my $data =  Rdb::Vtlsfm::Manager->get_vtlsfm(query =>[nofm =>{eq=> $primarykey_value}], sort_by => 'primarykey');
	  $self->{dataseet}->get_data_manager->query($data);

	  $self->{datasheet}->update();



=head1 DESCRIPTION

This module automates the process of setting up a model and treeview based on field definitions you pass it. An additional column named _status_column_ is added in front of a the other fields. It holds icons that shows if a row is beeing edited, mark for deletion or is added.

Steps for use:

=over

=item * 

Instanciate a xxxDataManager that will fetch a set of rows.

=item * 

Create a 'bare' Gtk2::TreeView.

=item *

Create a xxxDataManager holding the rows to display, if the datasheet has combo box, create the corresponding DataManager that hold the combo box content.

=item * 

Create a Gtk2::Ex::DbLinker::Datasheet object and pass it your TreeView and DataManagers objects. 

You would then typically connect some buttons to methods such as inserting, deleting, etc.

=back

=head1 METHODS

=head2 constructor

The C<new()> method expects a hash reference of key / value pairs.

=over

=item * 

C<data_manager> a instance of a xxxDataManager object.

=item *

C<tree> a Gtk2::TreeView

=item *

C<fields> a reference to an array of hash. Each hash has the following key / value pairs.

=over

=item *

C<name> / id of the field to display.

=item *

C<renderer> / one of "text combo toggle hidden image".

=back

if the renderer is a combo the following key / values are needed in the same hash reference:

=over

=item *

C<data_manager> / an instance holding the rows.

=item *

C<fieldnames> / a reference to an array of the fields that populate the combo. The first one is the return value.

=back

=back

=head2 C<update();>

Reflect in the user interface the changes made after the data manager has been queried, or on the datasheet creation.

=head2 C<get_data_manager();>

Returns the data manager to be queried.


=head2 Methods applied to a row of data:

=over 

=item *

C<insert();>

Displays an empty rows.

=item *

C<delete();>

Marks the current row to be deleted. The delele itself will be done on apply.

=item *

C<apply();>

Save a new row, save changes on an existing row, or delete the row(s) marked for deletion.

=item *

C<undo();>

Revert the row to the original state in displaying the values fetch from the database.

=back

=head1 SUPPORT

Any Gk2::Ex::DbLinker questions or problems can be posted to the the mailing list. To subscribe to the list or view the archives, go here: 
L<http://groups.google.com/group/gtk2-ex-dblinker>. 
You may also send emails to gtk2-ex-dblinker@googlegroups.com. 

The current state of the source can be extract using Mercurial from
L<http://code.google.com/p/gtk2-ex-dblinker/>.

=head1 AUTHOR

FranE<ccedil>ois Rappaz <rappazf@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014 by FranE<ccedil>ois Rappaz.  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Gtk2::Ex::Datasheet::DBI>

=head1 CREDIT

Daniel Kasak, whose modules initiate this work.

=cut

