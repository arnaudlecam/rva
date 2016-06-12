#!/bin/bash
# <!-- coding: utf-8 -->
# les données libres de Rennes Métropole
# auteur: Marc Gauthier
#
# http://www.data.rennes-metropole.fr/index.php?id=195
# http://www.geotribu.net/node/267 osm vers svg
  while read f; do
    [ -f $f ] || die "$0 $f"
    . $f
  done <<EOF
../win32/scripts/misc.sh
../win32/scripts/misc_sqlite.sh
../geo/scripts/rva_sqlite.sh
EOF

#f CONF:
CONF() {
  LOG "CONF debut"
  ENV
  CFG=RVA
  [ -d "${CFG}" ] || mkdir "${CFG}"
  VarDir=${DRIVE}/web.var/geo/${CFG}
  [ -d ${VarDir} ] || mkdir -p ${VarDir}
  _ENV_rva_sqlite
  insee=35051; # Cesson-Sévigné
#  insee=35351; # Le Verger
#  insee=35076; # Chavagne
#  insee=35022; # Bécherel
#  insee=35047 ; # Bruz
  insee=35238 ; # Rennes
  LOG "CONF fin"
}
#f _ENV_rva_sqlite: l'environnement spatilite
_ENV_rva_sqlite() {
 [ -f ../win32/scripts/misc_sqlite.sh ] || die "_ENV_rva_sqlite() misc_sqlite"
  _ENV_sqlite
  . ../win32/scripts/misc_sqlite.sh
  db="rva"
  Base=${db}.sqlite
}
#f e:
e() {
  LOG "e debut"
  E 'scripts/rva.sh'
  E  'scripts/rva_sqlite.sh'
  E  'scripts/rva.pl'
  E  'scripts/RvaOsm.pm'
  LOG "e fin"
}
#f _SHP_dl: téléchargement
_SHP_dl() {
  LOG "_SHP_dl debut"
  while read url; do
    if [ "$url" = "#" ] ; then
      break;
    fi
    _b=`basename $url`
    source="${VarDir}/${_b}"
    if [ -f "$source" ] ; then
      arch="${source%.*}_$(date +%Y%m%d -r "${source}").${source##*.}"
      if [ ! -f "$arch" ] ; then
        cp -pv "$source" "$arch"
      fi
    fi
    [ -f "$source" ] || wget -O "$source" $url
  done < /tmp/shp.lst
  ls -lh "${VarDir}"
  LOG "_SHP_dl fin ${VarDir}"
}
#f _SHP_unzip:
_SHP_unzip() {
  LOG "_SHP_unzip debut"
  while read url; do
    _b=`basename $url`
    if [ -f "${VarDir}/${_b}" ] ; then
      "${SEVENZIP}" -y x -o${VarDir} "${VarDir}/${_b}"
#      "${SEVENZIP}" -y e -o${VarDir}/${_b%%.*} "${VarDir}/${_b}"
    fi
  done < /tmp/shp.lst
  ls -1h ${VarDir}
  LOG "_SHP_unzip fin ${VarDir}"
}
# http://metropole.rennes.fr/politiques-publiques/elus-institution-citoyennete/les-communes-de-rennes-metropole/
#
#F RVA_dl: téléchargement des fichiers de l'opendata pour les voies adresses
RVA_dl() {
  LOG "RVA_dl debut"
  wget -O "${Drive}:/web.var/geo/RVA/rva_communes_rm.csv" http://www.data.rennes-metropole.fr/fileadmin/user_upload/data/codes_insee/Codes-Insee-Communes-RennesMetropole-Geolocalisees.csv
  cat <<'EOF' > /tmp/shp.lst
http://www.data.rennes-metropole.fr/fileadmin/user_upload/data/data_sig/referentiels/voies_adresses/voies_adresses_shp_lambcc48.zip
http://www.data.rennes-metropole.fr/fileadmin/user_upload/data/data_sig/referentiels/voies_adresses/voies_adresses_csv.zip
EOF
  _SHP_dl
  _SHP_unzip
  LOG "RVA_dl fin VarDir: $VarDir"
}
#F BANO_dl: téléchargement du fichier bano
BANO_dl() {
  LOG "BANO_dl debut"
  url=http://bano.openstreetmap.fr/data/bano-35.csv
  _b=`basename $url`
  source="${VarDir}/${_b}"
  if [ -f "$source" ] ; then
    arch="${source%.*}_$(date +%Y%m%d -r "${source}").${source##*.}"
    if [ ! -f "$arch" ] ; then
      cp -pv "$source" "$arch"
    fi
  fi
  wget -O "$source" $url
  LOG "BANO_dl fin"
}
#f INSEE_count:
INSEE_count() {
  LOG "INSEE_count debut"
  grep "^${insee}" ${VarDir}/bano-35.csv | wc -l
  grep ";${insee};" ${VarDir}/voies_adresses_csv/donnees/rva_adresses.csv | wc -l
  LOG "INSEE_count fin"
}
#F RM: enchainement des traitements pour les communes de Rennes Métropole
RM() {
  LOG "RM debut"
  tail -n +2 ${VarDir}/rva_communes_rm.csv | \
  while  IFS=";" read insee commune code_postal longitude_radian latitude_radian; do
    echo $insee $commune
    perl scripts/rva.pl --insee ${insee} --DEBUG 1 --DEBUG_GET 1 -- adresses osm_insee
    perl scripts/rva.pl --insee ${insee} --DEBUG 2 --DEBUG_GET 1 -- adresses osm_ref
    perl scripts/rva.pl --insee ${insee} --DEBUG 1 --DEBUG_GET 1 -- adresses osm_cpl
  done
  perl scripts/rva.pl adresses wiki
  perl scripts/rva.pl adresses wiki_update

  LOG "RM fin"
}
#f INC:
INC() {
  LOG "INC debut"
  ls -l ${CFG}/osm_voies_inc_*.csv
  echo "[ -f RVA/${insee}_osm2rva.csv ] || cp ${VarDir}/osm_voies_inc_${insee}.csv RVA/${insee}_osm2rva.csv"
  echo "grep -i "^${insee}.*Sedar" ${VarDir}/voies_adresses_csv/donnees/rva_voies.csv"
  LOG "INC fin"
}
#F GIT: pour mettre à jour le dépot git
GIT() {
  LOG "GIT debut"
  _rva
  ls -1 RVA/35*osm2rva.csv >> /tmp/git.lst
  bash ../win32/scripts/git.sh INIT
  LOG "GIT fin"
}
#f _rva: la liste des fichiers pour le dépot
_rva() {
  Local="${DRIVE}/web/geo";  Depot=rva; Remote=github
  export Local
  export Depot
  export Remote
  cat  <<'EOF' > /tmp/git.lst
scripts/rva.sh
scripts/rva_sqlite.sh
scripts/rva.pl
scripts/Osm.pm
scripts/OsmApi.pm
scripts/OsmOapi.pm
scripts/Rva.pm
scripts/RvaOsm.pm
scripts/RvaWiki.pm
RVA/rva_communes_rm.csv
EOF
  cat  <<'EOF' > /tmp/README.md
# rva : OpenStreetMap et Rennes Métropole Voies Adresses

scripts en environnement Windows 10 : MinGW Strawberry Perl
EOF
}
[ $# -gt 0 ] && ( CONF; $* ; exit )
[ $# -eq 0 ] && HELP