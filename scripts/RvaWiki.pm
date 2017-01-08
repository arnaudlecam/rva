# <!-- coding: utf-8 -->
#
#
package Rva;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use English;
sub wiki {
  my $self = shift;
  my $f_rm = $self->{cfgDir} . "/rva_communes_rm.csv";
  my $rm = csv_hash($f_rm, "code_insee", 'utf8', ";");
  my $wiki = <<'EOF';
==Les communes==
{| class="wikitable"
! code_insee
! commune
! osm
! rva
! ref
! double
! bano
! osm_mod
! osm_inc
! rva_inc
EOF
  my $wiki_osm2rva = <<'EOF';
==Les correspondances osm => rva==

EOF
  for my $insee ( sort keys %$rm ) {
    warn "wiki() $insee";
    my $commune = $rm->{$insee}->{commune};
    my $osm = $self->file_wc($self->{varDir} . "/osm_${insee}.csv");
    my $rva = $self->file_wc($self->{varDir} . "/voies_adresses_csv/donnees/rva_adresses.csv", ";$insee;");
    my $ref = $self->file_wc($self->{varDir} . "/ref_${insee}.csv");
    my $double = $self->file_wc($self->{varDir} . "/double_${insee}.csv");
    my $bano = $self->file_wc($self->{varDir} . "/bano-35.csv", "^$insee");
    my $osm_inc = $self->file_wc($self->{varDir} . "/osm_inc_${insee}.csv");
    my $osm_mod = $self->file_wc($self->{varDir} . "/osm_voies_mod_${insee}.csv");
    my $rva_inc = $self->file_wc($self->{varDir} . "/rva_inc_${insee}.csv");
    $wiki .= <<EOF;
|-
| $insee
| $commune
| $osm
| $rva
| $ref
| $double
| $bano
| $osm_mod
| $osm_inc
| $rva_inc
EOF
    my $f_csv = $self->{cfgDir} . "/${insee}_osm2rva.csv";
    if ( -f $f_csv ) {
      my $osm2rva = csv_hash($f_csv, "osm", 'utf8', ";");
      $wiki_osm2rva .= "\n===$commune===";
      for my $voie ( sort keys %$osm2rva ) {
        $wiki_osm2rva .= "\n* $voie => " . $osm2rva->{$voie}->{rva};
      }
    }
  }
  $wiki .= <<'EOF';
|}
EOF
  my $f_wiki = $self->{cfgDir} . "/rm_suivi.wiki";
  open(WIKI, "> :utf8",  $f_wiki) or die "...() erreur:$! $f_wiki";
  print(WIKI $wiki);
  close(WIKI);
  warn "wiki() f_wiki: $f_wiki";
  $f_wiki = $self->{cfgDir} . "/rm_osm2rva.wiki";
  open(WIKI, "> :utf8",  $f_wiki) or die "...() erreur:$! $f_wiki";
  print(WIKI $wiki_osm2rva);
  close(WIKI);
  warn "wiki() f_wiki: $f_wiki";
}
sub file_wc {
  my $self = shift;
  my $f = shift;
  my $filtre = undef;
  if ( @_ ) {
    $filtre = shift;
  }
  my $nb = 0;
  open(F, "<", $f) or die "file_wc() $f";;
  while(<F>) {
    if ( $filtre && $_ !~ m{$filtre} ) {
      next;
    }
    $nb++;
  }
  close(F);
  if ( ! $filtre ) {
    $nb--;
  }
  return $nb;
}
#
# pour mettre à jour le wiki
our $mech;
sub wiki_update {
  my $self = shift;
  use WWW::Mechanize qw();
  $mech = WWW::Mechanize->new;
  $mech->get('https://wiki.openstreetmap.org/w/index.php?title=Special:UserLogin');
  $mech->submit_form(with_fields => {
    wpName => $self->{config}->{wiki}->{user},
    wpPassword => $self->{config}->{wiki}->{password},
  });
  $self->wiki_update_section("1", "rm_suivi.wiki");
  $self->wiki_update_section("2", "rm_osm2rva.wiki");
}
sub wiki_update_section {
  my $self = shift;
  my ($section, $file) = @_;
  my $f_wiki = $self->{cfgDir} . "/$file";
  open(WIKI, "< :utf8",  $f_wiki) or die "...() erreur:$! $f_wiki";
  my @wiki = <WIKI>;
  close(WIKI);
  my $wiki = join('',@wiki);
  $mech->get("http://wiki.openstreetmap.org/w/index.php?title=Rennes_M%C3%A9tropole/Import_suivi&action=edit&section=$section");
  $mech->success or die " wiki_update() échec page";
  $mech->submit_form(
    with_fields => {
      wpTextbox1   => $wiki,
    },
  );
  warn "wiki_update_section() fin: $f_wiki";
}
1;