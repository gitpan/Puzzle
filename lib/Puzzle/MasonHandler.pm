package Puzzle::MasonHandler;

our $VERSION = '0.02';

use HTML::Mason::ApacheHandler();

use strict;

{
	package Puzzle::Request;
	use Apache2::Request;
	use Apache2::Cookie;
	use Apache::DBI;
	use Apache::Session::MySQL;
	use I18N::AcceptLanguage;
	use HTML::Template::Pro::Extension;
}

my %ah;

sub params 		{return 	( 
						args_method			=> 'mod_perl',
              			comp_root			=> "/www/$_[0]/www",
               			data_dir			=> "/var/cache/mason/$_[0]",
						code_cache_max_size	=> 0,
						autoflush 			=> 0,
						dhandler_name 		=> 'dhandler.mpl',
						request_class		=> 'Puzzle::Request',
)};

sub handler {
	my ($r)	= @_;
	my $sn    = $r->dir_config('ServerName');
	$ah{$sn} = new HTML::Mason::ApacheHandler(&params($sn)) unless (exists $ah{$sn});
	return $ah{$sn}->handle_request($r);
}

1;

# vim: set ts=2:
