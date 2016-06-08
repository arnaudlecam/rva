# <!-- coding: utf-8 -->
#
#
package Rva;
use utf8;
use strict;
use Carp;
use Data::Dumper;
use English;
use XML::Simple;
use OsmMisc;    # quelques fonctions génériques
use OsmApi;     # l'api d'interrogation et de mise à jour
use OsmOapi;    # une api d'interrogation
use OsmDb;      # la base avec les données OSM et gtfs en provenance de la star
use Osm;        # la base avec les données OSM et gtfs en provenance de la star
sub new {
  my( $class, $attr ) = @_;
  my $self = {};
  $self->{cfgDir} = "RVA";
  $self->{varDir} = "D:/web.var/geo/RVA";
  $self->{osm_commentaire} = 'maj Keolis novembre 2014';
#  confess  Dumper $attr;
  bless($self, $class);
  $self->{oAPI} = new OsmApi();
  $self->{oOAPI} = new OsmOapi();
  $self->{oDB} = new OsmDb();
  $self->{oOSM} = new Osm();
  while ( my ($key, $value) = each %{$attr} ) {
    warn "$key:$value";
    $self->{$key} = $value;
    $self->{oOSM}->{$key} = $value;
    $self->{oAPI}->{$key} = $value;
    $self->{oOAPI}->{$key} = $value;
  }
  if ( not defined $self->{'tag_stop'} ) {
    my $network = $self->{network};
    $network =~ s{^fr_}{};
    $self->{tag_stop} = '["ref:' . $network . '"]';
  }
  my $file = "scripts/rva.dmp";
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
  return $self;
}
sub DESTROY {
  my $self = shift;
# un autre DESTROY
  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
  warn "DESTROY()";
  print $self->{log};
}
#
# récupération des données OSM
# ============================
sub oapi_get {
  my $self = shift;
  return $self->{'oOAPI'}->osm_get(@_);
}
#
# transformation d'un fichier csv en hash indexe
sub csv_hash {
  my ( $auto, $i, $j, $k, $cle, $champs, @champs, @valeurs, $fichier, $index, $hash, $decode, $sep, $debug, $filtre );
  if ( @_ < 2 ) {
    croak "csv_hash erreur paramamtres nb:".scalar(@_);
  }
  $decode = '';
  $sep = ',;';
  $debug = 1;
  $filtre = '';
  $fichier = shift;
  $index = shift;
  if ( @_ ) {
    $decode = shift;
  }
  if ( @_ ) {
    $sep = shift;
  }
  if ( @_ ) {
    $debug = shift;
  }
  if ( @_ ) {
    $filtre = shift;
  }
  warn "csv_hash($fichier,$index) debut decode:$decode filtre:$filtre";
  open(F, "< :$decode", $fichier) || croak "csv_hash ouverture fichier:$fichier erreur:$!";
  $champs = <F>;
  $champs =~ s{[\n\r]+$}{};
  $champs =~ s{^[\W]*}{};
# auto-index ?
  $auto = '';
  if ( $index =~ m{^&(.*)} ) {
    $auto = $1;
  } elsif ( $champs !~ /$index/ ) {
    croak "csv_hash() fichier:$fichier index:$index absent champs:$champs";
    return undef;
  }
  warn "csv_hash() auto:$auto";
  @champs = split(/[$sep]/,$champs);
#  confess Dumper @champs;
  $k = -1;
  foreach $i ( 0 .. $#champs ) {
    if ( $champs[$i] eq $index ) {
      $k = $i;
    }
  }
  if ( $auto eq '' ) {
    if ( $k < 0 ) {
      croak "csv_hash() index:$index inconnu champs:$champs";
      return undef;
    }
  }
  while ( <F> ) {
    s{[\n\r]+$}{};
#    if ( $decode ne '' ) {
#      $_ = Encode::encode($decode, $_);
#    }
    if ( $debug && $. > 1320 && $. < 1330 ) {
#      warn "csv_hash() $.:$_";
    }
    next if ( /^\s*$/);
    next if ( /^[\*\#]/ );
    if ( $filtre ne '' ) {
      if ($_ !~ m{$filtre} ) {
        next;
      }
    }
    @valeurs = split(/[$sep]/);
    if ( $#champs ne $#valeurs ) {
      warn "csv_hash() sep:$sep $#champs ne $#valeurs $_";
      exit;
    }
    if ( $auto eq '' ) {
      $cle = $valeurs[$k];
    } else {
      $cle = "$.";
    }
#    warn Dumper \@champs;
#    warn Dumper \@valeurs;
    if ( defined $hash->{$cle} ) {
      if ( $debug ) {
        warn "csv_hash() nouvelle occurence de la cle:$cle ligne:$.";
      }
      next;
    }
#    warn "cle:$cle";
    foreach ( @champs ) {
      $hash->{$cle}->{$_} = shift @valeurs;
    }
#    confess Dumper $hash;
  }
  close(F);
  warn "csv_hash() fin nb:".scalar(keys %{$hash});
  return $hash;
}
1;