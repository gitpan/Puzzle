package Puzzle::Template::DBIxClassConverter;

our $VERSION = '0.15';

use base 'Class::Container';

sub resultset {
	my $self	= shift;
	my $rs		= shift;

	my $tblName	= $rs->result_source->name;

	my @all		= $rs->all;
	my @ret;

	foreach my $rec (@all) {
		my %rrow	= $rec->get_columns;
		my %row 	= %rrow;
		$row{"$tblName.$_"} = $rrow{$_} foreach(keys %rrow);
		push @ret,\%row;
	}

	return \@ret;
}

sub row {
	my $self	= shift;
	my $rs		= shift;

	my $tblName	= $rs->result_source->name;

	my %ret		= $rs->get_columns;
	$ret{"$tblName.$_"} = $ret{$_} foreach(keys %ret);

	return \%ret;
}

1;
