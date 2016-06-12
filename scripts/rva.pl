#!/usr/bin/perl
# <!-- coding: utf-8 -->
# rva.pl
# auteur: Marc GAUTHIER
# licence : Paternité - Pas d’Utilisation Commerciale 2.0 France (CC BY-NC 2.0 FR)
# m.starbusmetro.fr
# http://wiki.openstreetmap.org/wiki/OSM_History_Viewer
# https://osm.athemis.de/
# http://www.predim.org/IMG/pdf/notices-donnees-v1.1.pdf
#
# quelques usages
# la mise à jour des arrêts
# perl scripts/rva.pl  bus_stop diff_bus_stop
# la validation d'une relation route : arrêts versus gtfs
# perl scripts/rva.pl --ref=33 route diff_route
# la validation des relations route_master
# perl scripts/rva.pl route_master valid_routes_master 2> toto
# la validation de la relation network
#  perl scripts/rva.pl  -d network valid_network
use strict;
use warnings;
use Carp;
use utf8;
use Data::Dumper;
use English;
use Cwd;
use LWP::Simple;
use LWP::Debug qw(+);
# use XML::Twig;
use XML::Simple;
use Getopt::Long;
use lib "scripts";


use Rva;
use RvaOsm;
use RvaWiki;
use RvaBano;
our $cfgDir = 'RVA';
our $baseDir = getcwd;
our $Drive = substr($baseDir,0,2);
our $varDir = "$Drive/web.var/geo/${cfgDir}";
  $baseDir =~ s{/scripts}{};
  chdir($baseDir);
  select (STDERR);$|=1;
  select (STDOUT);$|=1;
  binmode STDOUT, ":utf8";  # assuming your terminal is UTF-8
  binmode STDERR, ":utf8";  # assuming your terminal is UTF-8
  if ( ! -d "$cfgDir" ) {
    mkdir("$cfgDir");
  }
  if ( ! -d "$varDir" ) {
    mkdir("$varDir");
  }
  our( $sp, $ssp, $insee, $DEBUG, $DEBUG_GET );
  $sp = 'aide';
  $insee = '35051';
  $DEBUG = 1;  $DEBUG_GET = 1;
#  $DEBUG = 0;  $DEBUG_GET = 0;
# pour le mode ligne de commandes (cli)
  GetOptions(
    'insee=s' => \$insee,
    'debug|d' => \$DEBUG,
    'DEBUG=s' => \$DEBUG,
    'DEBUG_GET=s' => \$DEBUG_GET,
    'g' => \$DEBUG_GET
  );
  $sp = shift if ( @ARGV );

  warn "$0 $] sp:$sp DEBUG:$DEBUG DEBUG_GET:$DEBUG_GET insee:$insee";
  my $sub = UNIVERSAL::can('main',"$sp");
  if ( defined $sub ) {
    &$sub(@ARGV);
  } else {
    warn "main sp:$sp inconnu";
  }
  warn "$0 $] fin";
  exit 0;
sub aide {
  help();
}
sub help {
  print <<'EOF';
perl scripts/rva.pl --DEBUG 1 --DEBUG_GET 1 --insee  35278 adresses osm_insee
EOF

}
sub adresses {
  my $oRva = new Rva(&_adresses);
  $sp = 'osm2csv';
  if ( @_ ) {
    $sp = shift @_;
  } else {
    $sp = $ssp;
  }
  $oRva->$sp(@_);
}
sub _adresses {
  my $self = {
    DEBUG => $DEBUG,
    DEBUG_GET => $DEBUG_GET,
    insee => "$insee",
    cfgDir => "RVA",
    source => "data.rennes-metropole.fr - Année 2016",
    osm_commentaire => 'maj juin 2016',
  };
  return $self;
}


