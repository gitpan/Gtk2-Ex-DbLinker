package Forms::Sflang2_dbi;

use strict;
use warnings;

#use lib "../Gtk2-Ex-DbLinker/lib/";

use Gtk2::Ex::DbLinker::Form;
use Gtk2::Ex::DbLinker::Datasheet;

use Gtk2::Ex::DbLinker::DbiDataManager;

use Forms::Dnav2;

sub new {
	 my ( $class, $href ) = @_;

	  my $self = {
   	gladefolder => $$href{gladefolder},
	dbh => $$href{dbh},
	countryid => $$href{countryid},
   };

    $self->{log} = Log::Log4perl->get_logger(__PACKAGE__);

    $self->{dnav} = Forms::Dnav2->new(0);

	   $self->{dnav}->connect_signal_for("add", \&on_add_clicked, $self );
   $self->{dnav}->connect_signal_for("del", \&on_delete_clicked, $self );
   $self->{dnav}->connect_signal_for("apply", \&on_apply_clicked, $self );



	$self->{builder} =  $self->{dnav}->get_builder;

	   $self->{builder}->add_from_file($self->{gladefolder} . "/sflang2.bld");
	$self->{builder}->connect_signals($self);

	#inclusion of the subform in his navigation tool
	 my $w =$self->{builder}->get_object('sflang_window');
   	my $ctr= $self->{builder}->get_object('vbox1');
	  $self->{dnav}->reparent($ctr, $w);

	  #my $rs = $self->{schema}->resultset('Speak')->search_rs({countryid => $self->{countryid}});


	my $dman = Gtk2::Ex::DbLinker::DbiDataManager->new({
			dbh => $self->{dbh},
			sql => {
				select => "speaksid, countryid, langid",
				from => "speaks",
				where => "countryid = ?",
				bind_values => [$self->{countryid}],
			},
			});

		$self->{sform} = Gtk2::Ex::DbLinker::Form->new({
		data_manager => $dman,
		builder => $self->{builder},
		rec_spinner => $self->{dnav}->get_object('RecordSpinner'),
	    	status_label=>  $self->{dnav}->get_object('lbl_RecordStatus'),
		rec_count_label => $self->{dnav}->get_object("lbl_recordCount"),
			});

		#rs => $self->{schema}->resultset('Langue')->search_rs(undef, { order_by => 'langue' }),		
		my $combodata = Gtk2::Ex::DbLinker::DbiDataManager->new({
				dbh => $self->{dbh},
				sql => {
					select => "langid, langue",
					from => "langues",
					order_by => "langue",
				},


			});
		
		$self->{sform}->add_combo({
			data_manager => $combodata,
		    	id => 'langid',
			builder => $self->{builder},	
			});
		# 	Rdb::Speak::Manager->get_speaks(query =>[langid => {eq => $self->{langid} }, countryid => {ne => $self->{countryid}}]),
#rs => $self->{schema}->resultset('Speak')->search_rs({langid => $self->{langid}, countryid => {'!=' => $self->{countryid} }}), 	
		my $list =  Gtk2::Ex::DbLinker::DbiDataManager->new({
				dbh => $self->{dbh},
				sql => {
					select => "speaksid, countryid, langid",
					from => "speaks",
					where => "langid = ? and countryid != ?",
					bind_values => [$self->{langid}, $self->{countryid}],

				},
			});
		# 	rs => $self->{schema}->resultset('Country')->search_rs(undef, { order_by => 'country'} ),
		 $combodata = Gtk2::Ex::DbLinker::DbiDataManager->new({
					dbh => $self->{dbh},
					sql => {
						select => "countryid, country",
						from => "countries",
						order_by => "country",
					},
			});
		$self->{dnav}->set_dataref($self->{sform});
		my $tree =  Gtk2::TreeView->new();

		$self->{sf_list} = Gtk2::Ex::DbLinker::Datasheet->new({
				treeview => $tree,
				data_manager => $list,
				fields => [	{name=>"langid", renderer=>"hidden"},
			    			{name=>"countryid", renderer => "combo", data_manager=> $combodata, fieldnames => ["countryid", "country"],}
		          		],
				});

		#set up the datasheet
		#
		$self->{sf_list}->{dnav} = Forms::Dnav2->new(0);
		 $self->{sf_list}->{dnav}->connect_signal_for("add", \&on_add_lst_clicked, $self);
		my $scroll = Gtk2::ScrolledWindow->new;
		$scroll->add ($tree);
		 $self->{sf_list}->{dnav}->add_ctrl($scroll);
		 $self->{sf_list}->{dnav}->set_dataref($self->{sf_list});

		 $self->{sform}->add_childform($self->{sf_list});

	 	my $ctrl_from = $self->{sf_list}->{dnav}->get_object('vbox1_main');
		my $ctrl_to = $self->{builder}->get_object('alignment1');
	        Gtk2::Widget::reparent($ctrl_from, $ctrl_to);
	 	
		#$sf_list->show_all_except(["mainwindow"]);

		bless $self, $class;

}

sub on_countryid_changed {
	 my ($self,$value) = @_;
	$self->{log}->debug("sf_langues: countryid_changed $value");
	$self->{countryid}=$value;
	#$self->{schema}->resultset('Speak')->search_rs({ countryid => $value})
	$self->{sform}->get_data_manager->query({ where => "countryid = ?" , bind_values => [$value] });
	# Rdb::Speak::Manager->get_speaks(query => [countryid =>{ eq => $value } ]) 
	$self->{sform}->update;
	$value = $self->{sform}->get_widget_value("langid");
	$self->{log}->debug("sf_langues: langid changed $value");
	# $self->{schema}->resultset('Speak')->search_rs({langid => $value, countryid => {'!=' => $self->{countryid}} }) 
 	# Rdb::Speak::Manager->get_speaks(query => [ langid => { eq => $value }, countryid => {ne => $self->{countryid}} ] ) 
	$self->{sf_list}->get_data_manager->query( {where => "langid = ? and countryid != ?", bind_values => [$value, $self->{countryid}], });
	$self->{sf_list}->update;
	


}

sub on_langid_changed {
	my ($b, $self) = @_;
	my $value = $self->{sform}->get_widget_value('langid');
	if ($value) {
		$self->{log}->debug("sf_langues: langid_changed $value");
		$self->{langid} = $value;
		#  $self->{schema}->resultset('Speak')->search_rs({langid => $value, countryid => {'!=' => $self->{countryid}} })
		$self->{sf_list}->get_data_manager->query({where => "langid = ? and countryid != ?", bind_values => [$value, $self->{countryid}], } );
		# Rdb::Speak::Manager->get_speaks(query => [ langid => { eq => $value }, countryid => {ne => $self->{countryid}} ] ) );
		$self->{sf_list}->update;
	}
}

sub on_delete_clicked {
    my $b = shift;
    my $self = shift;
    $self->{sform}->delete;
}

sub on_add_clicked {
    my $b = shift;
    my $self = shift;
    $self->{sform}->insert;
    $self->{sform}->set_widget_value("countryid",$self->{countryid});
    
}


sub on_apply_clicked {
    my $b = shift;
    my $self = shift;
    $self->{log}->debug("sform_apply country : " . $self->{countryid} . " langue : " . $self->{langid} );
    $self->{sform}->apply;
}



sub on_add_lst_clicked {
	my ($b, $self) = @_;
	$self->{sf_list}->insert($self->{sf_list}->{colname_to_number}->{"langid"} =>  $self->{sform}->get_widget_value("langid"));
	

}


1;
