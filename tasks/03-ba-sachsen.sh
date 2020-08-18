#!/bin/bash
# Generierung PICA+
# - PPNs anreichern und Exemplare clustern
# - als PICA+ exportieren

# =============================== ENVIRONMENT ================================ #

# source the main script
source "${BASH_SOURCE%/*}/../bash-refine.sh" || exit 1

# read input
if [[ $1 ]]; then
  inputdir1="$(readlink -e "$1")"
else
  echo 1>&2 "Please provide path to directory with input file(s)"; exit 1
fi
#if [[ $2 ]]; then
#  inputdir2="$(readlink -e "$2")"
#fi

# check requirements, set trap, create workdir and tee to logfile
init

# ================================= STARTUP ================================== #

checkpoint "Startup"; echo

# start OpenRefine server
refine_start; echo

# ================================== IMPORT ================================== #

checkpoint "Import"; echo

# TODO: Zusammenführung mit Alephino
zip -j "${workdir}/ba-sachsen.zip" "${inputdir1}"/*.csv
projects["ba-sachsen"]="${workdir}/ba-sachsen.zip"

# Neues Projekt erstellen aus Zip-Archiv
p="ba-sachsen"
echo "import file" "${projects[$p]}" "..."
if curl -fs --write-out "%{redirect_url}\n" \
  --form project-file="@${projects[$p]}" \
  --form project-name="${p}" \
  --form format="text/line-based/*sv" \
  --form options='{
                   "encoding": "UTF-8",
                   "includeFileSources": "false",
                   "separator": ","
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

# ---------------------------- Titel ohne Exemplare -------------------------- #

# TODO: Temporäres Löschen durch Generierung von Lax-Sätzen ersetzen
echo "Titel ohne Exemplare löschen..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "2199",
            "expression": "isBlank(value)",
            "columnName": "2199",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": false,
                  "l": "false"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "7100f",
            "expression": "isBlank(value)",
            "columnName": "7100f",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": true,
                  "l": "true"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      }
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# -------------------------- PPN anreichern über ISBN ------------------------ #

# TODO: Anreicherung für 0110
# spec_Z_04
echo "PPN anreichern über ISBN..."
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
      "baseColumnName": "2000",
      "expression": "grel:with(value.replace('-',''),x,forEach(x.split('␟'),v,if(v.length()==10,with('978'+x[0,9],z,z+((10-(sum(forRange(0,12,1,i,toNumber(z[i])*(1+(i%2*2)) )) %10)) %10).toString()[0] ),v))).uniques().join('␟')",
      "onError": "set-to-blank",
      "newColumnName": "tmp",
      "columnInsertIndex": 3
    },
    {
      "op": "core/column-split",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "tmp",
      "guessCellType": false,
      "removeOriginalColumn": true,
      "mode": "separator",
      "separator": "␟",
      "regex": false,
      "maxColumns": 0
    },
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "2199",
            "expression": "isBlank(value)",
            "columnName": "2199",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": false,
                  "l": "false"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "0100",
            "expression": "isBlank(value)",
            "columnName": "0100",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": true,
                  "l": "true"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "tmp 1",
      "expression": "grel:with(forEach(value.cross('ba-sachsen','tmp 1'),r,forNonBlank(r.cells['0100'].value,v,v,null)).join('␟') + '␟' + forEach(value.cross('ba-sachsen','tmp 2'),r,forNonBlank(r.cells['0100'].value,v,v,null)).join('␟'),x,x.split('␟')[0])",
      "onError": "set-to-blank",
      "newColumnName": "tmp 1_0100",
      "columnInsertIndex": 4
    },
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "2199",
            "expression": "isBlank(value)",
            "columnName": "2199",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": false,
                  "l": "false"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "0100",
            "expression": "isBlank(value)",
            "columnName": "0100",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": true,
                  "l": "true"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "tmp 2",
      "expression": "grel:with(forEach(value.cross('ba-sachsen','tmp 1'),r,forNonBlank(r.cells['0100'].value,v,v,null)).join('␟') + forEach(value.cross('ba-sachsen','tmp 2'),r,forNonBlank(r.cells['0100'].value,v,v,null)).join('␟'),x,x.split('␟')[0])",
      "onError": "set-to-blank",
      "newColumnName": "tmp 2_0100",
      "columnInsertIndex": 6
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "2199",
            "expression": "isBlank(value)",
            "columnName": "2199",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": false,
                  "l": "false"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "0100",
            "expression": "isBlank(value)",
            "columnName": "0100",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": true,
                  "l": "true"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "0100",
      "expression": "grel:forNonBlank(cells['tmp 1_0100'].value,v,v,forNonBlank(cells['tmp 2_0100'].value,v,v,''))",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/column-removal",
      "columnName": "tmp 2_0100"
    },
    {
      "op": "core/column-removal",
      "columnName": "tmp 1_0100"
    },
    {
      "op": "core/column-removal",
      "columnName": "tmp 2"
    },
    {
      "op": "core/column-removal",
      "columnName": "tmp 1"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------- Exemplare clustern --------------------------- #

# TODO: 0110 berücksichtigen
# spec_Z_05
echo "Exemplare clustern..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "0100",
            "expression": "isBlank(value)",
            "columnName": "0100",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": true,
                  "l": "true"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "0100",
      "expression": "null",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "0100",
            "expression": "isBlank(value)",
            "columnName": "0100",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": true,
                  "l": "true"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "0100",
      "expression": "grel:row.record.cells[columnName].value[0]",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/row-reorder",
      "mode": "record-based",
      "sorting": {
        "criteria": [
          {
            "valueType": "string",
            "column": "0100",
            "blankPosition": 2,
            "errorPosition": 1,
            "reverse": false,
            "caseSensitive": false
          }
        ]
      }
    },
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "0100",
      "expression": "grel:forNonBlank(cells['0100'].value,v,v,forNonBlank(cells['2199'].value,v,v,''))",
      "onError": "set-to-blank",
      "newColumnName": "id",
      "columnInsertIndex": 0
    },
    {
      "op": "core/blank-down",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "id"
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

# Export in PICA+
format="pic"
echo "export ${p} to pica+ file using template..."
IFS= read -r -d '' template << "TEMPLATE"
{{
if(row.index - row.record.fromRowIndex == 0,
'' + '\n'
+ forNonBlank(cells['0500'].value, v, '002@' + ' 0' + v + '\n', '')
+ forNonBlank(cells['0100'].value, v, '003@' + ' 0' + v + '\n', '')
+ forNonBlank(cells['1100a'].value, v, '011@' + ' a' + v + ' n' + cells['1100n'].value + '\n', '')
+ forNonBlank(cells['1140'].value, v, '013H@' + ' a' + v + '\n', '')
+ forNonBlank(cells['2000'].value, v, forEach(v.split('␟'),x,'004A' + ' 0' + x + '\n').join(''), '')
+ forNonBlank(cells['2199'].value, v, '006Y' + ' 0' + v + '\n', '')
+ forNonBlank(cells['4000'].value, v, '021A' + ' a' + v + '\n', '')
,'')
}}{{
if(isNonBlank(cells['7100f'].value),
with(with(rowIndex - row.record.fromRowIndex + 1, i, '00'[0,2-i.length()] + i),exnr,
'208@/' + exnr + ' a' + cells['E0XX'].value + 'bn' + cells['E0XXb'].value + '\n'
+ '209A/' + exnr + ' B' + cells['7100B'].value + 'f' + cells['7100f'].value + forNonBlank(cells['7100a'].value, v, 'a' + v, '') + 'x00' + '\n'
+ forNonBlank(cells['8200'].value, v, '209C/' + exnr + ' a' + v + '\n', '')
), '')
}}
TEMPLATE
if echo "${template}" | head -c -2 | curl -fs \
  --data project="${projects[$p]}" \
  --data format="template" \
  --data prefix="" \
  --data suffix="" \
  --data separator="" \
  --data engine='{"facets":[],"mode":"row-based"}' \
  --data-urlencode template@- \
  "${endpoint}/command/core/export-rows" \
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
