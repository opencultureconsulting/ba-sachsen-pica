#!/bin/bash
# Alephino Hauptverarbeitung
# - Datenbereinigungen
# - Mapping auf PICA3
# - PICA3 als CSV (via Template) exportieren

# =============================== ENVIRONMENT ================================ #

# source the main script
source "${BASH_SOURCE%/*}/../bash-refine.sh" || exit 1

# read input
if [[ $1 ]]; then
  inputdir="$(readlink -e "$1")"
else
  echo 1>&2 "Please provide path to directory with input file(s)"; exit 1
fi

# check requirements, set trap, create workdir and tee to logfile
init

# ================================= STARTUP ================================== #

checkpoint "Startup"; echo

# start OpenRefine server
refine_start; echo

# ================================== IMPORT ================================== #

checkpoint "Import"; echo

# TSV-Exporte aller Einzelprojekte in ein Zip-Archiv packen
zip -j "${workdir}/alephino.zip" "${inputdir}"/*.tsv
projects["alephino"]="${workdir}/alephino.zip"

# Neues Projekt erstellen aus Zip-Archiv
p="alephino"
echo "import file" "${projects[$p]}" "..."
if curl -fs --write-out "%{redirect_url}\n" \
  --form project-file="@${projects[$p]}" \
  --form project-name="${p}" \
  --form format="text/line-based/*sv" \
  --form options='{
                   "encoding": "UTF-8",
                   "includeFileSources": "true",
                   "separator": "\t"
                  }' \
  "${endpoint}/command/core/create-project-from-upload$(refine_csrf)" \
  > "${workdir}/${p}.id"
then
  log "imported ${projects[$p]} as ${p}"
else
  error "import of ${projects[$p]} failed!"
fi
refine_store "${p}" "${workdir}/${p}.id" || error "import of ${p} failed!"
echo

# ================================ TRANSFORM ================================= #

checkpoint "Transform"; echo

# ----------------------------- Spalten sortieren ---------------------------- #

# damit Records-Mode erhalten bleibt

echo "Spalten sortieren: Beginnen mit 1. M|001, 2. E|001, 3. File..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-move",
      "columnName": "File",
      "index": 0
    },
    {
      "op": "core/column-move",
      "columnName": "E|001",
      "index": 0
    },
    {
      "op": "core/column-move",
      "columnName": "M|029",
      "index": 0
    },
    {
      "op": "core/column-move",
      "columnName": "M|026f",
      "index": 0
    },
    {
      "op": "core/column-move",
      "columnName": "M|IDN",
      "index": 0
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ------------------------------------ File ---------------------------------- #

echo "Bibliothekskürzel aus Import-Dateiname..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "File",
      "expression": "grel:with([ ['leipzig.tsv','LE'], ['riesa.tsv','RS'] ], mapping, forEach(mapping, m, if(value == m[0], m[1], '')).join(''))",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ------------------------------------ 7100a ---------------------------------- #

# spec_A_E_01
echo "Signatur..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "E|100",
      "expression": "grel:value.split('\u001f')[0].slice(1)",
      "onError": "set-to-blank",
      "newColumnName": "7100a",
      "columnInsertIndex": 5
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ================================== EXPORT ================================== #

checkpoint "Export"; echo

# Export des OpenRefine-Projekts für Tests
format="openrefine.tar.gz"
echo "export ${p} to ${format} file..."
if curl -fs \
  --data project="${projects[$p]}" \
  "${endpoint}/command/core/export-project" \
  > "${workdir}/${p}.${format}"
then
  log "exported ${p} (${projects[$p]}) to ${workdir}/${p}.${format}"
else
  error "export of ${p} (${projects[$p]}) failed!"
fi
echo

# ================================== FINISH ================================== #

checkpoint "Finish"; echo

# stop OpenRefine server
refine_stop; echo

# calculate run time based on checkpoints
checkpoint_stats; echo

# word count on all files in workdir
count_output
