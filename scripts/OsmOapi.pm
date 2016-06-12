#!/usr/bin/perl
# <!-- coding: utf-8 -->
# OsmOapi.pm
# auteur: Marc GAUTHIER
# licence : Paternité - Pas d’Utilisation Commerciale 2.0 France (CC BY-NC 2.0 FR)
#
# la partie requete http sur l'overpass
package OsmOapi;
use strict;
use Carp;
use Data::Dumper;
use MIME::Base64;
use URI;
use HTTP::Request;
# use Net::OAuth;
use LWP::UserAgent;
use Encode;
use POSIX qw/strftime/;
# http://articles.mongueurs.net/magazines/linuxmag56.html
use LWP::Debug qw(+);
use HTML::Entities;
use XML::Simple;
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
  $self->{api} = "http://api.openstreetmap.org/api/0.6/";
  bless($self, $class);
  $self->{ua} =  new LWP::UserAgent(agent => 'mgaClientV6', timeout => 400);
  return $self;
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
    $osm = $self->get($get);
    open(OSM, ">",  $f_osm) or die "osm_get() erreur:$! $f_osm";
    print(OSM $osm);
    close(OSM);
  } else {
    $osm = do { open my $fh, '<', $f_osm or die $!; local $/; <$fh> };
  }
#  confess $osm;
  my $hash = $self->osm2hash($osm);
  warn "osm_get() DEBUG_GET:" . $self->{DEBUG_GET} . " $f_osm nb_r:" . scalar(@{$hash->{relation}}) . " nb_w:" . scalar(@{$hash->{way}}) . " nb_n:" . scalar(@{$hash->{node}});
  return $hash;
}
#
# un get en http
# met à jour  $self->{content}
sub get {
  my $self = shift;
  my $data = shift;
  warn "get($data)";
  my $url = sprintf('http://overpass-api.de/api/interpreter?data=[timeout:360];%s', $data);
#  $url = sprintf('http://oapi-fr.openstreetmap.fr/oapi/interpreter?data=[timeout:360];%s', $data);
#  $url = sprintf('http://overpass.osm.rambler.ru/cgi/interpreter?data=[timeout:360];%s', $data);
#  $url = sprintf('http://api.openstreetmap.fr/oapi/interpreter?data=[timeout:360][maxsize:1073741824];%s', $data);
  $self->{content} = '';
  my $nb_essai = 3;
  my $req = new HTTP::Request 'GET' => $url;
  my $res;
  while ( $nb_essai-- > 0 ) {
    $res = $self->{ua}->request($req);
    if ($res->is_success) {
      $self->{content} = $res->content;
    } else {
      warn "get($url) Error: " . $res->status_line;
    }
    if ( $res->content !~ m{<strong style="color:#FF0000">Error</strong>} ) {
      last;
    }
    &now;
    warn $res->content;
    sleep 5;
  }
  return $res->content;
}
sub now {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  my $now = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
  warn $now;
}
#
# récuperation des relations route=master
sub get_relations_route_master {
  my $self = shift;
  return $self->get("relation[network=fr_star][route_master=bus];out meta;");
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
sub tri_tags_ref {
  my $self = shift;
  my $aa = $a->{tags}->{ref};
  my $bb = $b->{tags}->{ref};
  my ($an) = $aa =~ /^(\d+)/;
  my ($bn) = $bb =~ /^(\d+)/;
  if ( $an && $bn ) {
    $an <=> $bn;
  } else {
    $aa cmp $bb;
  }
}

1;