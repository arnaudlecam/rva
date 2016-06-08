#
# le fichier en provenance de bano
_sqlite_bano() {
  local table=bano
#  _sqlite_csv2table ${table} ${VarDir}/bano-35.csv UTF-8 ','
  f_csv="d:/web.var/geo/RVA/bano-35.csv"
  cat <<EOFSQL >> /tmp/sql
-- creation de la table
DROP TABLE IF EXISTS ${table};
CREATE TABLE ${table} (
  id TEXT,
  numero TEXT,
  voie TEXT,
  code_post TEXT,
  nom_comm TEXT,
  source TEXT,
  lat TEXT,
  lon TEXT
);
.separator ,
.charset UTF-8
.import ${f_csv} ${table}

ALTER TABLE ${table} ADD COLUMN code_insee text;
UPDATE ${table} SET code_insee = substr(id, 1, 5);

ALTER TABLE ${table} ADD COLUMN fantoir text;
UPDATE ${table} SET fantoir = substr(id, 1, 10);

EOFSQL

}
#
# le fichier rva_adresses en provenance de l'opendata
_sqlite_rva_adresses() {
  local table=rva_adresses
  local f_csv="d:/web.var/geo/RVA/voies_adresses_csv/donnees/rva_adresses.csv"
  _sqlite_csv2table ${table} ${f_csv} UTF-8 ';'
}
_sqlite_rva_voies() {
  local table=rva_voies
  local f_csv="d:/web.var/geo/RVA/voies_adresses_csv/donnees/rva_voies.csv"
  _sqlite_csv2table ${table} ${f_csv} UTF-8 ';'
}
_sqlite_overpass() {
  local table=overpass
  local f_csv="d:/web.var/geo/RVA/osm2csv.csv"
  _sqlite_csv2table ${table} ${f_csv} UTF-8 ';'
  cat <<EOFSQL >> /tmp/sql
ALTER TABLE ${table} ADD COLUMN adresse text;
UPDATE ${table} SET adresse = housenumber || " " || street;
EOFSQL
}
_sqlite_rva_adresses_ext() {
  local table=rva_adresses
# EXTENSION
  cat <<EOFSQL >> /tmp/sql
SELECT DISTINCT EXTENSION
FROM ${table}
;
EOFSQL
}
_sqlite_rva_overpass() {
  local table=rva_overpass
  local table1=rva_adresses
  local table2=overpass
  cat <<EOFSQL >> /tmp/sql
-- creation de la table
DROP TABLE IF EXISTS ${table};
CREATE TABLE ${table} (
  ref TEXT,
  source TEXT,
  insee TEXT,
  adresse TEXT
);
INSERT INTO ${table} (ref, source, insee, adresse )
SELECT ref, "overpass", insee,adresse FROM ${table2}
WHERE ref NOT IN (SELECT ID_ADR FROM ${table1})
;
INSERT INTO ${table} (ref, source, insee, adresse)
SELECT ID_ADR, "rva", CODE_INSEE, ADR_CPLETE FROM ${table1}
WHERE ID_ADR NOT IN (SELECT ref FROM ${table2})
AND CODE_INSEE = '$insee'
;
EOFSQL
  _sqlite_info ${table}
}