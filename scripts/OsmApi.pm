#!/usr/bin/perl
# <!-- coding: utf-8 -->
# OsmApi.pm
# auteur: Marc GAUTHIER
# licence : Paternité - Pas d’Utilisation Commerciale 2.0 France (CC BY-NC 2.0 FR)
#
# la partie requete http pour dialoguer avec l'api
#
# http://wiki.openstreetmap.org/wiki/API_v0.6
# http://wiki.openstreetmap.org/wiki/User:GranD/API_Perl_example
# https://github.com/h4ck3rm1k3/FOSM-Api/blob/master/OSM-API-Proxy/lib/OSM/API/Proxy.pm
# https://github.com/h4ck3rm1k3/FOSM-Api/blob/master/OSM-API-Proxy/lib/OSM/API/OsmChange.pm
# http://wiki.openstreetmap.org/wiki/OsmChange
package OsmApi;
use strict;
use utf8;
use Carp;
use English;
use Data::Dumper;
use MIME::Base64;
use URI;
use HTTP::Request;
# use Net::OAuth;
use LWP::UserAgent;
use Encode;
use XML::Parser;
use POSIX qw/strftime/;
# http://articles.mongueurs.net/magazines/linuxmag56.html
use LWP::Debug qw(+);
use HTML::Entities;
use base "Osm";
# c'est sale !
my (%node, %tags, @nd, $text, $changeset_id);
sub new {
  my( $class, $attr ) = @_;
  my $self =  {
  };
  while ( my ($key, $value) = each %{$attr} ) {
    warn "new() $key, $value";
    $self->{$key} = $value;
  }
  $self->{api} = "http://api06.dev.openstreetmap.org/api/0.6/";
  $self->{api} = "http://api.openstreetmap.org/api/0.6/";
#  my ($file, $return);
#  $file = "scripts/OsmApi.rc";
#  unless ($return = do $file) {
#    warn "couldn't parse $file: $@"         if $@;
#    warn "couldn't do $file: $!"            unless defined $return;
#    warn "couldn't run $file"               unless $return;
#  }
  bless($self, $class);
  my $file = "scripts/OsmApi.dmp";
  if ( -f $file ) {
    open my $fh, '<', $file or die "in() open $file erreur:$!";
    local $/ = undef;  # read whole file
    my $dumped = <$fh>;
    close $fh or die "new() $file erreur:$!";
#  confess Dumper $dumped;
    my %id =  %{eval $dumped};
    $self->{config} = \%id;
#    confess Dumper $self->{config};
  }
  $self->{'credentials'}->{'username'} = 'mga_geo@yahoo.fr';
  $self->{'credentials'}->{'password'} = 'osm83!39';
  $self->{ua} = new LWP::UserAgent(agent => 'mgaClientV6', timeout => 120);
#  confess "username:" . $self->{'credentials'}->{'username'};
  $self->{ua}->credentials('api.openstreetmap.org:80','Web Password',$self->{'config'}->{'osmapi'}->{'user'} => $self->{'config'}->{'osmapi'}->{'password'});
  return $self;
}
sub dump {
  my $self = shift;
  warn "dump()";
  if ( defined  $self->{osm} &&  $self->{osm} ne '' ) {
#    warn $self->{osm};
  }
}
#
# la partie changeset
sub changeset {
  my $self = shift;
  my $osm = shift;
  my $comment = shift;
  my $action = 'modify';
  if ( @_ ) {
    $action = shift;
  }
  my $f_osm = "$action.osm";
  open(OSM, "> :utf8",  $f_osm) or die "...() erreur:$! $f_osm";
  print(OSM $osm);
  close(OSM);
  if ( $self->{DEBUG} ) {
    warn "changeset() DEBUG $comment $action\n$osm";
    $self->{osm} .= $osm;
    return;
  }
  if ( $osm eq '' ) {
    return;
  }
  my ($url, $req, $res, $changeset_id, $timestamp, $text);
  $url = $self->{'api'} . "changeset/create";
  warn "changeset() comment:$comment $url";
  $req = new HTTP::Request 'PUT' => $url;
  $req->content_type('text/xml');
  $req->content("<osm><changeset><tag k='comment' v='$comment'/></changeset></osm>");
  $self->{ua}->timeout(600);
  $res = $self->{ua}->request($req);
  $self->{content} = '';
  if ( ! $res->is_success) {
    confess "changeset() create Error: " . $res->status_line;
  }
  $changeset_id = $res->content;
  $timestamp = strftime ("%Y-%m-%dT%H:%M:%S.0+02:00", gmtime);
  warn "changeset() id: $changeset_id";
#  confess $osm;
#  $osm =~ s{(<relation[^>]+version="\d+")[^>]*}{$1 changeset="$changeset_id" timestamp="$timestamp"}gsm;
  $osm =~ s{(changeset=")[^"]+"}{$1$changeset_id"}gsm;
  $osm =~ s{(timestamp=")[^"]+"}{$1$timestamp"}gsm;
  $text = "<osmChange version=\"0.3\" generator=\"mga_geo\">\n<${action}>\n";
  $text .= $osm;
  $text .= "\n</${action}>\n</osmChange>";
  if (utf8::is_utf8($text)) {
    warn "changeset() utf8";
    utf8::encode($text); #important!
  }
  $text =~ s{\n+}{\n}gsm;
#  warn $text;
  if ( $self->{DEBUG} ) {
    warn "changeset() DEBUG";
    return;
  }
  $url = $self->{'api'} . "changeset/$changeset_id/upload";
  warn "changeset() upload $url";
  $req = new HTTP::Request 'POST' => $url;
  $req->content_type('text/xml');
  $req->content($text);
  $res = $self->{ua}->request($req);
  if ( ! $res->is_success) {
    warn "changeset() upload Error: " . $res->status_line;
    warn "changeset() upload Error: " . $res->content;
    exit;
  }
  $url = $self->{'api'} . "changeset/$changeset_id/close";
  warn "changeset() close $url";
  $req = new HTTP::Request 'PUT' => $url;
  $res = $self->{ua}->request($req);
  if ( ! $res->is_success) {
    warn "changeset() close Error status_line: " . $res->status_line;
    warn "changeset() close Error: " . $res->content;
    exit;
  }
}
#
# la partie changeset sur un node
sub changeset_node {
  my $self = shift;
  my $id = shift;
  my ($url, $req, $changeset_id, $comment, $res, $text);
  $comment = 'maj Keolis octobre 2014';
  $url = $self->{'api'} . "changeset/create";
  warn "changeset() create $url";
  $req = new HTTP::Request 'PUT' => $url;
  $req->content_type('text/xml');
  $req->content("<osm><changeset><tag k='comment' v='$comment'/></changeset></osm>");
  $res = $self->{ua}->request($req);
  $self->{content} = '';
  if ( ! $res->is_success) {
    confess "changeset() create Error: " . $res->status_line;
  }
  $changeset_id = $res->content;
  warn "changeset() id: $changeset_id";
  $text = $self->modify_node($id, $changeset_id);
#  $text = $self->create_node(-1, $changeset_id);
  if (utf8::is_utf8($text)) {
    utf8::encode($text); #important!
  }
  $url = $self->{'api'} . "changeset/$changeset_id/upload";
  warn "changeset() upload $url";
  $req = new HTTP::Request 'POST' => $url;
  $req->content_type('text/xml');
  $req->content($text);
  $res = $self->{ua}->request($req);
  if ( ! $res->is_success) {
    confess "changeset() upload Error: " . $res->status_line;
  }
  $url = $self->{'api'} . "changeset/$changeset_id/close";
  warn "changeset() close $url";
  $req = new HTTP::Request 'PUT' => $url;
  $res = $self->{ua}->request($req);
  if ( ! $res->is_success) {
    confess "changeset() close Error: " . $res->status_line;
  }
}
sub osm_get {
  my $self = shift;
  my ($get, $f_osm) = @_;
  if ( ! $f_osm ) {
    confess "osm_get() f:$f_osm";
  }
  my ($osm);
#  $f_osm = "$self->{cfgDir}/relations_routes.osm";
  if ( ! -f "$f_osm" or  $self->{DEBUG_GET} > 0 ) {
    $get = "http://www.openstreetmap.org/api/0.6/$get";
    $osm = $self->get($get);
    open(OSM, ">",  $f_osm) or die "osm_get() erreur:$!";
    print(OSM $osm);
    close(OSM);
  } else {
    $osm = do { open my $fh, '<', $f_osm or die $!; local $/; <$fh> };
  }
#  confess $osm;
  my $hash = $self->osm2hash($osm);
  warn "osm_get() $f_osm nb_r:" . scalar(@{$hash->{relation}}) . " nb_w:" . scalar(@{$hash->{way}}) . " nb_n:" . scalar(@{$hash->{node}});
  return $hash;
}
#
# un get en http
# met à jour  $self->{content}
sub get {
  my $self = shift;
  my $url = shift;
  warn "get($url)";
  my $req = new HTTP::Request 'GET' => $url;
  my $res = $self->{ua}->request($req);
  $self->{content} = '';
  my $content = $res->content;
  utf8::decode($content);
  if ($res->is_success) {
    $self->{content} = $content;
  } else {
    warn "get($url) Error: " . $res->status_line;
  }
#  confess $self->{content};
  return $content;
}

# http://wiki.openstreetmap.org/wiki/API_v0.6
#
# récuperation d'un node
sub get_node {
  my $self = shift;
  my $id = shift;
  my $element = 'node';
  return $self->get("http://www.openstreetmap.org/api/0.6/$element/$id");
}
#
# create_node : création d'un node
sub create_node {
  my $self = shift;
  my $id = shift;
  my $changeset_id = shift;
  my $timestamp = strftime ("%Y-%m-%dT%H:%M:%S.0+02:00", gmtime);
  my $text = <<EOF;
<osmChange version="0.3" generator="mga_geo">
<create>
<node id="-1" timestamp="$timestamp" lat="48.0875052" lon="-1.6445175" changeset="$changeset_id" version="1">
  <tag k="highway" v="bus_stop"/>
  <tag k="name" v="La Poterie"/>
</node>
</create>
</osmChange>
EOF
  warn $text;
  return $text;
#  warn Dumper $oa->{content};
}
#
# modify_node : modification d'un node
sub modify_node {
  my $self = shift;
  my $id = shift;
  my $changeset_id = shift;
  my $xml = $self->get_node($id);

  my $parser = new XML::Parser(ProtocolEncoding => 'UTF-8', Handlers => {Start => \&xml_start});
  my $timestamp = strftime ("%Y-%m-%dT%H:%M:%S.0+02:00", gmtime);
  $parser->parse($xml);
  warn Dumper \%node;
  warn Dumper \%tags;
  $tags{'mga'} = 'geo';
  $node{'timestamp'} = $timestamp;
#  $node{version}++;
  $text = "<osmChange version=\"0.3\" generator=\"mga_geo\">\n<modify>\n";
  $text .= "<node id=\"$node{id}\" timestamp=\"$node{timestamp}\" lat=\"$node{lat}\" lon=\"$node{lon}\" changeset=\"$changeset_id\" version=\"$node{version}\">\n";
	for my $k(sort keys %tags) {
		$text .= "  <tag k=\"$k\" v=\"$tags{$k}\"/>\n";
	}
  $text .= "</node>\n</modify>\n</osmChange>";
  warn $text;
  return $text;
#  warn Dumper $oa->{content};
}
#
# modify_osm : modification d'un osm
sub modify_osm {
  my $self = shift;
  my $osm = shift;
  my $changeset_id = shift;
#  $node{version}++;
  $text = "<osmChange version=\"0.3\" generator=\"mga_geo\">\n<modify>\n";
  $text .= "</modify>\n</osmChange>";
  warn $text;
  return $text;
#  warn Dumper $oa->{content};
}


#
# xml_start : analyse avec mise en hashes
sub xml_start {
	my ($elem, $tag, %attr) = @_;
	if ($tag eq 'node' || $tag eq 'way') {
		for my $k (keys %attr) {
			$node{$k} = $attr{$k};
		}
	} elsif ($tag eq 'tag') {
		$tags{$attr{'k'}} = xml_escape($attr{'v'});
	} elsif ($tag eq 'nd') {
     push @nd, $attr{'ref'};
  }
}
# xml_escape échapppement de certains caractères
sub xml_escape {
  my $s = shift;
  $s =~ s/"/&quot;/g;
  $s =~ s/'/&apos;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  return $s;
}
1;