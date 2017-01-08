#!/usr/bin/perl
# <!-- coding: utf-8 -->
# Osm.pm
# auteur: Marc GAUTHIER
# licence : Paternité - Pas d’Utilisation Commerciale 2.0 France (CC BY-NC 2.0 FR)
#
#
# génération au format OSM
package Osm;
use strict;
use utf8;
use Carp;
use Data::Dumper;
use English;
use XML::Simple;
use Text::Diff;
use Text::Diff::Table;
use OsmMisc;
sub new {
  my( $class, $attr ) = @_;
  my $self =  {
    DEBUG => 0,
    node_id => 0,
    relation_id => 0,
  };
  while ( my ($key, $value) = each %{$attr} ) {
    warn "new() $key, $value";
    $self->{$key} = $value;
  }
  bless($self, $class);
  return $self;
}
sub init {
  return <<'EOF';
<?xml version='1.0' encoding='UTF-8'?>
<osm version="0.6" upload="false" generator="keolis.pl">
EOF
}
sub fin {
  return <<'EOF';
</osm>
EOF
}
sub delete_tags {
  my $self = shift;
  my $osm = shift;
  my $tag_keys = shift;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  my @lignes = split(/\n/, $osm);
  @lignes = grep ( !/tag k="($tag_keys)"/, @lignes);
  $osm = join("\n", @lignes);
  return $osm;
}
sub modify_latlon {
  my $self = shift;
  my $osm = shift;
  my $lat = shift;
  my $lon = shift;
  $osm =~ s{ lat="[^"]+"}{ lat="$lat"}sm;
  $osm =~ s{ lon="[^"]+"}{ lon="$lon"}sm;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  return $osm;
}
sub modify_name {
  my $self = shift;
  my $osm = shift;
  my $name = shift;
  $osm =~ s{<tag k="name" v="[^"]+"/>}{<tag k="name" v="$name"/>};
#  confess $osm;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  return $osm;
}
sub modify_tags {
  my $self = shift;
  my $osm = shift;
  my $tags = shift;
  my @tags = @_;
  foreach my $tag (sort @tags ) {
    if ( $self->{DEBUG} >= 2 ) {
      warn "modify_tags() $tag:" . $tags->{$tag};
    }
    my $ligne = '<tag k="' . $tag . '" v="' . $tags->{$tag} . '"/>';
#  <tag k="from" v="Saint-Laurent"/>
    if ( $osm =~ m{<tag k="$tag" v="[^"]+"/>}sm ) {
#      warn  "modify_tags() MATCH" . $MATCH;
      $osm = $PREMATCH . $ligne . $POSTMATCH;
    } else {
      $osm =~ s{</(node|way|relation)>}{ $ligne\n</$1>};
    }
  }
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
#  confess $osm;
  return $osm;
}
sub node_stops {
  my $self = shift;
  my $table = shift;
  my $format = <<'EOF';
  <node lat="%s" lon="%s" id="%s">
    <tag k="highway" v="bus_stop"/>
    <tag k="public_transport" v="platform"/>
    <tag k="name" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="ref" v="%s"/>
  </node>
EOF
#  confess Dumper $table;
  my $osm = $self->init();
  for my $hashref ( @{$table} ) {
#    confess Dumper $hashref;
    $self->{node_id}--;
    $osm .= sprintf($format, $hashref->{stop_lat}, $hashref->{stop_lon}, $self->{node_id}, $hashref->{stop_name}, $hashref->{stop_id}, $self->{k_ref}, $hashref->{stop_id});
  }
  $osm .= $self->fin();
  return $osm;
}
#
# création d'un node bicycle à partir des données Keolis
sub node_bicycle {
  my $self = shift;
  my $hash = shift;
#  confess Dumper $hash;
  my $format = <<'EOF';
  <node id="%s" lat="%s" lon="%s" version="1" timestamp="0" changeset="1">
    <tag k="amenity" v="bicycle_rental"/>
    <tag k="network" v="Vélo STAR"/>
    <tag k="operator" v="STAR"/>
    <tag k="name" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="capacity" v="%s"/>
    <tag k="source" v="Keolis Rennes"/>
  </node>
EOF
  $self->{node_id}--;
  return sprintf($format, $self->{node_id}, $hash->{latitude}, $hash->{longitude}, $hash->{name}, $hash->{number},  $hash->{bikesavailable} +  $hash->{slotsavailable});
}
#
# création d'un node recycling à partir des données de Rennes Métropole
# http://wiki.openstreetmap.org/wiki/FR:Tag:amenity%3Drecycling
sub node_recycling {
  my $self = shift;
  my $hash = shift;
  my $osm = <<'EOF';
  <node lat="%s" lon="%s" id="%s" timestamp="0" changeset="1" version="1">
  </node>
EOF
  $self->{node_id}--;
  $osm = sprintf($osm, $hash->{Y_WGS84}, $hash->{X_WGS84}, $self->{node_id});
  my $tags = $self->{tags};
  if ( $hash->{CODE_CARTO} =~ m{VE} ) {
    $tags->{"recycling:glass"} = "yes";
  }
  if ( $hash->{CODE_CARTO} =~ m{JM} ) {
    $tags->{"recycling:paper"} = "yes";
  }
  if ( $hash->{CODE_CARTO} =~ m{OM} ) {
#    $tags->{"recycling:waste"} = "yes";
  }
  $tags->{ref} = $hash->{ID_PAV};
  my $format = '';
  while ( my ($k, $v) = each %{$tags} ) {
    $format .= sprintf('<tag k="%s" v="%s"/>', $k, $v) . "\n";
  }
  $osm =~ s{</node>}{$format</node>};
  return $osm;
}
sub node_recycling_update {
  my $self = shift;
  my $osm = shift;
  my $hash = shift;
  my $osm_hash = $self->osm2hash($osm);
#  confess Dumper $osm_hash;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  $osm =~ s{\s*<tag k.*?"/>}{}gsm;
  my $tags = $osm_hash->{node}[0]->{tags};
  while ( my ($k, $v) = each %{$self->{tags}} ) {
    $tags->{$k} = $v;
  }
  $tags->{ref} = $hash->{ID_PAV};
#  confess Dumper $tags;
  my $format = '';
  while ( my ($k, $v) = each %{$tags} ) {
    $format .= sprintf('<tag k="%s" v="%s"/>', $k, $v) . "\n";
  }
  $osm =~ s{</node>}{$format</node>};
#  confess $osm;
  return $osm;
}
#
# création d'un node bus_stop à partir des données Keolis
sub node_stop {
  my $self = shift;
  my $hash = shift;
  my $format = <<'EOF';
  <node lat="%s" lon="%s" id="%s" timestamp="0" changeset="1" version="1">
    <tag k="highway" v="bus_stop"/>
    <tag k="public_transport" v="platform"/>
    <tag k="name" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="ref:%s" v="%s"/>
    <tag k="source" v="%s"/>
  </node>
EOF
  $self->{node_id}--;
  return sprintf($format, $hash->{stop_lat}, $hash->{stop_lon}, $self->{node_id}, $hash->{stop_name}, $hash->{stop_id}, $self->{network}, $hash->{stop_id}, $self->{source});
}
#
# suppression d'un node à partir des données osm
sub node_delete {
  my $self = shift;
  my $hash = shift;
  my $format = <<'EOF';
  <node lat="%s" lon="%s" id="%s" timestamp="0" changeset="1" version="%s">
  </node>
EOF
  return sprintf($format, $hash->{lat}, $hash->{lon}, $hash->{id}, $hash->{version});
}
sub node_disused {
  my $self = shift;
  my $osm = shift;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  $osm =~ s{<tag k="highway" v="bus_stop"/>}{<tag k="disused:highway" v="bus_stop"/>}sm;
  return $osm;
}
#
# création d'une relation public_transport=network
sub relation_public_transport_network {
  my $self = shift;
#  confess Dumper $self;
  my $hash = shift;
#  warn Dumper $hash;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="name" v="%s"/>
    <tag k="network" v="%s"/>
    <tag k="operator" v="%s"/>
    <tag k="public_transport" v="network"/>
    <tag k="type" v="network"/>
    <tag k="website" v="%s"/>
  </relation>
EOF
  $self->{relation_id}--;
  return sprintf($format, $self->{relation_id}, $self->{name}, $self->{network}, $self->{operator}, $self->{website});
}
#
# création d'une relation route=bus à partir des données Keolis
sub relation_route_bus {
  my $self = shift;
#  confess Dumper $self;
  my $hash = shift;
#  warn Dumper $hash;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="ref" v="%s"/>
    <tag k="ref:fr_star" v="%04d"/>
    <tag k="name" v="Bus Rennes Ligne %s Direction %s"/>
    <tag k="description" v="%s"/>
    <tag k="direction" v="%s"/>
    <tag k="from" v="%s"/>
    <tag k="to" v="%s"/>
    <tag k="network" v="fr_star"/>
    <tag k="operator" v="STAR"/>
    <tag k="route" v="bus"/>
    <tag k="type" v="route"/>
    <tag k="colour" v="#%s"/>
    <tag k="text_color" v="#%s"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
  $self->{relation_id}--;
  return sprintf($format, $self->{relation_id}, $hash->{ref}, $hash->{ref}, $hash->{ref}, $hash->{to}, xml_escape($hash->{description}), $hash->{to}, $hash->{from} , $hash->{to}
    , $hash->{trip}[0]->{route_color}, $hash->{trip}[0]->{route_text_color}, $self->{source} );
}
#
# création d'une relation type=route route=bus à partir des données GTFS
sub relation_route {
  my $self = shift;
  my $iti = shift;
  warn "relation_route() ref:" . $iti->{ref};
  $self->{relation_id}--;
#  confess Dumper $iti;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="description" v="%s"/>
    <tag k="direction" v="%s"/>
    <tag k="name" v="Bus Rennes Ligne %s Direction %s"/>
    <tag k="network" v="fr_star"/>
    <tag k="operator" v="STAR"/>
    <tag k="ref" v="%s"/>
    <tag k="from" v="%s"/>
    <tag k="to" v="%s"/>
    <tag k="route" v="bus"/>
    <tag k="type" v="route"/>
    <tag k="colour" v="#%s"/>
    <tag k="text_color" v="#%s"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
  my $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{description}), $iti->{to}, $iti->{ref}, $iti->{to}, $iti->{ref}, $iti->{from}, $iti->{to}, $iti->{trip}[0]->{route_color}, $iti->{trip}[0]->{route_text_color}, $self->{source});
#  warn $osm;
  return $osm;
}

#
# création d'une relation type=route_master route_master=bus à partir des données GTFS
sub relation_route_master {
  my $self = shift;
  my $iti = shift;
  if ( not defined $iti->{route_short_name} ) {
    warn "relation_route_master() *** route_short_name";
    confess Dumper $iti;
  }
  warn "relation_route_master() route_short_name:" . $iti->{route_short_name};
  $self->{relation_id}--;
#  warn Dumper $iti;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="description" v="%s"/>
    <tag k="name" v="Bus Rennes Ligne %s"/>
    <tag k="network" v="fr_star"/>
    <tag k="operator" v="STAR"/>
    <tag k="ref" v="%s"/>
    <tag k="route_master" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="type" v="route_master"/>
    <tag k="colour" v="#%s"/>
    <tag k="text_color" v="#%s"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
  my $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{route_long_name}), $iti->{route_short_name}, $iti->{route_short_name}, $iti->{route_color}, $iti->{route_text_color}, $self->{source});
#  warn $osm;
  return $osm;
}
#
# création d'une relation type=route route=bus à partir des données wfs
sub relation_route_wfs {
  my $self = shift;
  my $iti = shift;
  warn "relation_route_wfs() ref:" . $iti->{id};
  $self->{relation_id}--;
#  confess Dumper $iti;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="name" v="%s"/>
    <tag k="network" v="fr_%s"/>
    <tag k="ref" v="%s"/>
    <tag k="route" v="bus"/>
    <tag k="type" v="route"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
  my $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{NOM_LIGNE}), $self->{network}, $iti->{NUM_LIGNE}, $self->{source});
#  warn $osm;
  return $osm;
}
#
# création d'une relation type=route_master route_master=bus à partir des données wfs
sub relation_route_master_wfs {
  my $self = shift;
  my $iti = shift;
  $self->{relation_id}--;
#  warn Dumper $iti;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="description" v="%s"/>
    <tag k="name" v="Bus Illenoo Ligne %s"/>
    <tag k="network" v="%s"/>
    <tag k="ref" v="%s"/>
    <tag k="route_master" v="bus"/>
    <tag k="service" v="busway"/>
    <tag k="type" v="route_master"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
  my $osm = sprintf($format , $self->{relation_id}, xml_escape($iti->{NOM_LIGNE}), $iti->{NUM_LIGNE}, $self->{network}, $iti->{NUM_LIGNE}, $self->{source});
#  warn $osm;
  return $osm;
}
#
# création d'une relation stop_area à partir des données GTFS
sub relation_stop_area {
  my $self = shift;
  my $name = shift;
  warn "relation_stop_area()";
  $self->{relation_id}--;
#  warn Dumper $iti;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="1">
    <tag k="name" v="%s"/>
    <tag k="network" v="fr_star"/>
    <tag k="operator" v="STAR"/>
    <tag k="public_transport" v="stop_area"/>
    <tag k="type" v="public_transport"/>
    <tag k="source" v="%s"/>
  </relation>
EOF
  my $osm = sprintf($format, $self->{relation_id}, $name, $self->{'source'});
  return $osm;
}
#
# suppression d'une relatione à partir des données osm
sub relation_delete {
  my $self = shift;
  my $hash = shift;
  my $format = <<'EOF';
  <relation id="%s" timestamp="0" changeset="1" version="%s">
  </relation>
EOF
  return sprintf($format, $hash->{id}, $hash->{version});
}
sub relation_delete_member_platform {
  my $self = shift;
  my $osm = shift;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  my @lignes = split(/\n/, $osm);
  @lignes = grep ( !/role="platform"/, @lignes);
  $osm = join("\n", @lignes);
  return $osm;
}
sub relation_replace_member {
  my $self = shift;
  my $osm = shift;
  my $regexp = shift;
  my $members = shift;
  $members = "\n$members";
  chomp $members;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  $osm =~ s{\s*$regexp}{}gsm;
  $osm =~ s{(<relation.*)}{$1$members};
  return $osm;
}
sub relation_replace_tags {
  my $self = shift;
  my $osm = shift;
  my $tags = shift;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  $osm =~ s{\s*<tag k.*?"/>}{}gsm;
  my @tags = split("\n", $tags);
  @tags = grep(/<tag/, @tags);
  $tags = "\n" . join("\n", @tags);
  $osm =~ s{(<relation.*)}{$1$tags};
  return $osm;
}
sub relation_disused {
  my $self = shift;
  my $osm = shift;
  $osm =~ s{.*<(node|way|relation)}{<$1}sm;
  $osm =~ s{</(node|way|relation)>.*}{</$1>}sm;
  $osm =~ s{<tag k="line" v="bus"/>}{<tag k="disused:route" v="bus"/>}sm;
  $osm =~ s{<tag k="route_master" v="bus"/>}{<tag k="disused:route_master" v="bus"/>}sm;
  return $osm;
}
#
# récupération des données OSM
# ============================
sub osm2fic {
  my $self = shift;
  my ($get, $f_osm) = @_;
  if ( ! $f_osm ) {
    confess "osm2fic() f:$f_osm";
  }
  my ($osm);
  warn "osm2fic() $f_osm $self->{DEBUG_GET}";
#  $f_osm = "$self->{cfgDir}/relations_routes.osm";
  if ( ! -f "$f_osm" or  $self->{DEBUG_GET} > 0 ) {
    $osm = $self->{oOAPI}->get($get);
    open(OSM, ">",  $f_osm) or die "osm_get() erreur:$!";
    print(OSM $osm);
    close(OSM);
  }
}
sub osm_get {
  my $self = shift;
  my ($get, $f_osm) = @_;
  if ( ! $f_osm ) {
    confess "osm_get() f:$f_osm";
  }
  my ($osm);
  warn "osm_get() $f_osm $self->{DEBUG_GET}";
#  $f_osm = "$self->{cfgDir}/relations_routes.osm";
  if ( ! -f "$f_osm" or  $self->{DEBUG_GET} > 0 ) {
    $osm = $self->{oOAPI}->get($get);
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
# transformation de la réponse osm en hash
sub osm2hash {
  my $self = shift;
  my $osm = shift;
#  confess "osm2hash() osm:" . $osm;
  my $hash = XMLin(
    $osm,
    ForceArray    => 1,
    KeyAttr       => [],
    SuppressEmpty => ''
  );
#  warn Dumper($hash);
  if ( defined  $hash->{meta} ) {
    warn "osm2hash() tags meta";
    warn Dumper $hash->{meta};
  }
  foreach my $relation (@{$hash->{relation}}) {
    $hash->{relations}->{$relation->{id}}++;
#    confess Dumper $relation;
    foreach my $tag (@{$relation->{tag}}) {
#     confess Dumper $tag;
      $relation->{tags}->{$tag->{k}} = $tag->{v};
    }
    delete $relation->{tag};
#	confess Dumper $relation->{tags};
#	last;
  }
  foreach my $node (@{$hash->{node}}) {
#    if ( $node->{id} eq '4225380537') {
#      warn "osm_get() " . Dumper $node;
#    }
    foreach my $tag (@{$node->{tag}}) {
      $node->{tags}->{$tag->{k}} = $tag->{v};
    }
    delete $node->{tag};
  }
  foreach my $way (@{$hash->{way}}) {
    foreach my $tag (@{$way->{tag}}) {
      $way->{tags}->{$tag->{k}} = $tag->{v};
    }
    foreach my $nd (@{$way->{nd}}) {
      push @{$way->{nodes}}, $nd->{ref};
    }
    delete $way->{tag};
    delete $way->{nd};
  }
  return $hash;
}
#
# recherche d'un node dans le hash
sub find_node {
  my $self = shift;
  my $id = shift;
  my $hash = shift;
  for my $node ( @{$hash->{node}} ) {
    if ( $id eq $node->{id} ) {
      return $node;
    }
  }
  return undef;
}
sub find_relation {
  my $self = shift;
  my $id = shift;
  my $hash = shift;
  for my $relation ( @{$hash->{relation}} ) {
    if ( $id eq $relation->{id} ) {
      return $relation;
    }
  }
  return undef;
}
sub find_way {
  my $self = shift;
  my $id = shift;
  my $hash = shift;
  for my $way ( @{$hash->{way}} ) {
    if ( $id eq $way->{id} ) {
      return $way;
    }
  }
  return undef;
}
sub osm2bbox {
  my $self = shift;
  my $f_osm = shift;
  open(OSM, $f_osm) or die;
  my $min_lon = +200;
  my $min_lat = +200;
  my $max_lon = -200;
  my $max_lat = -200;
  while (my $ligne = <OSM>) {
	  if ($ligne !~ /^\s*\<node/) {
      next;
    }
   	my ($lon) = ($ligne =~ / lon=[\'\"](.+?)[\'\"]/ ) ;
	 	my ($lat) = ($ligne =~ / lat=[\'\"](.+?)[\'\"]/ ) ;
    if ( $lat > $max_lat ) { $max_lat = $lat};
    if ( $lon > $max_lon ) { $max_lon = $lon};
    if ( $lat < $min_lat ) { $min_lat = $lat};
    if ( $lon < $min_lon ) { $min_lon = $lon};
  }
  close(OSM);
  warn "osm2bbox $min_lon,$max_lat,$max_lon,$min_lat";
}
sub diff_relation_member {
  my $self = shift;
  my ( $r1, $r2 ) = @_;
  my @l1 = split(/\n/, $r1);
  my @l2 = split(/\n/, $r2);
  @l1 = grep(/<member type=.way./, @l1);
  @l2 = grep(/<member type=.way./, @l2);
  s/\D//g for @l1;
  s/\D//g for @l2;

#  if( @l1 ~~ @l2 ) {
  if( array_cpm(\@l1, \@l2) == 0 ) {
    warn "The arrays are the same";
  }

#  warn Dumper \@l1;
#  warn Dumper \@l2;
  my $diff = diff \@l1, \@l2, { STYLE => "Table" };
  warn "diff_relation_member() diff:\n$diff";
  return $diff;
}
sub array_cmp {
  my $l1 = shift;
  my $l2 = shift;
  my @l1 = @{$l1};
  my @l2 = @{$l2};
  if ( scalar(@l1) != scalar(@l2) ) {
    return -1;
  }
  for ( my $i = 0 ; $i < scalar(@l1) ; $i++ ) {
    if ( $l1[$i] ne $l2[$i] ) {
      return -1;
    }
  }
  return 0;
}
1;