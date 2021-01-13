#!/bin/bash
# Bibliotheca Vorverarbeitung
# - Export von einer der Bibliotheken importieren
# - in Tabellenformat umwandeln
# - als TSV exportieren

# =============================== ENVIRONMENT ================================ #

# source the main script
source "${BASH_SOURCE%/*}/../bash-refine.sh" || exit 1

# read input
if [[ $1 ]]; then
  p="$(basename "$1" .imp)"
  projects[$p]="$(readlink -e "$1")"
else
  echo 1>&2 "Please provide path to input file"; exit 1
fi

# check requirements, set trap, create workdir and tee to logfile
init

# ================================= STARTUP ================================== #

checkpoint "Startup"; echo

# print environment variables
printenv | grep REFINE; echo

# start OpenRefine server
refine_start; echo

# ================================== IMPORT ================================== #

checkpoint "Import"; echo

# Line-based text files
# Character encoding: ISO-8859-1
# Store blank rows deaktivieren
# ignore first 1 line(s) at the beginning of file

echo "import file" "${projects[$p]}" "..."
if curl -fs --write-out "%{redirect_url}\n" \
  --form project-file="@${projects[$p]}" \
  --form project-name="${p}" \
  --form format="line-based" \
  --form options='{
                   "encoding": "ISO-8859-1",
                   "storeBlankRows": "false",
                   "ignoreLines": 1
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

# ------------------------- Makulierte Medien löschen ------------------------ #

# spec_Z_03
# löscht alle Titel und deren Exemplare, die nur makulierte Ex. enthalten
# löscht dann alle verbliebenen makulierten Ex.

echo "Makulierte Medien löschen..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "*********M",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "record-based"
      },
      "baseColumnName": "Column 1",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "tmp",
      "columnInsertIndex": 1
    },
    {
      "op": "core/column-move",
      "columnName": "tmp",
      "index": 0
    },
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "Column 1",
            "expression": "grel:if(isNonBlank(cells['tmp'].value),with(row.record.cells[columnName].value.join('').find(/EXSTA ./).uniques().join(''),v,v),null)",
            "columnName": "Column 1",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "EXSTA M",
                  "l": "EXSTA M"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "record-based"
      }
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "*********E",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "tmp",
      "expression": "grel:cells['Column 1'].value",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "EXSTA M",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "record-based"
      }
    },
    {
      "op": "core/column-removal",
      "columnName": "tmp"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# -------------------------- ACQ Datensätze löschen -------------------------- #

# spec_Z_03
# löscht alle Titel und deren Exemplare, die das Kennzeichen ACQ enthalten
# löscht dann alle verbliebenen Exemplare mit Kennzeichen ACQ

echo "ACQ Datensätze löschen..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "*********M",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "record-based"
      },
      "baseColumnName": "Column 1",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "tmp",
      "columnInsertIndex": 1
    },
    {
      "op": "core/column-move",
      "columnName": "tmp",
      "index": 0
    },
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "Column 1",
            "expression": "grel:if(isNonBlank(cells['tmp'].value),with(row.record.cells[columnName].value.join('').find(/MEKZ ./).uniques().join(''),v,v),null)",
            "columnName": "Column 1",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "MEKZ  ACQ",
                  "l": "MEKZ  ACQ"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "record-based"
      }
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "*********E",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "tmp",
      "expression": "grel:cells['Column 1'].value",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "MEKZ  ACQ",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "record-based"
      }
    },
    {
      "op": "core/column-removal",
      "columnName": "tmp"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ---------------------- Mehrzeilige Inhalte extrahieren --------------------- #

# - Column 1 > Text filter > regular expression aktivieren > ^\* > invert
# -- Column 1 > Edit column > Add column based on this column...
#       > value > value.slice(1)
# -- Column 1 > Edit cells > Transform... > null

echo "Mehrzeilige Inhalte extrahieren..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "^\\*",
            "mode": "regex",
            "caseSensitive": false,
            "invert": true
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "Column 1",
      "expression": "grel:value.slice(1)",
      "onError": "set-to-blank",
      "newColumnName": "value",
      "columnInsertIndex": 1
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "^\\*",
            "mode": "regex",
            "caseSensitive": false,
            "invert": true
          }
        ],
        "mode": "row-based"
      },
      "columnName": "Column 1",
      "expression": "grel:null",
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

# ---------------------------- Leerzeilen löschen ---------------------------- #

# - All > Facet > Facet by blank > true
# - All > Edit rows > Remove all matching rows

echo "Leerzeilen löschen..."
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
            "name": "Blank Rows",
            "expression": "(filter(row.columnNames,cn,isNonBlank(cells[cn].value)).length()==0).toString()",
            "columnName": "",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "true",
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


# ------------------------ Felder und Werte aufteilen ------------------------ #

# - value > Facet > Customized facets > Facet by blank > true
# -- value > Edit cells > Transform... > cells['Column 1'].value.slice(9)
# - Column 1 > Edit cells.> Transform > value[3,8]
# - Column 1 > Edit column > Rename this column > key

echo "Felder und Werte aufteilen..."
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
            "name": "value",
            "expression": "isBlank(value)",
            "columnName": "value",
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
      "columnName": "value",
      "expression": "grel:cells['Column 1'].value.slice(9)",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "Column 1",
      "expression": "grel:value[3,8]",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/column-rename",
      "oldColumnName": "Column 1",
      "newColumnName": "key"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo


# ----------------- Mehrzeilige Inhalte (mit #) zusammenführen --------------- #

# - value > Edit cells > Join multi-valued cells... > ␟
# (das ist das Unicode-Zeichen U+241F)

echo "Mehrzeilige Inhalte (mit #) zusammenführen..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/multivalued-cell-join",
      "columnName": "value",
      "keyColumnName": "key",
      "separator": "␟"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo


# ----------------------- Feldnamen um M oder E ergänzen --------------------- #

# - key > Facet > Text facet > *****
# -- value > Edit column > Add column based on this column... > typ > value
# - typ > Edit cells > Fill down
# - key > Facet > Text facet > *****
# -- All > Edit rows > Remove all matching rows
# - key > Edit cells > Transform... > cells['typ'].value + '|' + value
# - typ > Edit column > Remove this column

echo "Feldnamen um M oder E ergänzen..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "key",
            "expression": "value",
            "columnName": "key",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "*****",
                  "l": "*****"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "value",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "typ",
      "columnInsertIndex": 2
    },
    {
      "op": "core/fill-down",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "typ"
    },
    {
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "key",
            "expression": "value",
            "columnName": "key",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "*****",
                  "l": "*****"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      }
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "key",
      "expression": "grel:cells['typ'].value + '|' + value",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/column-removal",
      "columnName": "typ"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# --------------------- Mehrfachbelegungen zusammenführen -------------------- #

# - key > Edit cells > Blank down
# - value > Edit cells > join multi-valued cells... > ␟

echo "Mehrfachbelegungen zusammenführen..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/blank-down",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "key"
    },
    {
      "op": "core/multivalued-cell-join",
      "columnName": "value",
      "keyColumnName": "key",
      "separator": "␟"
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# -------------------- Titeldaten-Felder mit Zahlen löschen ------------------ #

# außer 025z 026 026k 052 076b 076d
echo "Titeldaten-Felder mit Zahlen löschen..."
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
            "name": "key",
            "expression": "grel:and(isNumeric(value[2,4].trim()), not(or(value[2,6] == '025z', value[2,6] == '026 ', value[2,6] == '026k', value[2,6] == '052 ', value[2,6] == '076b', value[2,6] == '076d')))",
            "columnName": "key",
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

# ------------------------------- Transponieren ------------------------------ #

# - key > Transpose > Columnize by key/value columns... > OK

echo "Transponieren..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/key-value-columnize",
      "keyColumnName": "key",
      "valueColumnName": "value",
      "noteColumnName": ""
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

format="tsv"
echo "export ${p} to ${format} file..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data format="${format}" \
  --data engine='{"facets":[],"mode":"row-based"}' \
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
