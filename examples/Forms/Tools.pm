package Forms::Tools;


=head1 NAME

Package Forms::Tools

Utility functions for Dnav bar

=cut
use Carp;
use strict;
use warnings;
use Exporter;
# use vars qw($VERSION @ISA @EXPORT_OK);
our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
$VERSION     = 1.00;
@ISA         = qw(Exporter);
%EXPORT_TAGS = ( 'all' => [ qw(widgets_set_sensitivity populate_widgets) ] );
@EXPORT_OK =( @{ $EXPORT_TAGS{'all'} });


=head2 widgets_set_sensitivity( $array_ref $value )

call the C<set_sensitive( $value )> methods on all the widget received in C<@$array_ref>

=cut

sub widgets_set_sensitivity {

 	my ($lst_ref, $val) = @_;

	# print "set_sensitivity $val size: ", scalar @$lst_ref , "\n";
	for my $w (@$lst_ref){
		# print $w->get_name,"\n";
		$w->set_sensitive($val);
	}
}

=head2 populate_widgets ( $widget, $array_ref, $id )

Cheks that C<$widget> is a Gtk2::Container and populate @$array_ref with all its descendant having an id different from $id and that are sensible - C<get_sensitive> returns true - 

This array can then be used with C< widgets_set_sensitivity> to change the sensitivity in one go

=cut

sub populate_widgets {
 my ($w, $lst_ref, $keepit, $no_warn) = @_;
# print "populate widgtets ", $w->get_name, " " , ref $w, " ", ( $w->isa('Gtk2::Container') ? " is a container" : " is not a container"), "\n";
 return unless $w->isa('Gtk2::Container');
 my @c = $w->get_children;
if( !defined $no_warn && scalar @c == 0) {
 	carp "Tools.pm - populate widgets received a conainer widget with no children" ;
 }
 for my $c ($w->get_children){
	 	my $name = $c->get_name;
		# print "populate widgets 1: $name\n";
		my $id =getID($c);
	 	if ($c->get_sensitive && $c->isa('Gtk2::Buildable') && $name ne "GtkVBox" && $name ne "GtkHBox" && $id ne ""){
		
			# print "populate widgets 2: $id $name\n";	
			if ($id ne $keepit){
				# $c->set_sensitive(0);
				push @$lst_ref, $c;
			} 
		}
		populate_widgets ($c, $lst_ref, $keepit, 1);
 	}
}

=head2 getID ( $widget )

Returns the C<$widget> Id or an empty string if none is found

=cut

sub getID {
	my $w = shift;
	my $ref = ref $w;
       my $id;	
	# get the id
	#print "$ref\n";
	if ($w) {
		$id = ( bless $w, "Gtk2::Buildable" )->get_name;  
# restore package
		bless $w, $ref;      
	}
	return  ($id?$id:"")

}

1;
