package Puzzle::Lang::Manager;

our $VERSION = '0.12';

use strict;
no strict 'refs';
use warnings;

use Params::Validate qw(:types);;
use base 'Class::Container';
use I18N::AcceptLanguage;

use HTML::Mason::MethodMaker(
	read_only 		=> [ qw(lang_name) ],
);

sub get_lang_obj { 
	# select language by session or browser and returnà
	# the class istance related
	my $self		= shift;
	my $obj;
	$self->{lang_name}= $self->container->session->lang eq ''
		? $self->browser
		: $self->container->session->lang;
	my $obj         = 'Puzzle::Lang::Base';
	if (defined $self->container->cfg->traslation) {
		if (exists $self->container->cfg->traslation->{$self->{lang_name}}) {
			$obj = $self->container->cfg->traslation->{$self->{lang_name}};
		} elsif (exists $self->container->cfg->traslation->{default} &&
		exists $self->container->cfg->traslation->{$self->container->cfg->traslation->{default}}) {
			$obj = $self->container->cfg->traslation->{$self->container->cfg->traslation->{default}};
		}
	}
	(my $obj_path = $obj . '.pm') =~s/::/\//g ;
	require $obj_path;
	my $newobj = new $obj;
	die "$obj must be a subclass of Puzzle::Lang::Base" unless $newobj->isa("Puzzle::Lang::Base");
	return $newobj;
} 

sub browser {
	# return browser supported lang between those defined in config
	my $self					= shift;
	my $acceptor			= I18N::AcceptLanguage->new(strict => 0);
	$acceptor->strict(0);
	if (defined $self->container->cfg->traslation) {
		my @defined_lang	= keys %{$self->container->cfg->traslation};
		my $default = $self->container->cfg->traslation->{default} || 'en';
		my $lang			= $acceptor->accepts($ENV{HTTP_ACCEPT_LANGUAGE}, \@defined_lang);
		$acceptor->defaultLanguage($self->container->cfg->traslation->{default});
		return $lang;
	}
}

1;
