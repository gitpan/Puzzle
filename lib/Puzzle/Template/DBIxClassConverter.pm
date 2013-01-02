package Puzzle::Template::DBIxClassConverter;

our $VERSION = '0.17';

use base 'Class::Container';

sub resultset {
	my $self	= shift;
	my $rs		= shift;
	my $key		= shift || $rs->result_source->name;

	my @ret;

	while ($rec = $rs->next) {
		push @ret,$self->row($rec);
	}

	return {$key => \@ret};
}

sub row {
	my $self	= shift;
	my $rs		= shift;

	my $tblName	= $rs->result_source->name;

	my %ret		= $rs->get_columns;
	$ret{"$tblName.$_"} = $ret{$_} foreach(keys %ret);
	foreach (keys %{$rs->result_source->_relationships}) {
		my $rrow = $rs->$_;
		if (ref($rrow) eq 'DBIx::Class::ResultSet') {
			if ($rrow->count == 1) {
				my $single_row = $rrow->next;
				%ret = (%ret,%{$self->row($single_row)});
			} else {
				%ret = (%ret,%{$self->resultset($rrow)});
			}
		}
	}

	return \%ret;
}

1;
