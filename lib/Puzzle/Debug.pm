package Puzzle::Debug;

our $VERSION = '0.14';

use base 'Class::Container';

use Data::Dumper;
use HTML::Entities;
use Time::HiRes qw(gettimeofday tv_interval);



use HTML::Mason::MethodMaker(
	read_only 		=> [ qw(timer) ],
);

sub sprint {
	my $self	= shift;
	my $tmpl	= $self->container->tmpl;
	my $html	= &Puzzle::Debug::debug_html_code();
	$tmpl->tmplfile(\$html);
	return $tmpl->html({$self->internal_objects_dump_for_html});
}

sub timer_reset {
	my $self	= shift;
	$self->{timer} = [gettimeofday];
}

sub internal_objects_dump_for_html {
	my $self		= shift;
  my $glob		= $self->all_mason_args_for_debug;
  my %debug;
  my $to_dump = sub { $_[0] =~ s/^\$VAR1\s*=\s*//;
                      $_[0] =~ s/(\'pw\'\s*\=\>\s*\'[^']+)/'pw' => '********/;
                      $_[0] =~ s/(\'password\'\s*\=\>\s*\'[^']+)/'password' => '********/;
                      $_[0] = encode_entities($_[0]);
                      $_[0] =~ s/\n/<br>/g;
                      $_[0] =~ s/\s/&nbsp;/g;
                      return $_[0]};
	$debug{debug_elapsed}	= tv_interval($self->timer);
  foreach my $key (qw/conf post args session env/) {
		delete $glob->{$key}->{container};
    foreach (sort {lc($a) cmp lc($b)} keys %{$glob->{$key}}) {
      my $dumper = &$to_dump(Data::Dumper::Dumper($glob->{$key}->{$_}));
      push @{$debug{"debug_$key"}},{ key => $_,value =>  $dumper};
    }
  }
  foreach (keys %{$self->container->post->args}) {
      my $dumper = &$to_dump(Data::Dumper::Dumper($self->container->post->args->{$_}));
      push @{$debug{"debug_http_post"}},{ key => $_,value =>  $dumper};
  }
  push @{$debug{"debug_cache"}}, {key => 'size',
    value => $self->container->_mason->cache(namespace=>$self->container->cfg->namespace)->size};
  my @cache_keys =$self->container->_mason->cache(namespace=>$self->container->cfg->namespace)->get_keys;
  foreach (@cache_keys) {
    push @{$debug{"debug_cache"}},
      {key => $_, value => &ParseDateString("epoch " .
        $self->container->_mason->cache(namespace=>$self->container->cfg->namespace)->get_object($_)->get_expires_at())};
  }	
	$debug{'puzzle_dump'} = $to_dump->(Data::Dumper::Dumper($self->container));
  return %debug
}


# TO DO : RECURSIVE AND REMOVE FROM DEBUG. OPTIMIZATION
sub all_mason_args {
	# ritorna tutti i parametri globali
	# alcuni normalizzati
	my $self	= shift;
	my $puzzle	= $self->container;
	return { 
			%{$puzzle->cfg->as_hashref}, 
			%{&_normalize_for_tmpl(&_normalize_for_tmpl(&_normalize_for_tmpl($puzzle->session->internal_session)))},
	  		%{&_normalize_for_tmpl($puzzle->post->args)},
			%{&_normalize_for_tmpl(&_normalize_for_tmpl($puzzle->args->args))}, 
			title => $puzzle->page->title,
	};
}

sub all_mason_args_for_debug {
	# ritorna tutti i parametri globali
	# alcuni normalizzati
	my $self  = shift;
	return { 
		conf => $self->container->cfg,
		session =>&_normalize_for_tmpl(&_normalize_for_tmpl(&_normalize_for_tmpl($self->container->session->internal_session))),
    post 	=> &_normalize_for_tmpl($self->container->post->args) ,
		args 	=> &_normalize_for_tmpl(&_normalize_for_tmpl($self->container->args->args)),
		env		=> 	\%ENV
	};
}

sub _normalize_for_tmpl {
  # questa funzione prende un hashref e lo aggiusta eventualmente
  # per essere compatibile con quello che si aspetta HTML::Template
  my $params = shift;
  my %as = %{$params};
  foreach (keys %as) {
    # gestisco dei casi particolari
    if (ref($as{$_}) eq 'ARRAY' && defined($as{$_}->[0])
      && ref($as{$_}->[0]) eq '') {
      # HTML::Template si aspetta in questo caso degli hashref come
      # elementi ma se, come nel caso di form HTML con elementi con
      # name uguali, si ha un ARRAY di scalar allora lo devo gestire
      $as{"$_.array.count"} = scalar(@{$as{$_}});
      for (my $i=0;$i<$as{"$_.array.count"};$i++) {
        $as{"$_.array.$i"} = $as{$_}->[$i];
      }
      delete $as{$_};
    } elsif (ref($as{$_}) eq 'HASH') {
			# QUESTA FUNZIONE VA RESA RICORSIVA
			while (my ($k,$v) = each %{$as{$_}}) {
				$as{"$_.$k"} = $v;
			}
			delete $as{$_};
		}
  }
	return \%as;
}


sub debug_html_code {
	return <<EOF;
<!-- required debug.css and debug.js -->

<!-- INIT: DEBUG TABBED -->
<ul id="tablist">

<li><a href="#" class="current" onClick="return expandcontent('sc1', this)">DEBUG MENU</a></li>
<li><a href="#" onClick="return expandcontent('sc2', this)" theme="#EAEAFF">POST HTTP</a></li>
<li><a href="#" onClick="return expandcontent('sc3', this)" theme="#EAEAFF">Al template</a></li>
<li><a href="#" onClick="return expandcontent('sc4', this)" theme="#FFE6E6">Al template dal POST HTTP</a></li>
<li><a href="#" onClick="return expandcontent('sc5', this)" theme="#DFFFDF">Sessione</a></li>
<li><a href="#" onClick="return expandcontent('sc6', this)" theme="#AFAFAF">Configurazione</a></li>
<li><a href="#" onClick="return expandcontent('sc7', this)" theme="#D0F0D0">Ambiente</a></li>
<li><a href="#" onClick="return expandcontent('sc8', this)" theme="#BFBFDF">Cache</a></li>
<li><a href="#" onClick="return expandcontent('sc9', this)" theme="#FF9F9F">Puzzle</a></li>
</ul>

<DIV id="tabcontentcontainer">

<div id="sc1" class="tabcontent">
Pagina valutata in <b>%debug_elapsed%</b> secondi.<br />
</div>

<div id="sc2" class="tabcontent">
<table border="0">
<TMPL_LOOP NAME="debug_http_post">
        <tr>
        <td valign="top" >
<font color="#0000FF" class="debugcella">%key%</font></td>
        <td valign="top" class="debugcella"> 
        =&gt;</td> <td valign="top" class="debugcella">
        %value% </td>
        </tr>
</TMPL_LOOP>
</table>
</div>

<div id="sc3" class="tabcontent">
<table border="0">
<TMPL_LOOP NAME="debug_args">
        <tr>
        <td valign="top" >
<font color="#0000FF" class="debugcella">%key%</font></td>
        <td valign="top" class="debugcella"> 
        =&gt;</td> <td valign="top" class="debugcella">
        %value% </td>
        </tr>
</TMPL_LOOP>
</table>

</div>

<div id="sc4" class="tabcontent">
<table border="0">
<TMPL_LOOP NAME="debug_post">
        <tr>
        <td valign="top" >
<font color="#0000FF" class="debugcella">%key%</font></td>
        <td valign="top" class="debugcella"> 
        =&gt;</td> <td valign="top" class="debugcella">
        %value% </td>
        </tr>
</TMPL_LOOP>
</table>
</div>

<div id="sc5" class="tabcontent">
<table border="0">
<TMPL_LOOP NAME="debug_session">
        <tr>
        <td valign="top">
<font color="#0000FF" class="debugcella">%key%</font></td>
        <td valign="top" class="debugcella"> 
        =&gt;</td> <td valign="top" class="debugcella">
        %value%</td>
</tr>
</TMPL_LOOP>
</table>

</div>
<div id="sc6" class="tabcontent">
<table border="0">
<TMPL_LOOP NAME="debug_conf">
        <tr>
        <td valign="top" >
<font color="#0000FF" class="debugcella">%key%</font></td>
        <td valign="top" class="debugcella"> 
        =&gt;</td> <td valign="top" class="debugcella">
        %value% </td>
        </tr>
</TMPL_LOOP>
</table>
</div>

<div id="sc7" class="tabcontent">
<table border="0">
<TMPL_LOOP NAME="debug_env">
        <tr>
        <td valign="top" >
<font color="#0000FF" class="debugcella">%key%</font></td>
        <td valign="top" class="debugcella"> 
        =&gt;</td> <td valign="top" class="debugcella">
        %value% </td>
        </tr>
</TMPL_LOOP>
</table>
</div>
<div id="sc8" class="tabcontent">
<table border="0">
<TMPL_LOOP NAME="debug_cache">
        <tr>
        <td valign="top" >
<font color="#0000FF" class="debugcella">%key%</font></td>
        <td valign="top" class="debugcella"> 
        =&gt;</td> <td valign="top" class="debugcella">
        %value% </td>
        </tr>
</TMPL_LOOP>
</table>
</div>

<div id="sc9" class="tabcontent">
<font color="#000000" class="debugcella">
<PRE>
%puzzle_dump%
</PRE>
</font>
</div>


</DIV>
EOF
}

1;
