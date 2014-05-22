use strict;
use warnings;
use Rdb::Speak::Manager;

my $data = Rdb::Speak::Manager->get_speaks(query => [countryid => {eq => 7 }]);
my $row;

for $row (@$data){
	print "langid: ", $row->langid, "\n";
}

$row = @$data[0];
$row->langid(1);
$row->save or print("can't save");

print "in the current array of RDB objects:\n";

for $row (@$data){
	print "langid: ", $row->langid, "\n";
}

$data = Rdb::Speak::Manager->get_speaks(query => [countryid => {eq => 7 }]);

print "after saving and querying again...:\n";
for $row (@$data){
	print "langid: ", $row->langid, "\n";
}

