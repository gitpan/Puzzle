package Puzzle::Template::DBIxClassConverter;

our $VERSION = '0.16';

use base 'Class::Container';

sub resultset {
	my $self	= shift;
	my $rs		= shift;

	my $tblName	= $rs->result_source->name;

	my @ret;

	while ($rec = $rs->next) {
		push @ret,$self->row($rec);
	}

	return {$tblName => \@ret};
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
