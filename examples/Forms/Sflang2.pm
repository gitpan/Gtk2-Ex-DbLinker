package Forms::Sflang2;

use strict;
use warnings;

use lib "../Gtk2-Ex-DbLinker/lib/";

use Gtk2::Ex::DbLinker::Form;
use Gtk2::Ex::DbLinker::Datasheet;

use Gtk2::Ex::DbLinker::RdbDataManager;

use Rdb::Speak::Manager;
use Rdb::Langue::Manager;
use Rdb::Country::Manager;

use Forms::Dnav2;

sub new {
	 my ( $class, $href ) = @_;

	  my $self = {
   	gladefolder => $$href{gladefolder},
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


	my $data = Rdb::Speak::Manager->get_speaks(query => [countryid => {eq => $self->{countryid} }]);

	my $dman = Gtk2::Ex::DbLinker::RdbDataManager->new({
			data => $data,
			meta => Rdb::Speak->meta,
			});

		$self->{sform} = Gtk2::Ex::DbLinker::Form->new({
		data_manager => $dman,
		builder => $self->{builder},
		rec_spinner => $self->{dnav}->get_object('RecordSpinner'),
	    	status_label=>  $self->{dnav}->get_object('lbl_RecordStatus'),
		rec_count_label => $self->{dnav}->get_object("lbl_recordCount"),
			});

		
		my $combodata = Gtk2::Ex::DbLinker::RdbDataManager->new({
				data => Rdb::Langue::Manager->get_langues(order_by => 'langue' ),
				meta => Rdb::Langue->meta,
			});
		
		$self->{sform}->add_combo({
			data_manager => $combodata,
		    	id => 'langid',
			builder => $self->{builder},	
			});
		my $list =  Gtk2::Ex::DbLinker::RdbDataManager->new({
				data => Rdb::Speak::Manager->get_speaks(query =>[langid => {eq => $self->{langid} }, countryid => {ne => $self->{countryid}}]),
				meta => Rdb::Speak->meta,
				
			});

		 $combodata = Gtk2::Ex::DbLinker::RdbDataManager->new({
				 data => Rdb::Country::Manager->get_countries(sort_by => 'country' ),
				 meta => Rdb::Country->meta,
			
			});

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
	
	$self->{sform}->get_data_manager->query(  Rdb::Speak::Manager->get_speaks(query => [countryid =>{ eq => $value } ]) );
	$self->{sform}->update;
	$value = $self->{sform}->get_widget_value("langid");
	$self->{log}->debug("sf_langues: langid changed $value");
	
	$self->{sf_list}->get_data_manager->query(  Rdb::Speak::Manager->get_speaks(query => [ langid => { eq => $value }, countryid => {ne => $self->{countryid}} ] ) );
	$self->{sf_list}->update;
	


}

sub on_langid_changed {
	my ($b, $self) = @_;
	my $value = $self->{sform}->get_widget_value('langid');
	if ($value) {
		$self->{log}->debug("sf_langues: langid_changed $value");
		$self->{langid} = $value;
		$self->{sf_list}->get_data_manager->query(  Rdb::Speak::Manager->get_speaks(query => [ langid => { eq => $value }, countryid => {ne => $self->{countryid}} ] ) );
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
