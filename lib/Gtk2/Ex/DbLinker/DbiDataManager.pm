package Gtk2::Ex::DbLinker::DbiDataManager;
use  Gtk2::Ex::DbLinker;
our $VERSION = $Gtk2::Ex::DbLinker::VERSION;

use Class::Interface;

&implements('Gtk2::Ex::DbLinker::AbDataManager');

use strict;
use warnings;
use  Carp;
#use Data::Dumper;

use Glib qw/TRUE FALSE/;

use Gtk2::Ex::Dialogs (
                        destroy_with_parent => TRUE,
                        modal               => TRUE,
                        no_separator        => FALSE
);

my %fieldtype = (tinyint => "integer", "int" => "integer");

$Class::Interface::CONFESS = 1;

sub new {
		my ( $class, $req ) = @_;

		my $self = {
    		dbh                     => $$req{dbh},                                  # A database handle
    		primary_keys            => $$req{primary_keys},                         # An array ref of primary keys
		ai_primary_keys		=> $$req{ai_primary_keys}, 			# an array of auto incremented primary keys
		sql                     => $$req{sql},                                  # A hash of SQL related stuff
		aperture	=> $$req{aperture} || 1,
		before_query => $$req{before_query},
	};

	 bless $self, $class;

	 $self->{log} = Log::Log4perl->get_logger(__PACKAGE__);


	$self->{auto_incrementing} = ( defined ($self->{ai_primary_keys}) ? 1 : 0);
	croak(__PACKAGE__ . ": use ai_primary_keys or primary_keys but not both...") if (defined $self->{ai_primary_keys} && defined $self->{primary_keys});
	$self->{primary_keys} = $self->{ai_primary_keys} if (defined $self->{ai_primary_keys});

	$self->{log}->debug("auto_incrementing: " . 	$self->{auto_incrementing});

	if ( ! $self->{dbh} ) {
        croak( __PACKAGE__ . ": constructor missing a dbh!\n" );
    }
       
    #$self->{cols} = {}; 
    $self->{cols} = [];


     if ($self->{sql}->{select_distinct}) {
	    $self->{sql}->{select}=$req->{sql}->{select_distinct};
	    $self->{sql}->{head}="select distinct ";
	    #die;
     } else {
	   $self->{sql}->{head}="select ";
     }

    if ( $self->{sql} ) {
        if ( exists $self->{sql}->{pass_through} ) {
            # pass_throughs are read-only at the moment ... it's all a bit hackish
            $self->{read_only} = TRUE;
        } elsif ( ! ( exists $self->{sql}->{select} && exists $self->{sql}->{from} ) ) {
            croak( __PACKAGE__ . " constructor missing a complete sql definition!\n"
                . "You either need to specify a pass_through key ( 'pass_through' )\n"
                . "or BOTH a 'select' AND and a 'from' key\n" );
        }
    }

        $self->{server} = $self->{dbh}->get_info( 17 );
   $self->{log}->debug("server : " .  ($self->{server} ? $self->{server} : "UNDEF"));
    # Some PostGreSQL stuff - DLB
    if ($self->{server} && $self->{server} =~ /postgres/i ) {
        if ( ! $self->{search_path} ) {
            if ( $self->{schema} ) {
                $self->{search_path} = $self->{schema} . ",public";
            } else {
                $self->{search_path} = "public";
            }
        }
        my $sth = $self->{dbh}->prepare ( "SET search_path to " . $self->{search_path} );
        eval {
            $sth->execute or die $self->{dbh}->errstr;
        };
        if ( $@ ) {
            carp( "Failed to set search_path to " . $self->{search_path}
                . " for a Postgres database. I'm not sure what the implications of this are. Postgres users, please report ...\n" );
        }
}
   
	$self->{friendly_table_name} = $self->{sql}->{from};

	if ($self->{sql}->{select} && $self->{sql}->{select} !~ /[\*|%]/ ) {
		my $fieldslist =  $self->{sql}->{select};
        	 $fieldslist =~ s/distinct//i;

        	foreach my $fieldname ( split( / *, */, $fieldslist ) ) {
            		if ( $fieldname =~ m/ as /i ) {
		                my ( $sql_fieldname, $alias ) = split( / as /i, $fieldname );
                		$self->{widgets}->{$alias} = { sql_fieldname    => $sql_fieldname };
				# $alias = lc( $alias);
				 push @{$self->{cols}}, $alias unless ($alias ~~ @{$self->{cols}});
		 # $self->{cols}->{ lc $alias } ++;
            		} else {
		                if ( ! exists $self->{widgets}->{$fieldname} ) {
                		    $self->{widgets}->{$fieldname} = {};
				    $self->{log}->debug("DBI_dman : fieldname " . $fieldname);
				    # $fieldname = lc ( $fieldname );
				     push @{$self->{cols}}, $fieldname  unless ($fieldname ~~ @{$self->{cols}});
		    #$self->{cols}->{ lc $fieldname } ++;
                		}
            		}
        	}
	} else {
        
        # If we're using a wildcard SQL select or a pass-through, then we use the fieldlist from an empty recordset
        # to construct the widgets hash
        
        	my $sth;
        
	        eval {
        	    if ( exists $self->{sql}->{pass_through} ) {
                	$sth = $self->{dbh}->prepare( $self->{sql}->{pass_through} )
                    		|| croak( $self->{dbh}->errstr );
		    } else {
        	        $sth = $self->{dbh}->prepare(
                	    $self->{sql}->{head} . $self->{sql}->{select} . " from " . $self->{sql}->{from} . " where 0=1")
                        	|| croak( $self->{dbh}->errstr );
            	}
        	};
        
        	if ( $@ ) {
            		Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(title   => "Error in Query!", icon    => "error", text    => "<b>Database Server Says:</b>\n\n$@");
	            return FALSE;
        	}
        
        	eval {
            		$sth->execute || croak( $self->{dbh}->errstr );
        	};
        
	        if ( $@ ) {
	     		Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(title   => "Error in Query!", icon    => "error", text    => "<b>Database Server Says:</b>\n\n$@");
	        return FALSE;
        	}

        	foreach my $fieldname ( @{$sth->{'NAME'}} ) {
	            if ( ! $self->{widgets}->{$fieldname} ) {
			    # print "$fieldname\n";
                	$self->{widgets}->{$fieldname} = {};
			$self->{log}->debug("DBI_dman : fieldname " . $fieldname);
			#$fieldname = lc ( $fieldname );
			 push @{$self->{cols}}, $fieldname unless ($fieldname ~~ @{$self->{cols}});
		#  $self->{cols}->{ lc $fieldname } ++;
            		}
        	}
        
        $sth->finish;
        
    } #else
	
    my $sth;

        # Construct a hash to map SQL fieldnames to widgets
    foreach my $widget ( keys %{$self->{widgets}} ) {
		$self->{log}->debug("sql_to_widget: widget $widget fieldname : " . 
			($self->{widgets}->{$widget}->{sql_fieldname}?$self->{widgets}->{$widget}->{sql_fieldname}:" undef") );
        	$self->{sql_to_widget_map}->{ $self->{widgets}->{$widget}->{sql_fieldname} || $widget} = $widget;
    }
   if ( ! $self->{primary_keys} ) {
	   
        eval {
            $sth = $self->{dbh}->primary_key_info( undef, undef, $self->{sql}->{from} )
                || croak $self->{dbh}->errstr;
        };
        if ( ! $@ ) {
	
            while ( my $row = $sth->fetchrow_hashref ) {
		   
                $self->{log}->debug("Bound to " . $self->{friendly_table_name} . " detected primary key : " . $row->{COLUMN_NAME});
                
		 push @{$self->{primary_keys}}, $row->{COLUMN_NAME};
		 #push @{$self->{cols}}, $row->{COLUMN_NAME};
                if ( exists $row->{KEY_SEQ} ) {
                    if ( ! $row->{KEY_SEQ} ) {
                        $self->{log}->debug("This primary key is NOT auto-incrementing");
			$self->{auto_incrementing} = 0;
                    }
                } #if
            } #while
        }#if
    } #if
    else {
    	$self->{log}->debug("primary key: ", join(" ", @{$self->{primary_keys}}));
    }
     foreach my $pk (@{$self->{primary_keys}} ){
	     	$self->{log}->debug("DBI_dman: pk " . $pk);
		 push @{$self->{cols}}, $pk unless ($pk ~~ @{$self->{cols}});
		#  $self->{cols}->{ lc $pk } ++;
    }
    croak("Cannot deal with a table without a primary key") unless($self->{primary_keys});
    

  if ( exists $self->{sql}->{pass_through} ){	
	 eval {
                $sth = $self->{dbh}->prepare( $self->{sql}->{pass_through} )  || croak( $self->{dbh}->errstr );
	   
		$sth->execute || croak( $self->{dbh}->errstr);
    	};
     	$self->use_sth_info($sth);
  } else {

	  $sth =  $self->use_dbh_column_info; 
	
    }

	croak(__PACKAGE__ . ": no primary keys detected. Please provide an array ref using ai_primary_keys or primary_keys in the constructor") unless($sth);
	$sth->finish;
        

   

    if ($self->{sql}->{bind_values}) {
	     $self->query({where => $self->{sql}->{where}, bind_values => $self->{sql}->{bind_values}});
     } else {
	     $self->query();
     }

    return $self;

}#new

sub use_dbh_column_info {
	my ($self ) = @_;
	my $sth;
	my @sth;
 eval {
=for comment
the absence of pass_through was tested above, so we never reach these lines
        if ( $self->{sql}->{pass_through} ) {
		# % return one field from the table and not all or not the pk
            $sth = $self->{dbh}->column_info( undef, $self->{schema}, $self->{sql}->{pass_through}, '%' ) || croak $self->{dbh}->errstr;
	    push @sth, $sth;
        } else {
=cut
		my ($table) = ( $self->{sql}->{from}=~/^(\w+)/);
		$self->{log}->debug("table: " . $table);
            # $sth = $self->{dbh}->column_info( undef, $self->{schema}, $self->{sql}->{from}, '%' ) 
	    #$sth = $self->{dbh}->column_info( undef, $self->{schema}, $table, '%' ) || croak $self->{dbh}->errstr;
	    #}

	    for my $pk (@{$self->{primary_keys}}) {
		  $sth = $self->{dbh}->column_info( undef, $self->{schema}, $table, $pk ) || croak $self->{dbh}->errstr;
		  push @sth, $sth;
	    
	    }
	 #} #else
    	};
    	for $sth (@sth) {
	   	croak("Column_info not supported by the drivers - a primary_keys array ref is required in the constructor") unless (defined $sth); 
           	while ( my $column_info_row = $sth->fetchrow_hashref ) {
		 	my	 $fieldname = $column_info_row->{COLUMN_NAME};
           
	    #for my $fieldname ( keys %{$self->{sql_to_widget_map}} ) {
	    #        if ( $column_info_row->{COLUMN_NAME} eq ( $fieldname ) ) {
                   
		    if (! $self->{auto_incrementing} && $column_info_row->{mysql_is_auto_increment}){
			     $self->{auto_incrementing} = 1;
			     push @{$self->{ai_primary_keys}}, $fieldname;
		    
		    }
                    $self->{column_info}->{ $self->{sql_to_widget_map}->{$fieldname} } = $column_info_row;
		    #last;
		    #}
	     #} #for
    	} #while
	} #for
    
    # Make sure we've got the primary key in the widgets hash and the sql_to_widget_map hash
    # It will NOT be here unless it's been specified in the SQL select string or the widgets hash already
    # Note that we test the sql_to_widget_map, and NOT the widgets hash, as we don't know what
    # the widget might be called, but we DO know what the name of the key in the sql_to_widget_map
    # should be
    	foreach my $primary_key ( @{$self->{primary_keys}} ) {
        	if ( ! exists $self->{sql_to_widget_map}->{ $primary_key } ) {
	            $self->{widgets}->{ $primary_key } = {};
        	    $self->{sql_to_widget_map}->{ $primary_key } = $primary_key;
        	}
    	}
    
    # If things failed above, we mightn't have a $sth to finish, so
    # check we do first ...
    	if ( $sth ) {
        	$sth->finish;
    	}
    	foreach my $c (keys %{$self->{column_info}}){
    		#$self->{log}->debug("DBI_dman col_info Data_type : " . $c . " " . $self->{column_info}->{$c}->{DATA_TYPE} );
		$self->{log}->debug("DBI_dman col_info  Type_name : " . $c . " " . $self->{column_info}->{$c}->{TYPE_NAME} );
		#$self->{log}->debug("DBI_dman col_info sql_data_type : " . $c . " " . $self->{column_info}->{$c}->{SQL_DATA_TYPE} );

    	}
	return $sth;
}

sub use_sth_info {
	my ($self, $sth ) = @_;

	 $self->{cols} = $sth->{'NAME'};
	#for my $name (@{ $sth->{'NAME_lc'}}){
	#	$self->{cols}->{ $name };
	#}
	my @type = @{$sth->{'TYPE'}};
	$self->{log}->debug("TYPE: ", join(" ", @type));
	my $pos=0; #http://docstore.mik.ua/orelly/linux/dbi/ch06_01.htm
	my %sqltype = (1=>'char', 2=>'integer', 3=>'integer', 4=>'integer', 5=>'integer', 6=>'integer', 7=>'integer', 
		8=>'integer', 9=>'date', 10=>'date', 11=>'date', 12=>'varchar', -1=>'varchar', -2=>'boolean', -3=>'boolean', 
		-5=>'integer', -6=>'integer', -7=>'integer');
	for my $name ( @{$self->{cols} }) {
		my $type = lc $type[$pos++];;
		if ($self->{server}) { #mysql gives type as given in sqltype above, DBI::CSV (where $self->{server} is undef) gives the type as an array of string
			$type =  $sqltype{$type};
		}
	
		$self->{log}->debug($name . " type: " . $type );
		$self->{column_info}->{$name}->{TYPE_NAME} = $type;
	}
}

sub set_row_pos{
	my ($self, $pos) = @_;
	# $self->{log}->debug("Dbi_dman: set_row_pos: " . $pos  );
	$self->_move(undef, $pos);

}

sub get_row_pos{
    # Returns the absolute position ( starting at 0 ) in the recordset ( taking into account the keyset and slice positions )    
    my $self = shift;
    return ( $self->{keyset_group} * $self->{aperture} ) + $self->{slice_position};
    
}

sub set_field{
	 my ($self, $fieldname, $value) = @_;
	 $self->{records}[$self->{slice_position}]->{$fieldname} = $value;

}


sub get_field{
 my ($self, $fieldname) = @_;
   my $data = $self->{records}[$self->{slice_position}]->{$fieldname};
   return $data;
}

sub get_field_type{
	my ($self, $fieldname) = @_;
	my $type; 
	if (exists $self->{column_info}->{$fieldname}){
		 $type = lc($self->{column_info}->{$fieldname}->{TYPE_NAME});
		$type = ($fieldtype{$type} ? $fieldtype{$type} : $type);
	} else {
		#$self->{log}->debug (Dumper $self->{column_info});
		$type = "varchar";
	}
	$self->{log}->debug("Dbi_dman get_field_type for ".   $fieldname . " : " . $type);
	return $type;

}

sub new_row{

    
    # Inserts a record at the end of the *in-memory* recordset.
    
    my $self = shift;
    my $newposition = $self->count; # No need to add one, as the array starts at zero.
=for comment
    if ( ! $self->_move( 0, $newposition ) ) {
        warn "Insert failed ... probably because the current record couldn't be applied\n";
        return FALSE;
    }
=cut

	$self->_move( 0, $newposition);
    
    # Assemble new record and put it in place
    $self->{records}[$self->{slice_position}] = $self->_assemble_new_record;
    
    # Finally, paint the current recordset onto the widgets
    # This is the 2nd time this is called in this sub ( 1st from $self->move ) but we need to do it again to paint the default values
    # $self->paint;
    
    return TRUE;

}

sub save{

	my ($self,  $href) = @_;
    
    my @fieldlist = ();
    my @bind_values = ();
    #$href is used to change a field's value when the field is included in a composed primary keys. 
    #The array @pk holds the field's name of the primary keys since ->get_primarykeys return these fields even if auto_incrementing is 0
    #The if test in the foreach loop fails and the values of the primary key fields are not added in the bind_values array therefore.
    #The old values are then used to select the row when the field has to be changed.
    #
    #When $href is undef, save is used to insert or changed a non primary keys field, the primary key value comes from the database. 
    #@pk holds the auto incremented primary key names (auto_incrementing is) or is undef.
    #
     my @pk;   
    if ($href) {
    	for my $k (keys %$href) {
		$self->{log}->debug("push on bind_values " .  $href->{$k} . " from field " . $k);
	 	push @bind_values, $href->{$k};
		push @fieldlist, $k;
	}
    	@pk = $self->get_primarykeys;
    } else {
     	@pk  = $self->get_autoinc_primarykeys;
     }
    # my $placeholders; never used! # We need to append to the placeholders while we're looping through fields, so we know how many fields we actually have
    
    foreach my $fieldname ( keys %{$self->{widgets}} ) {
        
        $self->{log}->debug("Processing field ". $fieldname);
        
        
        # Support for aliases
        my $sql_fieldname = $self->{widgets}->{$fieldname}->{sql_fieldname} || $fieldname;
        
        # Don't include the field if it's a primary key.
        # This goes for inserts and updates.
	
	if ( $sql_fieldname ~~ @pk) {
		$self->{log}->debug("jumping $sql_fieldname because it's a pk");
            next;
        }
        

	#if ( defined $widget && ref $widget ne "Gtk2::Label" ) { # Labels are read-only
            push @fieldlist, $sql_fieldname;
	    #push @bind_values, $self->get_widget_value( $fieldname );
	    $self->{log}->debug("push on bind_values " . $sql_fieldname . " : " . $self->get_field( $fieldname ));
	    push @bind_values, $self->get_field( $fieldname );
	  #}
        
    }
    
    my $update_sql;
    
    if ( $self->{inserting} ) {
        
        $update_sql = "insert into " . $self->{sql}->{from} . " ( " . join( ",", @fieldlist, ) . " )"
            . " values ( " . "?," x ( @fieldlist - 1 ) . "? )";
        
        $self->{log}->debug("inserting ");
       
        
    } else {
         $self->{log}->debug("updating ");
        $update_sql = "update " . $self->{sql}->{from} . " set " . join( "=?, ", @fieldlist ) . "=? where "
            . join( "=? and ", @{$self->{primary_keys}} ) . "=?";
        
        foreach my $primary_key ( @{$self->{primary_keys}} ) {
 	$self->{log}->debug("push on bind_values " . $primary_key . " : " . $self->{records}[$self->{slice_position}]->{ $self->{sql_to_widget_map}->{$primary_key}});
            push @bind_values, $self->{records}[$self->{slice_position}]->{ $self->{sql_to_widget_map}->{$primary_key} };
        }
        
    }
    
    $self->{log}->debug( "Final SQL:  " . $update_sql);
        
	#   my $counter = 0;
        
	#    for my $value ( @bind_values ) {
		#print " " x ( 20 - length( $fieldlist[$counter] ) ) . $fieldlist[$counter] . ": $value\n";
	    #$counter ++;
	    #   }
    
    
    my $sth;
    
    # Evaluate the results of attempting to prepare the statement
    eval {
        $sth = $self->{dbh}->prepare( $update_sql )
            || die $self->{dbh}->errstr;
    };
    
    if ( $@ ) {
        Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(
            title   => "Error preparing statement to update recordset!",
            icon    => "error",
            text    => "<b>Database server says:</b>\n\n$@"
        );
        carp( "Error preparing statement to update recordset:\n\n$update_sql\n\n@bind_values\n" . $@ );
    }
    
    # Evaluate the results of the update.
    eval {
        $sth->execute( @bind_values ) || die $self->{dbh}->errstr;
    };
    
    $sth->finish;
    
    if ( $@ ) {
        Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(
            title   => "Error updating recordset!",
            icon    => "error",
            text    => "<b>Database server says:</b>\n\n" . $@
        );
        carp( "Error updating recordset:\n\n$update_sql\n\n@bind_values\n" . $@ . "\n" );
    }
    
    # If this was an INSERT, we need to fetch the primary key value and apply it to the local slice,
    # and also append the primary key to the keyset
    
    if ($self->{auto_incrementing} && $self->{inserting} ) {
        
	     # We only support a *single* primary key in the case of
            # an auto-incrementing setup.
	    #
               my $new_key = $self->_last_insert_id;
            my $primary_key = $self->{primary_keys}[0];
            $self->{records}[$self->{slice_position}]->{ $self->{sql_to_widget_map}->{$primary_key} } = $new_key;
            
        
        my @keys;
        
        foreach my $primary_key ( @{$self->{primary_keys}} ) {
		my $value = $self->{records}[$self->{slice_position}]->{ $self->{sql_to_widget_map}->{$primary_key}};
		$self->{log}->debug("pk : " . $primary_key . " value: " . ($value ? $value : " undef"));
            push @keys, $value ;
        }
        
	#push @{$self->{keyset}}, @keys;
	push @{$self->{keyset}}, join(", ", @keys);
        $self->{log}->debug( join(", ", @keys) . " added to keyset");

        
    }
    

    
    
    $self->{inserting} = 0;
    
    return TRUE;

}#save

sub delete{

  
    my $self = shift;
    my @pks = $self->get_primarykeys;

    $self->{log}->debug("delete pk_name is " . join( " ", @pks));

      my $delete_sql = "delete from " . $self->{sql}->{from} . " where " . join( "=? and ", @pks ) . "=?";
	$self->{log}->debug("delete : " . $delete_sql) ; 
	
       my @bind_values = ();

 
        foreach my $primary_key ( @pks ) {
            push @bind_values, $self->{records}[$self->{slice_position}]->{ $self->{sql_to_widget_map}->{$primary_key} };
        }

    # my $sth = $self->{dbh}->prepare( "delete from " . $self->{sql}->{from} . " where " . $self->{primary_key} . " = ?" );
	$self->{log}->debug("delete values: " . join(" ", @bind_values));
    my $sth =  $self->{dbh}->prepare($delete_sql);
    eval {
      #  $sth->execute($self->{records}[$self->{slice_position}]->{ $self->{sql_to_widget_map}->{$self->{primary_key}} })
       #     || die $self->{dbh}->errstr;
 
        $sth->execute( @bind_values ) || die $self->{dbh}->errstr;
	$sth->finish;

    };
    
    if ( $@ ) {
        Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(
            title   => "Error Deleting Record!",
            icon    => "error",
            text    => "<b>Database Server Says:</b>\n\n$@"
        );
        $sth->finish;
        return FALSE;
    }
    
    $sth->finish;

    
    # First remove the record from the keyset
    splice(@{$self->{keyset}}, $self->get_row_pos, 1);
    
    # Force a new slice to be fetched when we move(), which in turn handles with possible problems
    # if there are no records ( ie we want to set the 'inserting' flag if there are no records )
    $self->{keyset_group} = -1;
    
    # Moving forwards will give problems if we're at the end of the keyset, so we move backwards instead
    # If we're already at the start, move() will deal with this gracefully
    $self->_move( -1 );
 
}

sub next{
	shift->_move(1);
}

sub previous{
	shift->_move(-1);
}

sub last{
	my $self = shift;
	$self->_move(undef, $self->count - 1);
}

sub first{
	shift->_move(undef, 0);
}
sub row_count{
	return shift->count;
}

sub get_field_names{
	my $self = shift;
	# my @names =  keys %{$self->{widgets}};
	my @names = @{ $self->{cols} };
	return @names;
}

sub get_autoinc_primarykeys{
	my $self = shift;
	if ($self->{auto_incrementing}) {
		my $arref = ( $self->{ai_primary_keys} ? $self->{ai_primary_keys} : $self->{primary_keys} );
		return  @{$arref};
	} else {
		#http://stackoverflow.com/questions/1006904/why-does-my-array-undef-have-an-element
		return ();
	}
	
}

sub get_primarykeys{
	my $self = shift;
	if ($self->{auto_incrementing}){
		return @{$self->{ai_primary_keys}};
	} else {
		return  @{$self->{primary_keys}};
	}

}


sub query {
	 my ( $self,  $where_object ) = @_;
	$self->{log}->debug("query " . ($where_object ? " with arg " : " without arg"));
	if ( $where_object->{where} ) {
              $self->{sql}->{where} = $where_object->{where};
          }
         if ( $where_object->{bind_values} ) {
                $self->{sql}->{bind_values} = $where_object->{bind_values};
         }

             # Execute any before_query code
    if ( $self->{before_query} ) {
        if ( ! $self->{before_query}( $where_object ) ) {
            return FALSE;
        }
    } 


        if ( ! exists $self->{sql}->{from} && exists $self->{sql}->{pass_through} ) {
        eval {
            $self->{records} = $self->{dbh}->selectall_arrayref (
                    $self->{sql}->{pass_through},   {Slice=>{}}
            ) || croak( "Error in SQL:\n\n" . $self->{sql}->{pass_through} );
        };
        
        if ( $@ ) {
            Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(
                    title   => "Error in Query!",
                    icon    => "error",
                    text    => "<b>Database Server Says:</b>\n\n$@"
            );
            return FALSE;
        }
        
    } else {  
 
        $self->{keyset_group} = undef;
        $self->{slice_position} = undef;

        # Get an array of primary keys
        my $sth;
        
	my $local_sql;
	my @pks = $self->get_primarykeys();
	$self->{log}->debug("pks: " . join( ", ", @pks ));
		$self->{log}->debug("select: " .$self->{sql}->{select} );
		#if (  @{$self->{primary_keys}} = 0)
		$local_sql = $self->{sql}->{head} . join( ", ", @pks ) . " from " . $self->{sql}->{from};
		# else 
		#$local_sql =  $self->{sql}->{head} . $self->{sql}->{select} . " from " .  $self->{sql}->{from};
		#
	    # die $local_sql,"\n";
        # Add where clause if defined

        if ( $self->{sql}->{where} ) {
            $local_sql .= " where " . $self->{sql}->{where};
        }
        
        # Add order by clause of defined
        if ( $self->{sql}->{order_by} ) {
            $local_sql .= " order by " . $self->{sql}->{order_by};
        }
	 $self->{log}->debug("657 local_sql " . $local_sql);
        eval {
            $sth = $self->{dbh}->prepare( $local_sql )
                || croak( $self->{dbh}->errstr . " ".  $local_sql );
        };
        
        if ( $@ ) {
            Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(
                title   => "Error in Query!",
                icon    => "error",
                text    => "<b>Database Server Says:</b>\n\n$@"
            );
             croak( "query died with the SQL:\n\n$local_sql\n" );
            
            return FALSE;
        }
	  
        eval {
            if ( $self->{sql}->{bind_values} ) {
                $sth->execute( @{$self->{sql}->{bind_values}} ) || croak( $self->{dbh}->errstr );
            } else {
                $sth->execute || croak( $self->{dbh}->errstr . " ".  $local_sql );
            }
        };
	# $self->{log}->debug("DBI_dman_query sql: $local_sql");
 
        if ( $@ ) {
            Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(
                title   => "Error in Query!",
                icon    => "error",
                text    => "<b>Database Server Says:</b>\n\n" . $@  . " ".  $local_sql 
            );
	    #$self->{local_sql} = $sth->Statement;            
	    $sth->finish;
                croak( __PACKAGE__ . "::query died with the SQL:\n\n$local_sql\n" );
            
                return FALSE;
            }
        


        $self->{keyset} = ();
        $self->{records} = ();

        while ( my @row = $sth->fetchrow_array ) {
            my $key_no = 0;
            my @keys;
            foreach my $primary_key ( @pks ) {
		    # $self->{log}->debug("query : " . $primary_key . " value : " . $row[$key_no] );
		 croak (__PACKAGE__ . ": no value found for primary key $primary_key... check the primary_key names") unless($row[$key_no]);
                push @keys, $row[$key_no];
                $key_no ++;
            }
	    #was : 
	    # push @{$self->{keyset}}, @keys; # but the loop in fetch_new_slice missed a pk value...
	    push @{$self->{keyset}}, join(", ", @keys);
	   
        }
	#$self->{keyset_size}
	#for my $v ( @{$self->{keyset}} ) { $self->{log}->debug("value : " . $v);}
        
        $sth->finish;
        
    } #else
   $self->_move( 0, 0 );
    return TRUE; 

}

sub _move {
    
    # Moves to the requested position, either as an offset from the current position,
    # or as an absolute value. If an absolute value is given, it overrides the offset.
    # If there are changes to the current record, these are applied to the Database Server first.
    # Returns TRUE ( 1 ) if successful, FALSE ( 0 ) if unsuccessful.
    my ( $self, $offset, $absolute ) = @_;

     my ( $new_keyset_group, $new_position);
    
    if ( defined $absolute ) {
        $new_position = $absolute;
    } else {
        $new_position = ( $self->get_row_pos || 0 ) + $offset;
        # Make sure we loop around the recordset if we go out of bounds.
        if ( $new_position < 0 ) {
            $new_position = $self->count - 1;
        } elsif ( $new_position > $self->count - 1 ) {
            $new_position = 0;
        }
    }
    # if (  ! exists $self->{sql}->{pass_through})
    # $self->{log}->debug("new pos: $new_position");
    if ( exists $self->{sql}->{from} ) {
        
        # Check if we need to roll to another slice of our recordset
        $new_keyset_group = int($new_position / $self->{aperture} );
	# $self->{log}->debug("ksg: ". ( $self->{keyset_group} ?  $self->{keyset_group} : " undef") . " new_ksg " . $new_keyset_group . " slice_pos: " . ($self->{slice_position}? $self->{slice_position} : " undef")); 
        if (defined $self->{slice_position}) {
            if ( $self->{keyset_group} != $new_keyset_group ) {
                $self->{keyset_group} = $new_keyset_group;
                $self->_fetch_new_slice;
            }
=for comment
	    else {
		    $self->{log}->debug("new_ksg == ksg ");
		    my $href = $self->{records}[$self->{slice_position}];
		    my $data="";
			die unless($href);
		    for my $k (keys %{ $href }){
		    	$data .= $k . " : " . $href->{$k};
		    }
		    $self->{log}->debug($data);
	    }
=cut
	} else {
            $self->{keyset_group} = $new_keyset_group;
            $self->_fetch_new_slice;
        }
        
        $self->{slice_position} = $new_position - ( $new_keyset_group * $self->{aperture} );
        
    } else {
        $self->{slice_position} = $new_position;
        
    }
    #$self->{log}->debug("slice_pos: " . $new_position);
}

sub _fetch_new_slice {
    
    # Fetches a new 'slice' of records ( based on the aperture size )
    my $self = shift;
    # $self->{log}->debug("fetch_new_slice");
    # Get max value for the loop 
    my $lower = $self->{keyset_group} * $self->{aperture} ;
    my $upper = ( ($self->{keyset_group} + 1) * $self->{aperture} ) - 1;
    
    # Don't try to fetch records that aren't there ( at the end of the recordset )
    my $keyset_count = $self->count; # So we don't keep running $self->count...

    #$self->{log}->debug("_fetch_new_slice ks_group : ". $self->{keyset_group} );
    
    # $self->{log}->debug("_fetch_new_slice lower: " . $lower . "  count : " . $keyset_count . " upper ". $upper);
    
    if ( ( $keyset_count == 0 ) || ( $keyset_count == $lower ) ) {
        
        # If $keyset_count == 0 , then we don't have any records.
        
        # If $keyset_count == $lower, then the 1st position ( lower ) is actually out of bounds
        # because our keyset STARTS AT ZERO.
        
        # Either way, there are no records, so we're inserting ...
        
        # First, we have to delete anything in $self->{records}
        # This would *usually* just be overwritten if we actually got a keyset above,
        # but since we didn't, we have to make sure there's nothing left
        $self->{records} = ();
        
        # Now create a new record ( with defaults and insertion marker )
        
        # Note that we don't set the changed marker at this point, so if the user starts entering data,
        # this is treated as an inserted record. However if the user doesn't enter data, and does something else
        # ( eg another query ), this record will simply be discarded ( changed marker = 0 )
        
        # Keep in mind that this doens't take into account other requirements for a valid record ( eg foreign keys )
        push @{$self->{records}}, $self->_assemble_new_record;
        
    } else {
        
        # Reset 'inserting' flag
        $self->{inserting} = 0;
        
        if ( $upper > $keyset_count - 1 ) {
        	$upper = $keyset_count - 1;
        }
        
        my $key_list;
        my @pks =  $self->get_primarykeys;
        
        # Assemble query
        my $local_sql = $self->{sql}->{head} . $self->{sql}->{select};
	# $self->{log}->debug($local_sql);
        # Do we have an SQL wildcard ( * or % ) in the select string?
	# the 3 lines below blow up when the primary keys are included in the select value
	if (  $self->{sql}->{select} !~ /[\*|%]/ ){
	    # No? In that case, check we have the primary keys; append them if we don't - we need them
	    # $local_sql .= ", " . join( ', ', @{$self->{primary_keys}} );
	}
	# $self->{log}->debug($local_sql);
	$local_sql .= " from " . $self->{sql}->{from}. " where ( " . join( ', ', @pks ) . " ) in ( ";
	#
        # The where clause we're trying to build should look like:
        #
        # where ( key_1, key_2, key_3 ) in
        # (
        #    ( 1, 5, 8 ),
        #    ( 2, 4, 9 )
        # )
        # ... etc ... assuming we have a primary key spanning 3 columns
	# $self->{log}->debug("_fetch_new_slice lower: " . $lower . "  count : " . $keyset_count . " upper ". $upper); 
        for ( my $counter = $lower; $counter < $upper+1; $counter++ ) {
		 $local_sql .= " ( " . join( ",", $self->{keyset}[$counter] ) . " ),";
		 # $local_sql .= join( ",", $self->{keyset}[$counter] ) . " ";
            #$key_list .= " " . $self->{keyset}[$counter] . ",";
        }
        
        # Chop off trailing comma
        chop( $local_sql );
        
        $local_sql .= " )";
        
	if ( $self->{sql}->{order_by} ) {
            $local_sql .= " order by " . $self->{sql}->{order_by};
        }
	#$self->{log}->debug("_fetch_new_slice " . $local_sql);

        eval {
            $self->{records} = $self->{dbh}->selectall_arrayref (
                $local_sql, {Slice=>{}}
            ) || croak( $self->{dbh}->errstr . "\n\nLocal SQL was:\n$local_sql" );
        };
	# $self->{log}->debug("records: " .  join(" ", @{$self->{records}}));
        if ( $@ ) {
            Gtk2::Ex::Dialogs::ErrorMsg->new_and_run(
                title   => "Error fetching record slice!",
                icon    => "error",
                text    => "<b>Database server says:</b>\n\n" . $@
            );
	     croak( __PACKAGE__ . "::query died with the SQL:\n\n$local_sql\n" );
	    #return FALSE;
        }
        
        return TRUE;
        
    }
    
}

sub _assemble_new_record {
    
    # This sub assembles a new hash record and sets default values
    
    my $self = shift;
    #$self->{log}->debug("_assemble_new_record");
    my $new_record;
    
    # First, we create fields with default values from the database ...
    foreach my $fieldname ( keys %{$self->{column_info}} ) {
        # COLUMN_DEF is DBI speak for 'column default'
        my $default = $self->{column_info}->{$fieldname}->{COLUMN_DEF};
        if ( $default && $self->{server} =~ /microsoft/i ) {
            $default = $self->parse_sql_server_default( $default );
        }
        $new_record->{$fieldname} = $default;
    }
    
    # ... and then we set user-defined defaults
    foreach my $fieldname ( keys %{$self->{defaults}} ) {
        $new_record->{$fieldname} = $self->{defaults}->{$fieldname};
    }
    
    # Finally, set the 'inserting' flag ( but don't set the changed flag until the user actually changes something )
    $self->{inserting} = 1;
    
    return $new_record;
    
}

sub _last_insert_id {
    
    my $self = shift;
    
    my $primary_key;
    
    if ( $self->{server} =~ /postgres/i ) {
        
        # Postgres drivers support DBI's last_insert_id()
        
        $primary_key = $self->{dbh}->last_insert_id (
            undef,
            $self->{schema},
            $self->{sql}->{from},
            undef
        );
        
    } elsif ( lc($self->{server}) eq "sqlite" ) {
        
        $primary_key = $self->{dbh}->last_insert_id(
            undef,
            undef,
            $self->{sql}->{from},
            undef
        );
        
    } else {
        
        # MySQL drivers ( recent ones ) claim to support last_insert_id(), but I'll be
        # damned if I can get it to work. Older drivers don't support it anyway, so for
        # maximum compatibility, we do something they can all deal with.
        
        # The below works for MySQL and SQL Server, and possibly others ( Sybase ? )
        
        my $sth = $self->{dbh}->prepare( 'select @@IDENTITY' );
        $sth->execute;
        
        if ( my $row = $sth->fetchrow_array ) {
            $primary_key = $row;
        } else {
            $primary_key = undef;
        }
        
    }
    
    return $primary_key;
    
}


sub count {
    
    # Counts the records ( items in the keyset array ).
    # Note that this returns the REAL record count, and keep in mind that the first record is at position 0.
    
    my $self = shift;
    
    my $count_this;
    
    #if ( exists $self->{sql}->{pass_through} ) {
    if ( ! exists $self->{sql}->{from} && exists $self->{sql}->{pass_through} ) {
        $count_this = "records";
    } else {
        $count_this = "keyset";
    }
    
    if ( ref($self->{$count_this}) eq "ARRAY" ) {
        return scalar @{$self->{$count_this}};
    } else {
        return 0;
    }
    
}

1;

__END__

=pod

=head1 NAME

Gtk2::Ex::DbLinker::DbiDataManager - a module that get data from a database using DBI and sql commands

=head1 VERSION

See Version in L<Gtk2::Ex::DbLinker>

=head1 SYNOPSIS

	use DBI;
	use Gtk2 -init;
	use Gtk2::GladeXML;
	use Gtk2::Ex:Linker::DbiDataManager; 

	my $dbh = DBI->connect (
                          "dbi:mysql:dbname=sales;host=screamer;port=3306",
                          "some_username",
                          "salespass", {
                                           PrintError => 0,
                                           RaiseError => 0,
                                           AutoCommit => 1,
                                       }
	);
	 my $builder = Gtk2::Builder->new();
	 $builder->add_from_file($path_to_glade_file);

To fetch the data from the database

	  my $rdbm = Gtk2::Ex::DbLinker::DbiDataManager->new({
		 	dbh => $dbh,
		 	 primary_keys => ["pk_id"],
		sql =>{from => "mytable",
			select => "pk_id, field1, field2, field3"
		},
	 });

To link the data with a Gtk windows, have the Gtk entries ID, or combo ID in the xml glade file set to the name of the database fields: pk_id, field1, field2...

	  $self->{linker} = Gtk2::Ex::DbLinker::Form->new({ 
		    data_manager => $rdbm,
		    builder =>  $builder,
		    rec_spinner => $self->{dnav}->get_object('RecordSpinner'),
  	    	    status_label=>  $self->{dnav}->get_object('lbl_RecordStatus'),
		    rec_count_label => $self->{dnav}->get_object("lbl_recordCount"),
	    });

To add a combo box in the form:

	  my $dman = Gtk2::Ex::DbLinker::DbiDataManager->new({
			dbh => $dbh,
			sql => {
				select => "id, name",
				from => "table",
				order_by => "name ASC"
				},
		});

The first field given in the select value will be used as the return value of the combo.
C<noed> is the Gtk2combo id in the glade file and the field's name in the table displayed in the form.

    $self->{linker}->add_combo({
    	data_manager => $dman,
    	id => 'noed',
      });

And when all combos or datasheets are added:

      $self->{linker}->update;

To change a set of rows in a subform, listen to the on_changed event of the primary key in the main form:

		$self->{subform_a}->on_pk_changed($new_primary_key_value);

In the subform_a module:

	sub on_pk_changed {
		 my ($self,$value) = @_;
		$self->{jrn_coll}->get_data_manager->query({ where =>"pk_value_of_the_bound_table = ?", 
								bind_values => [ $value ],
							   });
		...
		}

=head1 DESCRIPTION

This module fetches data from a dabase using DBI and sql commands. A new instance is created using a database handle and sql string and this instance is passed to a Gtk2::Ex::DbLinker::Form object or to Gtk2::Ex::DbLinker::Datasheet objet constructors.

=head1 METHODS

=head2 constructor

The parameters to C<new> are passed in a hash reference with the keys C<dbh>, C<sql>, C<primary_keys>, C<ai_primary_keys>.
The value for C<primary_keys> and C<ai_primary_keys> are arrayrefs holding the field names of the primary key and auto incremented primary keys. 
If the table use a autogenerated key, use ai_primary_keys instead of primary_keys to set these.
C<dbh>, C<sql> are mandatory.
The value for C<sql> is a hash reference with the following keys : C<select> or C<select_distinct>, C<from>, C<where>, C<order_by>, C<bind_values>.

The value are

=over

=item *

C<select> or C<select_distinct> : a comma delimited string of the field names.

=item *

C<from> : a string of the join clause.

=item *

C<where> : a string of the where clause. Use place holders if the C<bind_values> keys is set.

=item *

C<order_by> : a string of the order by clause.

=item *

C<bind_values> : a array ref of the values corresponding to the place holders in the C<where> clause.

=item *

C<before_query> : a code ref to be run at the start of the query method.

=back

	Gtk2::Ex::DbLinker::DbiManager->new({ dbh => $dbh,
					    sql => {
							select_distinct => "abo.ref as ref, abo.type as type, abo.note as note, abo.debut as debut, abo.fin as fin, abo.nofrn as nofrn, abo.biblio as biblio, abo.encours as encours, abo.eonly as eonly",
				from   => "abo INNER JOIN jrnabt ON abo.noabt = jrnabt.noabt",
				where  => "nofm=?",
				order_by =>"abo.type ASC, abo.ref ASC",
				bind_values=> [$self->{nofm}],
				}
				});

=head2 C<query({ where => "pk=?" , bind_values=>[ $value ] });

To display an other set of rows in a form, call the query method on the datamanager instance for this form.

	my $dman = $self->{form_a}->get_data_manager();

	$dman->query({where=>"nofm=?", bind_values=>[ $f->{nofm} ]});
	
	$self->{form_a}->update;

The parameter of the query method is a hash reference with the folowing key / value pairs:

=over

=item *

C<where> : a string of the where clause, with placeholder if the bind_values array is set.

=item *

C<bind_values> : a array reference holding the value(s) corresponding to the placeholders of the where clause.

=back

=head2 C<save();> 

Build the sql commands tu insert a new record or update an existing record. Fetch the value from auto_incremented primary key.


=head2 C<save({ $field_name => $value });>

Pass a href to save when a value has to be saved in the database without using C< $dman->set_field($ field, $value ) >. Use this when you want to change a field that is part of a multiple fields primary key.

=head2 C<new_row();>

=head2 C<delete();>

=head2 C<set_row_pos( $new_pos); >

Change the current row for the row at position C<$new_pos>.

=head2 C<get_row_pos( );>

Return the position of the current row, first one is 0.

=head2 C<set_field ( $field_id, $value);>

Sets $value in $field_id. undef as a value will set the field to null.

=head2 C<get_field ( $field_id );>

return the value of the field C<$field_id> or undef if null.

=head2 C<get_field_type ( $field_id);>

Return one of varchar, char, integer, date, serial, boolean.

=head2 C<row_count();>

Return the number of rows.

=head2 C<get_field_names();>

Return an array of the field names.

=head2 C<get_primarykeys()>;

Return an array of primary key(s) (auto incremented or not). Can be supplied to the constructor, or are guessed by the code.

=head2 C<get_autoinc_primarykeys();>

Return an array of auto incremented primary key(s). If the names are not supplied to the constructor, the array of primary keys is returned.

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

L<Gtk2::Ex::DBI>
 
=head1 CREDIT

Daniel Kasak, whose code have been heavily borrowed from, to write this module.

=cut

