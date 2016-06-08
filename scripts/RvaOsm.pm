# <!-- coding: utf-8 -->
#
#
package Rva;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use English;
use Math::Polygon;
#
# récupération des adresses d'une commune
sub osm_insee {
  my $self = shift;
  my $insee = $self->{insee};
  my $hash_node = $self->{oOAPI}->osm_get("area['ref:INSEE'='${insee}']->.boundaryarea;node(area.boundaryarea)['addr:housenumber']['addr:street'];out meta;", "$self->{cfgDir}/node_${insee}.osm");
  my $hash_fantoir = $self->{oOAPI}->osm_get("area['ref:INSEE'='${insee}']->.boundaryarea;way(area.boundaryarea)['ref:FR:FANTOIR'];out meta;", "$self->{cfgDir}/fantoir_${insee}.osm");
  my $hash_way = $self->{oOAPI}->osm_get("area['ref:INSEE'='${insee}']->.boundaryarea;(way(area.boundaryarea)['addr:housenumber']['addr:street'];>);out meta;", "$self->{cfgDir}/way_${insee}.osm");
  my $hash_rel = $self->{oOAPI}->osm_get("area['ref:INSEE'='${insee}']->.boundaryarea;
rel(area.boundaryarea)[type=associatedStreet]->.associatedStreet;
node(r.associatedStreet:'house')->.asHouseNode;
way(r.associatedStreet:'house')->.asHouseWay;
node(w.asHouseWay)->.asHouseWayNode;
(.associatedStreet;.asHouseWay;.asHouseWayNode; .asHouseNode);
out meta;", "$self->{cfgDir}/rel_${insee}.osm");
# indexation des nodes
  my $nodes;
  for my $node ( (@{$hash_rel->{'node'}}, @{$hash_way->{'node'}})  ) {
    $nodes->{$node->{id}} = $node;
    $nodes->{$node->{id}}->{type} = 'node';
  }
#  confess Dumper $nodes->{'4225380537'};
  my $ways;
  for my $way ( (@{$hash_rel->{'way'}}, @{$hash_way->{'way'}}) ) {
# calcul du centroïde/barycentre
    my @p = ();
    my ($lon, $lat, $nb);
    for my $n ( @{$way->{nodes}} ) {
      my $node = $nodes->{$n};
#      warn Dumper $n;
      push @p, [ $node->{lon}, $node->{lat} ];
      $lon += $node->{lon};
      $lat += $node->{lat};
      $nb++;
    }
    $lon = $lon / $nb;
    $lat = $lat / $nb;
    $way->{lon} = sprintf("%0.6f", $lon);
    $way->{lat} = sprintf("%0.6f", $lat);
#    confess Dumper \@p;
#*
#    my ( $p, $rc );
#    eval {
#      $p = Math::Polygon->new(points => \@p);
#      $rc = $p->centroid();
#    } or do {
#      warn Dumper $way;
#      next;
#    };
#    $way->{lon} = sprintf("%0.6f", $rc->[0]);
#    $way->{lat} = sprintf("%0.6f", $rc->[1]);
    $ways->{$way->{id}} = $way;
    $ways->{$way->{id}}->{type} = 'way';
  }

  my $csv;
  my $type = 'node';
  $csv .= sprintf("%s;%s;%s;%s;%s;%s;%s;%s", 'id', 'type', 'lon', 'lat', 'insee', 'street', 'housenumber', 'ref');

  for my $node ( @{$hash_node->{'node'}} ) {
#    if ( $node->{id} eq '4225380537') {
#      warn "osm_i() " . Dumper $node;
#    }
    $csv .= sprintf("\n%s;%s;%s;%s;%s;%s;%s;%s", $node->{id}, $type, $node->{lon}, $node->{lat}, $insee, $node->{tags}->{'addr:street'}, $node->{tags}->{'addr:housenumber'}, $node->{tags}->{'source:addr:housenumber:ref'});
  }
  my $type = 'way';
  for my $way ( @{$hash_way->{'way'}} ) {
#    warn Dumper $way;
    $csv .= sprintf("\n%s;%s;%s;%s;%s;%s;%s;%s", $way->{id}, $type, $way->{lon}, $way->{lat}, $insee, $way->{tags}->{'addr:street'}, $way->{tags}->{'addr:housenumber'}, $way->{tags}->{'source:addr:housenumber:ref'});
  }
  for my $relation ( @{$hash_rel->{'relation'}} ) {
#    warn Dumper $relation;
    my $name =  $relation->{tags}->{'name'};
    for my $member ( @{$relation->{member}} ) {
      if ( $member->{role} ne 'house' ) {
        next;
      }
      my $n = $member->{ref};
      my $node = '';
      if ( $member->{type} eq 'node' ) {
        $node = $nodes->{$n};
      }
      if ( $member->{type} eq 'way' ) {
        $node = $ways->{$n};
      }
      if ( $node eq '' ) {
        next;
      }
      if ( defined $node->{tags}->{'addr:street'} ) {
        $name = $node->{tags}->{'addr:street'};
      }
      $csv .= sprintf("\n%s;%s;%s;%s;%s;%s;%s;%s", $n, $node->{type}, $node->{lon}, $node->{lat}, $insee, $name, $node->{tags}->{'addr:housenumber'}, $node->{tags}->{'source:addr:housenumber:ref'});
    }
  }
  my $f_csv = $self->{varDir} . "/osm_${insee}.csv";
  open(CSV, "> :utf8",  $f_csv) or die "...() erreur:$! $f_csv";
  print(CSV $csv);
  close(CSV);
  warn "osm_insee() $f_csv";
  $csv = "name;fantoir";
  for my $way ( @{$hash_fantoir->{'way'}} ) {
    $csv .= sprintf("\n%s;%s", $way->{tags}->{'name'}, $way->{tags}->{'ref:FR:FANTOIR'});
  }
  $f_csv = $self->{varDir} . "/fantoir_${insee}.csv";
  open(CSV, "> :utf8",  $f_csv) or die "...() erreur:$! $f_csv";
  print(CSV $csv);
  close(CSV);
  warn "osm_insee() $f_csv";
}
#
# récupération des adresses de Rennes Métropole
sub osm_ref {
  my $self = shift;
  warn "osm_ref()";
  my $insee = $self->{insee};
  my $hash = $self->{oOAPI}->osm_get("area['ref:INSEE'='$insee']->.boundaryarea;
(node(area.boundaryarea)['source:addr:housenumber:ref'];way(area.boundaryarea)['source:addr:housenumber:ref']);
out meta;", "$self->{cfgDir}/osm_ref.osm");
  my ($csv, $type, $refs);
  my $type = 'node';
  $csv .= sprintf("%s;%s;%s;%s;%s;%s;%s;%s", 'id', 'type', 'lon', 'lat', 'city', 'street', 'housenumber', 'ref');
  my $level0 = '';
  my $double = "ref1,ref2";
  for my $node ( @{$hash->{'node'}} ) {
    $node->{type} = 'n';
    my $ref = $node->{tags}->{'source:addr:housenumber:ref'};
    if ( $ref !~ m{^\d+$} ) {
#      warn Dumper $node;
      $level0 .= "n$node->{id},";
      next;
    }
    if ( defined $refs->{$ref} ) {
      if ( $self->{DEBUG} > 1 ) {
        warn Dumper $node;
        warn Dumper $refs->{$ref};
      }
      $level0 .= "n$node->{id},";
      $double .= "\n$node->{type}$node->{id},$refs->{$ref}->{type}$refs->{$ref}->{id}";
      next;
    }
    $refs->{$ref} = $node;
    $csv .= sprintf("\n%s;%s;%s;%s;%s;%s;%s;%s", $node->{id}, $type, $node->{lon}, $node->{lat}, $node->{tags}->{'addr:city'}, $node->{tags}->{'addr:street'}, $node->{tags}->{'addr:housenumber'}, $node->{tags}->{'source:addr:housenumber:ref'});
  }
  $type = 'way';
  for my $way ( @{$hash->{'way'}} ) {
    $way->{type} = 'w';
    my $ref = $way->{tags}->{'source:addr:housenumber:ref'};
    if ( $ref !~ m{^\d+$} ) {
#      warn Dumper $way;
      $level0 .= "w$way->{id},";
      next;
    }
   if ( defined $refs->{$ref} ) {
      if ( $self->{DEBUG} > 1 ) {
        warn Dumper $way;
        warn Dumper $refs->{$ref};
      }
      $level0 .= "w$way->{id},";
      $double .= "\n$way->{type}$way->{id};$refs->{$ref}->{type}$refs->{$ref}->{id}";
      next;
    }
    $csv .= sprintf("\n%s;%s;%s;%s;%s;%s;%s;%s", $way->{id}, $type, $way->{lon}, $way->{lat}, $way->{tags}->{'addr:city'}, $way->{tags}->{'addr:street'}, $way->{tags}->{'addr:housenumber'}, $way->{tags}->{'source:addr:housenumber:ref'});
  }
  warn "osm_ref() level0: $level0";
  my $f_csv = $self->{varDir} . "/ref_${insee}.csv";
  open(CSV, "> :utf8",  $f_csv) or die "...() erreur:$! $f_csv";
  print(CSV $csv);
  close(CSV);
  warn "osm_ref() *** $f_csv";
  my $f_double = $self->{varDir} . "/double_${insee}.csv";
  open(DOUBLE, "> :utf8",  $f_double) or die "...() erreur:$! $f_double";
  print(DOUBLE $double);
  close(DOUBLE);
  warn "osm_ref() fin $f_double";
}
#
# déduplication des points adresses de Rennes Métropole
sub osm_double {
  my $self = shift;
  warn "osm_double()";
  my $insee = $self->{insee};
  my $rva = csv_hash($self->{varDir} . "/voies_adresses_csv/donnees/rva_adresses.csv", "ID_ADR", 'utf8', ";", 0, ";${insee};");
  my $f_double = $self->{varDir} . "/double_${insee}.csv";
  open(DOUBLE, "< :utf8",  $f_double) or die "...() erreur:$! $f_double";
  my $types = {n => 'node', w => 'way', r => 'relation' };
  my $osm_delete = '';
  while (my $ligne = <DOUBLE> ) {
    if ( $self->{DEBUG} > 1 ) {
      if ( $. > 10 ) {
        last;
      }
    }
    chomp $ligne;
    my ($type1, $id1, $type2, $id2) = ( $ligne =~ m{^(\w)(\d+),(\w)(\d+)$} );
    if ( ! $id1 ) {
      next;
    }
    $type1 = $types->{$type1};
    $type2 = $types->{$type2};
    warn "$type1, $id1, $type2, $id2";
    if ( $type1 ne $type2 ) {
      warn "osm_double() # type $type1 $type2 $ligne";
      next;
    }
    if ( $type1 ne "node" ) {
      warn "osm_double() # type $type1 $ligne";
      next;
    }
    if ( $id1 > $id2 ) {
      my $temp = $id1; $id1 = $id2; $id2 = $temp;
      my $temp = $type1; $type1 = $type2; $type2 = $temp;
    }
    my $osm1 = $self->{oAPI}->get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", $type1, $id1));
    my $osm2 = $self->{oAPI}->get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", $type2, $id2));
    if ( $self->{DEBUG} > 1 ) {
      warn $osm1;
      warn $osm2;
    }
    my $hash1 = $self->{oAPI}->osm2hash($osm1);
    my $hash2 = $self->{oAPI}->osm2hash($osm2);
     if ( $self->{DEBUG} > 3 ) {
      warn Dumper $hash1;
    }
    if ( $osm1 =~ m{user="blue_prawn_script"}sm ) {
      $osm_delete .= $self->{oOSM}->node_delete($hash1->{node}[0]);
      next;
    }
    my $ref = $hash1->{node}[0]->{tags}->{"source:addr:housenumber:ref"};
#    confess Dumper $rva->{$ref};
    my $X_WGS84 = $rva->{$ref}->{'X_WGS84'};
    my $Y_WGS84 = $rva->{$ref}->{'Y_WGS84'};
    $X_WGS84 =~ s{,}{.};
    $Y_WGS84 =~ s{,}{.};
    my $d1 =  haversine_distance_meters($hash1->{node}[0]->{lat}, $hash1->{node}[0]->{lon}, $Y_WGS84, $X_WGS84);
    my $d2 =  haversine_distance_meters($hash2->{node}[0]->{lat}, $hash2->{node}[0]->{lon}, $Y_WGS84, $X_WGS84);
    warn "osm_double() ref:$ref d1:$d1 d2:$d2";
#     confess Dumper $hash1;
#    last;
  }
  close(DOUBLE);
  $self->{oAPI}->changeset($osm_delete, "point adresse en double ou sans addr:street", 'delete');
  warn "osm_double() fin $f_double";
}
#
# pour compléter les adresses d'une commune
#
our ($commune, $code_postal, $rm, $rva_voies, $rva_voies_noms, $osm_fantoir, $rva_fantoir);
our $osm__rva;
our %voies; # les voies sans ref
sub osm_cpl {
  my $self = shift;
  warn "osm_cpl()";
  my $insee = $self->{insee};
  warn "osm_cpl() --$insee--";
  my $f_rm = $self->{varDir} . "/rva_communes_rm.csv";
  $rm = csv_hash($f_rm, "code_insee", 'utf8', ";");
  $commune = $rm->{$insee}->{commune};
  $code_postal = $rm->{$insee}->{code_postal};
  $osm_fantoir = csv_hash( $self->{varDir} . "/fantoir_${insee}.csv", "name", 'utf8', ";", 0);
  my @k =  keys %{$osm_fantoir};
  for my $id ( @k ) {
    my $fantoir = chop $id;
    $osm_fantoir->{$fantoir} = $osm_fantoir->{$id};
  }
#  confess Dumper $rm;
  $rva_voies = csv_hash($self->{varDir} . "/voies_adresses_csv/donnees/rva_voies.csv", "ID_VOIE", 'utf8', ";", 0, "^${insee};");
  $rva_voies_noms = csv_hash($self->{varDir} . "/voies_adresses_csv/donnees/rva_voies.csv", "VOIE_NOM_COMPLET", 'utf8', ";", 0, "^${insee};");
  for my $id ( keys %{$rva_voies} ) {
#    confess Dumper $rva_voies->{$id};
    my $fantoir = $rva_voies->{$id}->{CODE_INSEE} . $rva_voies->{$id}->{FANTOIR};
    $rva_fantoir->{$fantoir} = $rva_voies->{$id}->{VOIE_NOM_COMPLET};
  }
#  confess Dumper $rva_fantoir;
  my $f_rva = $self->{varDir} . "/voies_adresses_csv/donnees/rva_adresses.csv";
  my ($rva, $rva_id, $osm_ref);
  open(RVA, "< :utf8",  $f_rva) or die "...() erreur:$! $f_rva";
  while ( my $ligne = <RVA> ) {
    chomp $ligne;
    my ($ID_ADR, $NUMERO, $EXTENSION, $BATIMENT, $ANGLE_GRD, $ANGLE_DEG, $CODE_INSEE, $ID_VOIE, $VOIE_NOM, $ADR_CPLETE, $X_LAMBCC48, $Y_LAMBCC48, $X_LAMB93, $Y_LAMB93, $X_WGS84, $Y_WGS84) = split(";", $ligne);
#    confess "$ID_ADR, $NUMERO, $EXTENSION, $BATIMENT, $ANGLE_GRD, $ANGLE_DEG, $CODE_INSEE, $ID_VOIE, $VOIE_NOM, $ADR_CPLETE, $X_LAMBCC48, $Y_LAMBCC48, $X_LAMB93, $Y_LAMB93, $X_WGS84, $Y_WGS84";
    if ( $CODE_INSEE !~ m{$insee} ) {
      next;
    }
    if ( $Y_WGS84 !~ m{^4} ) {
      next;
    }
    $rva_id->{$ID_ADR} = $ligne;
    $rva->{$ADR_CPLETE} = $ligne;
  }
  close(RVA);
  warn "osm_cpl() nb_rva:" . scalar(keys %{$rva});
  my $tags = {
    "source:addr" => "Rennes Métropole",
    "source:addr:housenumber:ref" => "",
    "source:addr:version" =>"2016-04-01",
    "addr:city" => $commune,
    "addr:postcode"=> "35510"
  };
  my $osm = '';
  my $nodes;
  my $modify;
  my $nb_modify = 0;
  my $level0 = '';
  my ($osm_inc, $rva_inc);
  my $f_csv = $self->{varDir} . "/osm_${insee}.csv";
  open(CSV, "< :utf8",  $f_csv) or die "...() erreur:$! $f_csv";
  $osm_inc = <CSV>;
  while ( my $ligne = <CSV> ) {
    chomp $ligne;
    my ($id, $type, $lon, $lat, $city, $street, $housenumber, $ref ) = split(";", $ligne);
    if ( $id !~ m{^\d} ) {
      next;
    }
    if ( $street =~ m{^\s*$} ) {
      next;
    }
# déjà référencé ?
    if ( $ref =~ m{^\d+$} ) {
      $osm_ref->{$ref} = $id;
      next;
    }
# on mémorise
    $nodes->{"$type/$id"} = {
      lon => $lon,
      lat => $lat,
      ref => $ref,
      ligne => $ligne
    };
# on rapproche sur la voie
    my $voie = $street;
    if ( not defined $rva_voies_noms->{$voie} ) {
      $voie = $self->voie_osm2rva($voie);
    }
    if ( not defined $rva_voies_noms->{$voie} ) {
#      $voie =~ s{É}{E}g;;
    }
    if ( not defined $rva_voies_noms->{$voie} ) {
      $osm_inc .= "$ligne\n";
      $voies{$street}->{nb}++;
      $voies{$street}->{rva}++;
      push @{$voies{$street}->{numeros}}, $housenumber;
      my $l = substr($type,0,1) . $id . ',';
      $l = "http://www.openstreetmap.org/edit?editor=id&$type=$id ";
      $voies{$street}->{level0} .= $l;
      if ( $street =~ m{^[a-z]} ) {
        $level0 .= $l;
      }
      next;
    }
# on rapproche sur le numéro
    my $numero = $housenumber;
    my $adr = "$numero $voie";
    if ( ! defined $rva->{$adr} ) {
      if ( $numero =~ m{^(\d+)([a-z]+)$}i ) {
        $numero = "$1 $2";
        $adr = "$numero $voie";
      }
    }
# on est en échec
    if ( ! defined $rva->{$adr} ) {
      if ( $street =~ m{chal Joffre} ) {
        warn "$street $adr";
      }
      $osm_inc .= "$ligne\n";
      $voies{$street}->{nb}++;
      push @{$voies{$street}->{numeros}}, $housenumber;
      if ( $self->{DEBUG} > 1 ) {
        warn $ligne;
        warn  "\t$rva_id->{$ref}";
        warn  "\tadr:$adr";
      }
#    confess Dumper $rva;;
      next;
    }
#      warn "$type $id => " . $rva->{$adr};
    my ($ID_ADR, $NUMERO, $EXTENSION, $BATIMENT, $ANGLE_GRD, $ANGLE_DEG, $CODE_INSEE, $ID_VOIE, $VOIE_NOM, $ADR_CPLETE, $X_LAMBCC48, $Y_LAMBCC48, $X_LAMB93, $Y_LAMB93, $X_WGS84, $Y_WGS84) = split(";", $rva->{$adr});
    if ( $ID_ADR !~ m{^\d+$} ) {
      confess;
    }
    undef $rva->{$adr};
    if ( $ref =~ m{\d+} ) {
      next;
    }
#      next;
    $tags->{"source:addr:housenumber:ref"} = $ID_ADR;
#      next;
    if ( defined $modify->{"$type/$id"} ) {
      next;
    }
    $modify->{"$type/$id"}++;
    if ( $self->{DEBUG} == 0 ) {
      my $type_osm = $self->{oAPI}->get(sprintf("http://api.openstreetmap.org/api/0.6/%s/%s", $type, $id));
      $osm .= $self->{oOSM}->modify_tags($type_osm, $tags, qw(source:addr source:addr:version source:addr:housenumber:ref addr:city)) . "\n";
    }
    $nb_modify++;
    if ( $nb_modify%1000 == 0 ) {
      $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' ajout des tags data.rennes-metropole.fr' , 'modify');
      $osm = '';
#        exit;
    }
#    last;
  }
  close(CSV);
  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' ajout des tags data.rennes-metropole.fr' , 'modify');
  warn "osm_cpl() nb_osm_ref: " . scalar(keys %{$osm_ref});
  warn "osm_cpl() nb_modify: $nb_modify";
  my $osm_voies_inc = "voie;nb";
  foreach my $voie (sort { $voies{$a}->{rva} <=> $voies{$b}->{rva} } keys %voies) {
#    printf "%-40s %4d %4d %s\n", $voie, $voies{$voie}->{nb}, $voies{$voie}->{rva}, join(",", @{$voies{$voie}->{numeros}});
    printf("%-40s %4d %4d %s\n", $voie, $voies{$voie}->{nb}, $voies{$voie}->{rva}, $voies{$voie}->{level0});
    if ( $voies{$voie}->{rva} > 0 ) {
      $osm_voies_inc .= sprintf("\n%s;%s", $voie, $voies{$voie}->{rva});
    }
  }
  my $f_inc = $self->{varDir} . "/osm_voies_inc_${insee}.csv";
  open(INC, "> :utf8",  $f_inc) or die "...() erreur:$! $f_inc";
  print(INC $osm_voies_inc);
  close(INC);
  warn "osm_ref() fin $f_inc";
  chomp $osm_inc;
  $f_inc = $self->{varDir} . "/osm_inc_${insee}.csv";
  open(INC, "> :utf8",  $f_inc) or die "...() erreur:$! $f_inc";
  print(INC $osm_inc);
  close(INC);
  warn "osm_ref() fin $f_inc";
# l'utilisation du fantoir
  while ( my ($key, $value) = each(%$osm__rva) ) {
    if ( $key ne $value ) {
#      print "$key;$value\n";
    }
  }
  print $level0;
#  exit;
#
# la partie création des nouveaux points adresse
  $osm = '';
  my $nb_create = 0;
  $rva_inc = "ID_ADR;NUMERO;EXTENSION;BATIMENT;ANGLE_GRD;ANGLE_DEG;CODE_INSEE;ID_VOIE;VOIE_NOM;ADR_CPLETE;X_LAMBCC48;Y_LAMBCC48;X_LAMB93;Y_LAMB93;X_WGS84;Y_WGS84\n";
  for my $ref ( keys %{$rva_id} ) {
    if ( ! defined $rva_id->{$ref} ) {
      next;
    }
    if ( defined $osm_ref->{$ref} ) {
      next;
    }
    my $ligne = $rva_id->{$ref};

    my ($ID_ADR, $NUMERO, $EXTENSION, $BATIMENT, $ANGLE_GRD, $ANGLE_DEG, $CODE_INSEE, $ID_VOIE, $VOIE_NOM, $ADR_CPLETE, $X_LAMBCC48, $Y_LAMBCC48, $X_LAMB93, $Y_LAMB93, $X_WGS84, $Y_WGS84) = split(";", $ligne);
    if ( $ID_ADR !~ m{^\d+$} ) {
      confess;
    }
# on est très proche d'une autre adresse ?
    $X_WGS84 =~ s{,}{.};
    $Y_WGS84 =~ s{,}{.};
    my $ko = 0;
    for my $node ( keys %{$nodes} ) {
      if ( $nodes->{$node}->{ref} =~ m{^\d+$} ) {
        next;
      }
      my $d =  haversine_distance_meters($nodes->{$node}->{lat}, $nodes->{$node}->{lon}, $Y_WGS84, $X_WGS84);
      if ( $d < 10 ) {
        $ko++;
        if ( $self->{DEBUG} > 1 ) {
          warn "$nodes->{$node}->{lat}, $nodes->{$node}->{lon}, $Y_WGS84, $X_WGS84, $d";
          warn $ligne;
          warn  $nodes->{$node}->{ligne};
        }
      }
    }
    if ( $ko > 0 ) {
      $rva_inc .= "$ligne\n";
      next;
    }
    $osm .= $self->node_rva($ligne) . "\n";
    $nb_create++;
    if ( $nb_create%2000 == 0 ) {
      $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' ajout des adresses de data.rennes-metropole.fr' , 'create');
      $osm = '';
    }
  }
#  warn $osm;

  $self->{oAPI}->changeset($osm, $self->{osm_commentaire} . ' ajout des adresses de data.rennes-metropole.fr' , 'create');
  warn "osm_cpl() nb_create: $nb_create";
  chomp $rva_inc;
  my $f_inc = $self->{varDir} . "/rva_inc_${insee}.csv";
  open(INC, "> :utf8",  $f_inc) or die "...() erreur:$! $f_inc";
  print(INC $rva_inc);
  close(INC);
  warn "osm_ref() fin $f_inc";
}
#
# création du noeud point adresse
sub node_rva {
  my $self = shift;
  my $ligne = shift;
  my $insee = $self->{insee};
  my ($ID_ADR, $NUMERO, $EXTENSION, $BATIMENT, $ANGLE_GRD, $ANGLE_DEG, $CODE_INSEE, $ID_VOIE, $VOIE_NOM, $ADR_CPLETE, $X_LAMBCC48, $Y_LAMBCC48, $X_LAMB93, $Y_LAMB93, $X_WGS84, $Y_WGS84) = split(";", $ligne);
  my $voie = $VOIE_NOM;
  $voie = $self->voie_rva2osm($voie);
  $X_WGS84 =~ s{,}{.};
  $Y_WGS84 =~ s{,}{.};
  $self->{node_id}--;
  my $numero = "$NUMERO $EXTENSION";
  $numero =~ s{\s*$}{};

  my $osm = <<EOF;
  <node id="$self->{node_id}" lat="$Y_WGS84" lon="$X_WGS84" timestamp="0" changeset="1" version="1">
    <tag k="addr:housenumber" v="$numero"/>
    <tag k="addr:street" v="$VOIE_NOM"/>
    <tag k="addr:city" v="$commune"/>
    <tag k="addr:postcode" v="$code_postal"/>
    <tag k="source:addr" v="Rennes Métropole"/>
    <tag k="source:addr:housenumber:ref" v="$ID_ADR"/>
    <tag k="source:addr:version" v="2016-04-01"/>
  </node>
EOF
  return $osm;
}
#
# calcul de la distance entre 2 points en mètre
sub haversine_distance_meters {
  my $O = 3.141592654/180 ;
  my $lat1 = shift(@_) * $O;
  my $lon1 = shift(@_) * $O;
  my $lat2 = shift(@_) * $O;
  my $lon2 = shift(@_) * $O;
  my $dlat = $lat1 - $lat2;
  my $dlon = $lon1 - $lon2;
  my $f = 2 * &asin( sqrt( (sin($dlat/2) ** 2) + cos($lat1) * cos($lat2) * (sin($dlon/2) ** 2)));
  return sprintf("%d",$f * 6378137) ; 		# Return meters
  sub asin {
   atan2($_[0], sqrt(1 - $_[0] * $_[0])) ;
  }
}
#
# rapprochement des voies osm avec les voies rva
# le code fantoir peut aider !
our $osm2rva;
sub voie_osm2rva {
  my $self = shift;
  my $insee = $self->{insee};
  my ( $voie) = @_;
  if ( ! $osm2rva ) {
    my $f_csv = $self->{cfgDir} . "/${insee}_osm2rva.csv";
    if ( -f $f_csv ) {
      $osm2rva = csv_hash($f_csv, "osm", 'utf8', ";", 1);
    } else {
      $osm2rva = {};
    }
    for my $k ( keys %{$osm2rva} ) {
      my $v = $osm2rva->{$k}->{rva};
      if ( not defined $rva_voies_noms->{$v} ) {
        warn "adr_osm2rva() $k;$v";
#        warn Dumper $rva_voies_noms;
        confess "la voie n'existe pas dans la commune";
        return $voie;
      }
    }
  }
  if ( defined $osm_fantoir->{$voie} ) {
#    warn Dumper $osm_fantoir->{$voie};
    my $fantoir = $osm_fantoir->{$voie}->{fantoir};
    chop $fantoir;
    if ( defined $rva_fantoir->{$fantoir} ) {
#      warn Dumper $rva_fantoir->{$fantoir};
      $osm__rva->{$voie} = $rva_fantoir->{$fantoir};
      $voie = $rva_fantoir->{$fantoir};
    }
  }
  if ( defined $osm2rva->{$voie} ) {
    $voie = $osm2rva->{$voie}->{rva};
    $voies{$voie}->{rva} = 0;
  }
  return $voie;
}
our $rva2osm;
sub voie_rva2osm {
  my $self = shift;
  my $insee = $self->{insee};
  my ( $voie) = @_;
  if ( ! $rva2osm ) {
    my $f_csv = $self->{cfgDir} . "/${insee}_rva2osm.csv";
    if ( -f $f_csv ) {
      $rva2osm = csv_hash($f_csv, "osm", 'utf8', ";", 1);
    } else {
      $rva2osm = {};
    }
  }
  if ( defined $rva2osm->{$voie} ) {
    $voie = $rva2osm->{$voie}->{osm};
  }
  return $voie;
}

1;