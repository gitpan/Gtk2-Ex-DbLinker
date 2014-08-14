package Forms::Dnav2;
use strict;
use warnings;
use Forms::Tools;
use Carp qw( carp croak );
our $debug=1;
use Data::Dumper;

my %refs = map { $_, 1} qw(Gtk2::Ex::Datasheet::DBI Linker::Datasheet Gtk2::Ex::DbLinker::Datasheet);
my %ref_form = map {$_,1} qw(Gtk2::Ex::DBI Linker::Form Gtk2::Ex::DbLinker::Form);

sub new {
    
    my ( $class, $ismain, $size_ref ) = @_;
     debug("new Dnav  ", join(" ", @_), "\n");
    my $self = {};
    $self->{msg}="Dnav";
    $self->{ismain}=(defined $ismain ? $ismain : 1);
    # print "ismain is : ", $self->{ismain}, " received : ", (defined $ismain? $ismain:'undef'),"\n";
    #  $self->{globals} = $globals;
     my $builder = Gtk2::Builder->new();
     #    %INC is another special Perl variable that is used to cache the names of the files and 
     #    the modules that were successfully loaded and compiled by use(), require() or do() statements.
     # my $path= $INC{"Forms/Dnav2.pm"};
     
     # $path =~ s/\/Forms\/Dnav2.pm// ; #Enlever /Forms/Dnav.pm de $path
     #$builder->add_from_file( $path . "\\Forms\\dnav.bld")   or die "Couldn't read  glade/dnav.bld";
     my $path;
     $self->{w2hide}=[];
     $self->{size}=$size_ref;
   if ($ENV{PAR_TEMP}){
	   $path = $ENV{PAR_TEMP}. "/inc/" ."Forms/dnav.bld";
	   #$path = $ENV{PAR_TEMP}. "/inc/" ."glade/dnav.bld";
    } else {
	$path =  "./Forms/dnav2.bld";
    }
     $builder->add_from_file($path);
     $self->{glade_xml} = $builder;	
     # $self->{glade_xml}->connect_signals($self);
    if ($self->{ismain}){
	     $self->{glade_xml}->get_object("mainwindow")->signal_connect("destroy", \&gtk_main_quit);
	}
    $self->{events_id}={};
    $self->{events_callback}={"add" => \&on_add_clicked, "del"=> \&on_delete_clicked, "cancel"=>\&on_cancel_clicked, "apply"=>\&on_apply_clicked};
    for my $n (keys %{$self->{events_callback}}){
	my $id = $builder->get_object($n)->signal_connect('clicked', $self->{events_callback}->{$n}, $self);
	$self->{events_id}->{$n}=$id;
    }
    # $self->{data}= $dataref;
     bless $self, $class;
}
sub set_dataref {
	my ($self, $dataref) = @_;
	#the line below defined on what the button will call the delete, undo, add calls
	#it is the main reason of calling this method and giving it Gtk2::Ex::DbLinker::Form instance
	#
	$self->{data}=$dataref;
	# show_all($self);
	croak("No instance found for set_dataref ") unless ($dataref);
	my $ref =  ref $dataref;
	# if the instance received is a grid, hide a few things:
	if ( $refs{$ref} ){
		#my $l = $self->{glade_xml}->get_object('lbl_RecordStatus');
		#$l->hide();
		$self->{ismain}=0;
		#Gtk2::Widget::hide($self->{glade_xml}->get_object('RecordSpinner'));
		#Gtk2::Widget::hide($self->{glade_xml}->get_object('lbl_recordCount'));
		#Gtk2::Widget::hide($self->{glade_xml}->get_object('menubar1'));
		push @{$self->{w2hide}}, (	$self->{glade_xml}->get_object('RecordSpinner'),
						$self->{glade_xml}->get_object('lbl_recordCount'), 
						$self->{glade_xml}->get_object('menubar1'),
		 				$self->{glade_xml}->get_object('lbl_RecordStatus')
					);
	} else {	
			
			carp ("$ref not found with set_dataref")  unless ( $ref_form{ $ref });

	}
}

sub get_builder {
	my $self = shift;
	return $self->{glade_xml};
}

sub add_widgets2hide {
	my ($self, @allnames)= @_;
	foreach my $n (@allnames){
		debug( "add_w2h:  $n\n");
		push @{$self->{w2hide}}, $self->{glade_xml}->get_object($n);
	}
}

sub connect_signal_for {
	my ($self, $btn, $sub_ref, $data, $signal) = @_;
	my $b = $self->{glade_xml}->get_object($btn);
	croak "Dnav connect_signal_for failed since no widget instance exists for $btn" unless($b);
	$signal = ($signal?$signal:"clicked");
	if (exists ${$self->{events_id}}{$btn}){
	#deconnecter
		my $id = $self->{events_id}->{$btn};
		$b->signal_handler_disconnect($id); 
	}
	$b->signal_connect($signal, $sub_ref, $data);
}

sub show_tables {
	my ($self, $sql, $dbh) = @_;
	#my $dbh = $self->{globals}->{connections}->{dbh};
	my  $sth = $dbh->prepare($sql);
	
	$sth->execute;
	my $menu = $self->{glade_xml}->get_object('menu1');
	# die unless ($menu);
	while (my @row = $sth->fetchrow_array()){
		# print $row[0],"\n";
		my $t = Gtk2::MenuItem->new($row[0]);
		$t->signal_connect('activate', sub {display_tbl($self, {name => $row[0]}, $dbh);});
		# push @tbl, $t
		$menu->append($t);
		$t->show;
	}


}

sub display_tbl {
	my ($self, $href, $dbh) = @_;
	my $treeview = Gtk2::TreeView->new();
	my $rs_def;
	if ($href->{name}){
		$rs_def = {dbh =>$dbh,sql=> {	
	select => "*", from => $href->{name}},
			treeview =>  $treeview
		}
	} elsif ($href->{sql}){
		$rs_def = { dbh => $dbh,sql=> {
	pass_through => $href->{sql}},
			treeview => $treeview
			}
		
	}
	my $f = Forms::Dnav->new(0);
	my $scroll = Gtk2::ScrolledWindow->new;
	$scroll->add ($treeview);
	$f->add_ctrl($scroll);
	# print "$name\n";
	my $rs = Gtk2::Ex::Datasheet::DBI->new( $rs_def ) || die ("Error setting up Gtk2::Ex::Datasheet::DBI\n");
	$f->set_dataref($rs);
	# $f->test();
	$f->show_all_except;
	
}

sub show_querries {
	my ($self, $dbh) = @_;
	my $q = Config::YAML::Tiny->new(config=> "querries.txt");
	my $i = $q->{items};
	my $menu = $self->{glade_xml}->get_object('menu2');
 	foreach my $n (@$i){
	     # foreach my $v (keys %$n){
	     # print "$v ", $n->{$v}, "\n";
		# print $row[0],"\n";
			my $t = Gtk2::MenuItem->new($n->{menu});
			$t->signal_connect('activate', sub {display_tbl($self, {sql => $n->{sql}}, $dbh);});
			$t->set_tooltip_text($n->{comment});
			$menu->append($t);
		#$t->show;
	     #}
	 }
 }

sub show_all_except {
	my ($self, $ar_ref) = @_; 
	my @size = $self->{size}?@{$self->{size}}:(800,400);
	my $w = $self->{glade_xml}->get_object('mainwindow');  $w->set_default_size (@size); $w->show_all;
	foreach my $name (@$ar_ref){
		my $w = $self->{glade_xml}->get_object($name);
		debug( "hiding ", ($w ? $name : " but can't cause undefined object with $name"), "\n");
		$w->hide if ($w);
	}
	foreach my $w (@{$self->{w2hide}}){
		debug( "hiding : ", Forms::Tools::getID($w),"\n");
		$w->hide if ($w);
	}
}

sub add_ctrl {
	my ($self, $ctrl)=@_;
	 my $sfctrl = $self->{glade_xml}->get_object('main');
	 #  Gtk2::Widget::reparent($ctrl, $sfctrl);
	 # $ctrl->destroy;
	 $sfctrl->add($ctrl);
}


sub reparent {
	my ($self, $ctrl, $subw)=@_;
	 my $sfctrl = $self->{glade_xml}->get_object('main');
	 my $title =$subw->get_title();
	  $self->{glade_xml}->get_object('mainwindow')->set_title($title) if ($title);
	 Gtk2::Widget::reparent($ctrl, $sfctrl);
	 debug( "widget name: ", Forms::Tools::getID($subw), " main: ", $self->{ismain}, "\n");
	 $subw->destroy;
}

sub on_add_clicked 	{ my ($b, $self) = @_; $self->{data}->insert;}
sub on_cancel_clicked 	{ my ($b, $self) = @_; $self->{data}->undo;}
sub on_delete_clicked 	{ my ($b, $self) = @_; debug(print "in Dnav...\n"); $self->{data}->delete;}
sub on_apply_clicked 	{ my ($b, $self) = @_; $self->{data}->apply;}

sub get_object {
 my ($self, $ctrl_name) = @_;
 $self->{glade_xml}->get_object($ctrl_name);
}

sub test {my $self = shift; print  $self->{msg}, " in dnav.pm\n";}

sub gtk_main_quit {
	my ($w)=@_;
  	Gtk2->main_quit;
 }

sub debug {
	print(join(" ", @_)) if $debug;
}

1;
__END__

=head1 NAME

Package Forms::Dnav

A Navigation toolbar (nvabar for short), that can be used for a mainwindow, and that has two predefinned menu, or that can be used to navigate the records in a subform (and the menu are hidden then).

This module should be placed under a lib directory and the PERL5LIB environment variable should point to it.

=head1 
Depends also on

=over

=item *
Forms::Tools

=item *
a glad xml file with path lib/Forms/dnav.bld and the lib directory beeing define in the PERL5LIB environement variable (ie U:\docs\perl\lib on my pc)

=back

=head1 
SYNOPSIS

	$self->{dnav} = Forms::Dnav->new();
	my $b = $self->{dnav}->get_builder;
	$b->add_from_file( some glade files ) or die "Couldn't read ...";
	$b->connect_signals($self);


Build a navbar around a mainform

	$self->{dnav} =  Forms::Dnav->new(0);

Get a new Dnav object that will be used for a subform navigation. The predefinned menu in the navbar will not show

	$self->{dnav}-connect_signal_for("button name", \&code_ref, $data, $signal);

	$self->{dnav}->connect_signal_for("mainwindow", \&gtk_main_quit, $self, "destroy" ); 

Where

=over

=item *
button name is the button id in the glade file

=item *
&code_ref is a function to be called on click (default) unless a string is given in $signal

=item *
$data a ref to the Dnav object or to the main form object

=back 
	  
	$self->{dnav}->set_dataref($self->{jrn});
 
Where

=over

=item *
C<< $self->{jrn} >> est une ref E<agrave> un recordset issu de C<< Gtk2::Ex::DBI->new () >>

=back


	  my $w =$self->{glade_xml}->get_object('jrn');
  	  my $ctr= $self->{glade_xml}->get_object('vbox1');

	   $self->{dnav}->reparent($ctr, $w);
 
Where

=over

=item  *
C<< $self->{glade_xml}->get_object('jrn'); >> is a ref to the top window of the form

=item *
C<<  $self->{glade_xml}->get_object('vbox1'); >> is a ref to the first vbox that is a child of this top window

=item *
C<< $self->{dnav}->reparent($ctr, $w); >> place the content of the C<$ctr>  widget in the navbar, take the title of C<$w> and place it in the navbar and destroy this window

=back

=cut
