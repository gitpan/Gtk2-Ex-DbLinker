package Forms::Langues2_dbi;

use strict;
use warnings;
# use DBI;


#use lib "../Gtk2-Ex-DbLinker/lib/";

use Gtk2::Ex::DbLinker::Form;
use Gtk2::Ex::DbLinker::Datasheet;

use Gtk2::Ex::DbLinker::DbiDataManager;

use  Log::Log4perl;

use Forms::Dnav2;
use Forms::Sflang2_dbi;

sub new {
    
    my ( $class, $href ) = @_;
   
   my $self = {
   	gladefolder => $$href{gladefolder},
	dbh => $$href{dbh},
   };

  
    $self->{dnav} = Forms::Dnav2->new();

   $self->{log} = Log::Log4perl->get_logger(__PACKAGE__);

    my $builder = $self->{dnav}->get_builder;

    

      #my $data = Rdb::Country::Manager->get_countries(sort_by => 'country');

    my $dman =  Gtk2::Ex::DbLinker::DbiDataManager->new({
			dbh => $self->{dbh},
			sql => {
				select => "countryid, country, mainlangid",
				from => "countries",
			}
		
		});
	#$self->{schema}->resultset('Langue')->search_rs(undef, {order_by => 'langue'})


     $builder->add_from_file($self->{gladefolder} . "/langues2.bld") or die "Couldn't read  langues2.bld";

     $builder->connect_signals($self);

     $self->{linker} = Gtk2::Ex::DbLinker::Form->new({ 
		    data_manager => $dman,
		    builder =>  $builder,
		    rec_spinner => $self->{dnav}->get_object('RecordSpinner'),
  	    	    status_label=>  $self->{dnav}->get_object('lbl_RecordStatus'),
		    rec_count_label => $self->{dnav}->get_object("lbl_recordCount"),
	    });

   
#rs =>  $self->{schema}->resultset('Langue')->search_rs(undef, {sort_by => 'langue'}),
      my $combodata = Gtk2::Ex::DbLinker::DbiDataManager->new({
		      dbh => $self->{dbh},
		      sql => {
		      	select => "langid, langue",
			from => "langues",
			order_by => "langue",
		      },
			
		});
	
	$self->{linker}->add_combo({
    		data_manager => $combodata,
	    	id => 'mainlangid',
      });
  #do not name the toplevel window of the form 'mainwindow', since 
  # it's the name of the top level window in the navigation window
  # and we can't have two identical id in the same widgets tree.
     my $w =$builder->get_object('mainform');
     my $ctr= $builder->get_object('vbox1');

    $self->{dnav}->reparent($ctr, $w);

	$self->{sf} = Forms::Sflang2_dbi->new({gladefolder => $self->{gladefolder}, dbh => $self->{dbh} , countryid => $self->{countryid}});

	#mainwindow is the top level window of the subform navigation tool 
	my $subform = $self->{sf}->{dnav}->get_object('mainwindow');
	#vbox1_main is child object of this top level window in the nav tool
  	my $vbox = $self->{sf}->{dnav}->get_object('vbox1_main');
	#alignment1 is the control that will received vbox1_main
	my $sfctrl = $builder->get_object('alignment1');

	Gtk2::Widget::reparent($vbox, $sfctrl);
	$subform->destroy();
	
	$builder->get_object("vbox4")->show_all;
	#$sf->show_all_except(["mainwindow"]);

	$builder->get_object("mainwindow")->signal_connect("destroy", \&gtk_main_quit);

	#$self->{linker}->update;
	$self->{linker}->add_childform($self->{sf}->{sform});

	 $self->{dnav}->connect_signal_for("add", \&on_add_clicked, $self );
  	 $self->{dnav}->connect_signal_for("del", \&on_delete_clicked, $self );
   	$self->{dnav}->connect_signal_for("apply", \&on_apply_clicked, $self );

	show_tables($self);
	 $self->{dnav}->set_dataref($self->{linker});	
	 $self->{dnav}->show_all_except();
	 $self->{sf}->{dnav}->show_all_except(["mainwindow", "menubar1", "countryid"]);

	 $self->{sf}->{sf_list}->{dnav}->show_all_except(["mainwindow"]);
         $self->{linker}->update;

	     bless $self, $class;

     }



sub on_countryid_changed {
        my $b = shift;
	my $self = shift;
	$self->{log}->debug("countryid_changed called");
	my $value = $b->get_text();
	return unless defined ($value);
	$self->{log}->debug("on_countryid_changed : $value");
	$self->{countryid} = $value;
	$self->{sf}->on_countryid_changed($value);
 }

 sub on_delete_clicked {
    
    my ($b,$self) = @_;
	$self->{linker}->delete;
 
}

sub on_add_clicked {    
    my ($b, $self) = @_;
    # print Dumper($self);
    $self->{linker}->insert;
    
} 

 sub on_apply_clicked {
     my $b = shift;
    my $self = shift;

    $self->{linker}->apply;

    
}
sub show_tables {
	my $self = shift;
	my $dbh = $self->{dbh};
	my  $sth = $dbh->prepare('SELECT name FROM sqlite_master WHERE type = "table" AND name NOT LIKE "sqlite_%"');
	$sth->execute;
	my $menu = $self->{dnav}->get_object('menu1');
	die unless ($menu);
	while (my @row = $sth->fetchrow_array()){
		# print $row[0],"\n";
		my $t = Gtk2::MenuItem->new($row[0]);
		$t->signal_connect('activate', sub {display_tbl($self, {name => $row[0]});});
		# push @tbl, $t
		$menu->append($t);
		# $t->show;
	}
}

sub display_tbl {

	#my %class = (speaks => 'Speak', langues => 'Langue', countries =>'Country');

	my ($self, $href) = @_;
	my $treeview = Gtk2::TreeView->new();
	my $rs_def;
	#my $meta;
	my $data;
	if ($href->{name}){
		$self->{log}->debug("name : " . $href->{name});
		# my $rs = $self->{schema}->resultset($name)->search_rs();
		
		#$data = Gtk2::Ex::DbLinker::DbcDataManager->new({ rs => $rs});
		$data = Gtk2::Ex::DbLinker::DbiDataManager->new({sql=>{select => "*", from=> $href->{name}}, dbh=>$self->{dbh}});
	}
	my $f = Forms::Dnav2->new(0);
	my $scroll = Gtk2::ScrolledWindow->new;
	$scroll->add ($treeview);
	$f->add_ctrl($scroll);
	my $rs = Gtk2::Ex::DbLinker::Datasheet->new({
		treeview => $treeview,
		data_manager => $data,
	});
	$rs->update();
	$f->show_all_except(["menubar1"]);
	$f->set_dataref($rs);
	$f->show_all_except();
}



sub gtk_main_quit {
	my ($w)=@_;
  	Gtk2->main_quit;
 }

1;
