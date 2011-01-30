package Puzzle::Core;

our $VERSION = '0.03';

use 5.008008;
use strict;
use warnings;

use YAML qw(LoadFile);
use Puzzle::Config;
use Puzzle::DBI;
use HTML::Mason::Request;

use Params::Validate qw(:types);
use base 'Class::Container';

__PACKAGE__->valid_params(
	cfg_path			=> { parse 	=> 'string', type => SCALAR},
	session				=> { isa 		=> 'Puzzle::Session' },
	lang_manager	=> { isa 		=> 'Puzzle::Lang::Manager' },
	cfg						=> { isa 		=> 'Puzzle::Config'} ,
	tmpl					=> { isa 		=> 'Puzzle::Template'} ,
	dbg						=> { isa 		=> 'Puzzle::Debug'} ,
	args					=> { isa 		=> 'Puzzle::Args'} ,
	post					=> { isa 		=> 'Puzzle::Post'} ,
	sendmail			=> { isa 		=> 'Puzzle::Sendmail'} ,
);

__PACKAGE__->contained_objects (
	session    		=> 'Puzzle::Session',
	lang_manager	=> 'Puzzle::Lang::Manager',
	cfg						=> 'Puzzle::Config',
	tmpl					=> 'Puzzle::Template',
	dbg						=> 'Puzzle::Debug',
	args					=> 'Puzzle::Args',
	post					=> 'Puzzle::Post',
	page					=> {class => 'Puzzle::Page', delayed => 1},
	sendmail			=> 'Puzzle::Sendmail',
);


# all new valid_params are read&write methods
use HTML::Mason::MethodMaker(
	read_only 		=> [ qw(cfg_path dbh tmpl lang_manager lang dbg args page sendmail post) ],
	read_write		=> [ 
		[ cfg 			=> __PACKAGE__->validation_spec->{'cfg'} ],
		[ session		=> __PACKAGE__->validation_spec->{'session'} ],
		[ error			=> { parse 	=> 'string', type => SCALAR} ],
	]
);

sub new {
	my $class 	= shift;
	# append parameters required for new contained objects loading them
	# from YAML config file
	my $cfgH		= LoadFile($_[1]);
	my @params	= qw(frames base frame_bottom_file frame_left_file frame_top_file
										frame_right_file gids login description keywords db
										namespace debug cache auth_class traslation mail page);
	foreach (@params){
		push @_, ($_, $cfgH->{$_}) if (exists $cfgH->{$_});
	}
	# initialize class and their contained objects
	my $self 	= $class->SUPER::new(@_);
	$self->_init;
	return $self;
}


sub _init {
	my $self	= shift;
	
	# inizializzazione classi delayed
	my $center_class = 'Puzzle::Block';
	if ($self->cfg->page) {
		$center_class = $self->cfg->page->{center} if (exists $self->cfg->page->{center});
	}
	$self->{page} = $self->create_delayed_object('page',center_class => $center_class);
	

	$self->_autohandler_once;
}

sub _autohandler_once {
	my $self	= shift;
	$Apache::Session::Store::DBI::TableName = $self->cfg->db->{session_table};
	$Apache::Request::Redirect::LOG = 0;
	my $dbi = 'dbi:mysql:database=' . $self->cfg->db->{name} . 
		';host=' . $self->cfg->db->{host};
	$self->{dbh} 	||= new Puzzle::DBI($dbi,$self->cfg->db->{username},
		$self->cfg->db->{password});
}

sub process_request{
	my $self	= shift;
	my $html;
	&_mason->apache_req->no_cache(1);
	$self->post->_set({$self->_mason->request_args});
	$self->session->load;
	# enable always debug for debug users
	$self->cfg->debug(1) if $self->session->user->isGid('debug');
	$self->dbg->timer_reset if $self->cfg->debug;
	# configure language object
	$self->{lang} = $self->lang_manager->get_lang_obj;
	# and send to templates
	$self->args->lang($self->lang_manager->lang_name);
	$self->_login_logout;
	$self->page->process;
	if ($self->page->center->direct_output) {
		$html	= $self->page->center->html;
	} else {
		my $args = {
			frame_bottom		=> $self->page->bottom->body,
			frame_left			=> $self->page->left->body,
			frame_top			=> $self->page->top->body,
			frame_right			=> $self->page->right->body,
			frame_center		=> $self->page->body,
			header_client		=> $self->page->headers,
			body_attributes		=> $self->page->body_attributes,
			%{$self->dbg->all_mason_args},
		};
		$args->{frame_debug} = $self->dbg->sprint if ($self->cfg->debug);
		$self->tmpl->autoDeleteHeader(0);
		$html = $self->tmpl->html($args,$self->cfg->base);
	}
	print $html;
	$self->session->save;
	#$self->dbh->disconnect unless ($self->cfg->db->{persistent_db})
}

sub _login_logout {
	my $self	= shift;
	if ($self->post->logout) {
		$self->session->auth->logout;
	} elsif ($self->post->user ne '' && $self->post->pass ne '') {
		$self->session->auth->login($self->post->user, $self->post->pass);
	}
}

sub _mason  {
	return HTML::Mason::Request->instance();
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Puzzle - A Web framework 

=head1 SYNOPSIS

In httpd.conf or virtual host configuration file

  <IfModule mod_perl.c>
    AddType text/html .mpl
    PerlSetVar ServerName "myservername"
    <FilesMatch "\.mpl$">
      SetHandler  perl-script
      PerlHandler Puzzle::MasonHandler
    </FilesMatch>
    <LocationMatch "(\.mplcom|handler|\.htt)$|autohandler">
      SetHandler  perl-script
      PerlInitHandler Apache2::Const::HTTP_NOT_FOUND
    </LocationMatch>
  </IfModule>

in your document root, a config.yaml like this

  frames:           0
  base:              ~
  frame_bottom_file: ~
  frame_left_file:   ~
  frame_right_file:  ~
  frame_top_file:    ~
  # you MUST CHANGE auth component because this is a trivial auth controller
  # auth_class:   "Puzzle::Session::Auth"
  # auth_class:   "YourNameSpace::Auth"
  gids:
                - everybody
  login:        /login.mpl
  namespace:    cov
  description:  ""
  keywords:     ""
  debug:        1
  cache:        0
  db:
    username:               your_username
    password:               your_password
    host:                   your_hosts
    name:                   your_db_name
    session_table:          sysSessions
    persistent_connection:  0
  #traslation:
  #it:           "YourNameSpace::Lang::it"
  #default:      it
  mail:
    server:       "your.mail.server"
    from:         "your@email-address"

in your document root, a Mason autohandler file like this

  <%once>
    use Puzzle::Core;
    use abc;
  </%once>
  <%init>
    $abc::puzzle ||= new Puzzle::Core(cfg_path => $m->interp->comp_root
	  .  '/config.yaml';
    $abc::dbh = $abc::puzzle->dbh;
    $abc::puzzle->process_request;
  </%init>

an abc module in your @ISA path

  package abc;

  our $puzzle;
  our $dbh;

  1;



=head1 DESCRIPTION

Puzzle is a web framework based on HTML::Mason, HTML::Template::Pro with
direct support to dabatase connection via DBIx::Class. It include a
template system, a session user tracking and a simple authentication and
authorization login access for users with groups and privileges.

=head1 SEE ALSO

For update information and more help about this framework take a look to:

http://code.google.com/p/puzzle-cpan/

=head1 AUTHOR

Emiliano Bruni, E<lt>info@ebruni.it<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Emiliano Bruni

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
