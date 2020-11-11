#!/bin/bash
# Alephino Vorverarbeitung
# - Exporte (Titel und Exemplare) von einer der Bibliotheken importieren
# - in Tabellenformat umwandeln
# - Exemplarinformationen an Titel anhängen
# - als TSV exportieren

# =============================== ENVIRONMENT ================================ #

# source the main script
source "${BASH_SOURCE%/*}/../bash-refine.sh" || exit 1

# read input
if [[ $2 ]]; then
  titel="$(basename "$1" .txt)"
  projects[$titel]="$(readlink -e "$1")"
  exemplare="$(basename "$2" .txt)"
  projects[$exemplare]="$(readlink -e "$2")"
else
  echo 1>&2 "Please provide path to input files (1. Titel, 2. Exemplare)"; exit 1
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

# Fixed-width text files
# Columns: 5
# Character encoding: UTF-8
# Store blank rows deaktivieren

echo "import file" "${projects[$titel]}" "..."
if curl -fs --write-out "%{redirect_url}\n" \
  --form project-file="@${projects[$titel]}" \
  --form project-name="${titel}" \
  --form format="text/line-based/fixed-width" \
  --form options='{
                  "encoding":"UTF-8",
                  "columnWidths":[5],
                  "ignoreLines":-1,
                  "headerLines":0,
                  "skipDataLines":0,
                  "limit":-1,
                  "guessCellValueTypes":false,
                  "storeBlankRows":false,
                  "storeBlankCellsAsNulls":true,
                  "includeFileSources":false
                  }' \
  "${endpoint}/command/core/create-project-from-upload$(refine_csrf)" \
  > "${workdir}/${titel}.id"
then
  log "imported ${projects[$titel]} as ${titel}"
else
  error "import of ${projects[$titel]} failed!"
fi
refine_store "${titel}" "${workdir}/${titel}.id" || error "import of ${titel} failed!"
echo

echo "import file" "${projects[$exemplare]}" "..."
if curl -fs --write-out "%{redirect_url}\n" \
  --form project-file="@${projects[$exemplare]}" \
  --form project-name="${exemplare}" \
  --form format="text/line-based/fixed-width" \
  --form options='{
                  "encoding":"UTF-8",
                  "columnWidths":[5],
                  "ignoreLines":-1,
                  "headerLines":0,
                  "skipDataLines":0,
                  "limit":-1,
                  "guessCellValueTypes":false,
                  "storeBlankRows":false,
                  "storeBlankCellsAsNulls":true,
                  "includeFileSources":false
                  }' \
  "${endpoint}/command/core/create-project-from-upload$(refine_csrf)" \
  > "${workdir}/${exemplare}.id"
then
  log "imported ${projects[$exemplare]} as ${exemplare}"
else
  error "import of ${projects[$exemplare]} failed!"
fi
refine_store "${exemplare}" "${workdir}/${exemplare}.id" || error "import of ${exemplare} failed!"
echo

# ================================ TRANSFORM ================================= #

checkpoint "Transform"; echo

# --------------------------- Korrekturen Einzelfälle ------------------------ #

echo "Korrekturen Einzelfälle..."
if curl -fs \
  --data project="${projects[$titel]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/mass-edit",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "Column 1",
      "expression": "value",
      "edits": [
        {
          "from": [
            "001st"
          ],
          "fromBlank": false,
          "fromError": false,
          "to": "001"
        }
      ],
      "description": "Mass edit cells in column Column 1"
    }
  ]
JSON
then
  log "transformed ${titel} (${projects[$titel]})"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi

# ----------------------- Feldnamen um M bzw. E ergänzen --------------------- #

echo "Feldnamen um M bzw. E ergänzen..."
if curl -fs \
  --data project="${projects[$titel]}" \
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
      "columnName": "Column 1",
      "expression": "grel:'M|' + value.replace(' ','')",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10,
      "description": "Text transform on cells in column Column 1 using expression grel:'M|' + value.replace(' ','')"
    }
  ]
JSON
then
  log "transformed ${titel} (${projects[$titel]})"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi
if curl -fs \
  --data project="${projects[$exemplare]}" \
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
      "columnName": "Column 1",
      "expression": "grel:'E|' + value.replace(' ','')",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10,
      "description": "Text transform on cells in column Column 1 using expression grel:'E|' + value.replace(' ','')"
    }
  ]
JSON
then
  log "transformed ${exemplare} (${projects[$exemplare]})"
else
  error "transform ${exemplare} (${projects[$exemplare]}) failed!"
fi
echo

# -------------------------------- Sortieren --------------------------------- #

echo "Datensätze und Feldnamen sortieren..."
if curl -fs \
  --data project="${projects[$titel]}" \
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
            "name": "Column 1",
            "expression": "value",
            "columnName": "Column 1",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "M|IDN",
                  "l": "M|IDN"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "Column 2",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "id",
      "columnInsertIndex": 2,
      "description": "Create column id at index 2 based on column Column 2 using expression grel:value"
    },
    {
      "op": "core/column-move",
      "columnName": "id",
      "index": 0,
      "description": "Move column id to position 0"
    },
    {
      "op": "core/fill-down",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "id",
      "description": "Fill down cells in column id"
    },
    {
      "op": "core/row-reorder",
      "mode": "row-based",
      "sorting": {
        "criteria": [
          {
            "valueType": "string",
            "column": "id",
            "blankPosition": 2,
            "errorPosition": 1,
            "reverse": false,
            "caseSensitive": false
          },
          {
            "valueType": "string",
            "column": "Column 1",
            "blankPosition": 2,
            "errorPosition": 1,
            "reverse": false,
            "caseSensitive": false
          }
        ]
      },
      "description": "Reorder rows"
    },
    {
      "op": "core/column-removal",
      "columnName": "id",
      "description": "Remove column id"
    }
  ]
JSON
then
  log "transformed ${titel} (${projects[$titel]})"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi
if curl -fs \
  --data project="${projects[$exemplare]}" \
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
            "name": "Column 1",
            "expression": "value",
            "columnName": "Column 1",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "E|IDN",
                  "l": "E|IDN"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "Column 2",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "id",
      "columnInsertIndex": 2,
      "description": "Create column id at index 2 based on column Column 2 using expression grel:value"
    },
    {
      "op": "core/column-move",
      "columnName": "id",
      "index": 0,
      "description": "Move column id to position 0"
    },
    {
      "op": "core/fill-down",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "id",
      "description": "Fill down cells in column id"
    },
    {
      "op": "core/row-reorder",
      "mode": "row-based",
      "sorting": {
        "criteria": [
          {
            "valueType": "string",
            "column": "id",
            "blankPosition": 2,
            "errorPosition": 1,
            "reverse": false,
            "caseSensitive": false
          },
          {
            "valueType": "string",
            "column": "Column 1",
            "blankPosition": 2,
            "errorPosition": 1,
            "reverse": false,
            "caseSensitive": false
          }
        ]
      },
      "description": "Reorder rows"
    },
    {
      "op": "core/column-removal",
      "columnName": "id",
      "description": "Remove column id"
    }
  ]
JSON
then
  log "transformed ${exemplare} (${projects[$exemplare]})"
else
  error "transform ${exemplare} (${projects[$exemplare]}) failed!"
fi
echo

# --------------------- Mehrfachbelegungen zusammenführen -------------------- #

# - Column 1 > Edit cells > Blank down
# - Column 2 > Edit cells > join multi-valued cells... > ␟

echo "Mehrfachbelegungen zusammenführen..."
if curl -fs \
  --data project="${projects[$titel]}" \
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
      "columnName": "Column 1",
      "description": "Blank down cells in column Column 1"
    },
    {
      "op": "core/multivalued-cell-join",
      "columnName": "Column 2",
      "keyColumnName": "Column 1",
      "separator": "␟",
      "description": "Join multi-valued cells in column Column 2"
    }
  ]
JSON
then
  log "transformed ${titel} (${projects[$titel]})"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi
if curl -fs \
  --data project="${projects[$exemplare]}" \
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
      "columnName": "Column 1",
      "description": "Blank down cells in column Column 1"
    },
    {
      "op": "core/multivalued-cell-join",
      "columnName": "Column 2",
      "keyColumnName": "Column 1",
      "separator": "␟",
      "description": "Join multi-valued cells in column Column 2"
    }
  ]
JSON
then
  log "transformed ${exemplare} (${projects[$exemplare]})"
else
  error "transform ${exemplare} (${projects[$exemplare]}) failed!"
fi
echo

# ---------------------- Nicht benötigte Felder löschen ---------------------- #

echo "Nicht benötigte Felder löschen..."
if curl -fs \
  --data project="${projects[$titel]}" \
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
            "name": "Column 1",
            "expression": "value",
            "columnName": "Column 1",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "M|025_",
                  "l": "M|025_"
                }
              },
              {
                "v": {
                  "v": "M|025e",
                  "l": "M|025e"
                }
              },
              {
                "v": {
                  "v": "M|004",
                  "l": "M|004"
                }
              },
              {
                "v": {
                  "v": "M|011",
                  "l": "M|011"
                }
              },
              {
                "v": {
                  "v": "M|026_",
                  "l": "M|026_"
                }
              },
              {
                "v": {
                  "v": "M|026a",
                  "l": "M|026a"
                }
              },
              {
                "v": {
                  "v": "M|026d",
                  "l": "M|026d"
                }
              },
              {
                "v": {
                  "v": "M|026g",
                  "l": "M|026g"
                }
              },
              {
                "v": {
                  "v": "M|030",
                  "l": "M|030"
                }
              },
              {
                "v": {
                  "v": "M|037z",
                  "l": "M|037z"
                }
              },
              {
                "v": {
                  "v": "M|038b",
                  "l": "M|038b"
                }
              },
              {
                "v": {
                  "v": "M|070",
                  "l": "M|070"
                }
              },
              {
                "v": {
                  "v": "M|073",
                  "l": "M|073"
                }
              },
              {
                "v": {
                  "v": "M|076z",
                  "l": "M|076z"
                }
              },
              {
                "v": {
                  "v": "M|080",
                  "l": "M|080"
                }
              },
              {
                "v": {
                  "v": "M|800s",
                  "l": "M|800s"
                }
              },
              {
                "v": {
                  "v": "M|802",
                  "l": "M|802"
                }
              },
              {
                "v": {
                  "v": "M|808b",
                  "l": "M|808b"
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
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "Column 1",
            "columnName": "Column 1",
            "query": "^M\\|9",
            "mode": "regex",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "row-based"
      }
    }
  ]
JSON
then
  log "transformed ${titel} (${projects[$titel]})"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi
if curl -fs \
  --data project="${projects[$exemplare]}" \
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
            "name": "Column 1",
            "expression": "value",
            "columnName": "Column 1",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "E|A02",
                  "l": "E|A02"
                }
              },
              {
                "v": {
                  "v": "E|A86",
                  "l": "E|A86"
                }
              },
              {
                "v": {
                  "v": "E|SUB",
                  "l": "E|SUB"
                }
              },
              {
                "v": {
                  "v": "E|FMT",
                  "l": "E|FMT"
                }
              },
              {
                "v": {
                  "v": "E|CAT",
                  "l": "E|CAT"
                }
              },
              {
                "v": {
                  "v": "E|027",
                  "l": "E|027"
                }
              },
              {
                "v": {
                  "v": "E|123",
                  "l": "E|123"
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
  log "transformed ${exemplare} (${projects[$exemplare]})"
else
  error "transform ${exemplare} (${projects[$exemplare]}) failed!"
fi
echo


# ------------------------------- Transponieren ------------------------------ #

# - Column 1 > Transpose > Columnize by key/value columns... > OK

echo "Transponieren..."
if curl -fs \
  --data project="${projects[$titel]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/key-value-columnize",
      "keyColumnName": "Column 1",
      "valueColumnName": "Column 2",
      "noteColumnName": "",
      "description": "Columnize by key column Column 1 and value column Column 2 with note column "
    }
  ]
JSON
then
  log "transformed ${titel} (${projects[$titel]})"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi
if curl -fs \
  --data project="${projects[$exemplare]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/key-value-columnize",
      "keyColumnName": "Column 1",
      "valueColumnName": "Column 2",
      "noteColumnName": "",
      "description": "Columnize by key column Column 1 and value column Column 2 with note column "
    }
  ]
JSON
then
  log "transformed ${exemplare} (${projects[$exemplare]})"
else
  error "transform ${exemplare} (${projects[$exemplare]}) failed!"
fi
echo

# ---------------------------- Titel-ID separieren --------------------------- #

echo "Titel-ID separieren..."
if curl -fs \
  --data project="${projects[$titel]}" \
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
      "baseColumnName": "M|IDN",
      "expression": "grel:value.replace(/^0+/,'')",
      "onError": "set-to-blank",
      "newColumnName": "id",
      "columnInsertIndex": 12,
      "description": "Create column id at index 12 based on column M|IDN using expression grel:value.replace(/^0+/,'')"
    }
  ]
JSON
then
  log "transformed ${titel} (${projects[$titel]})"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi
if curl -fs \
  --data project="${projects[$exemplare]}" \
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
      "baseColumnName": "E|BIB",
      "expression": "grel:value.split('\u001f')[0].slice(1).replace(/^0+/,'')",
      "onError": "set-to-blank",
      "newColumnName": "titel_id",
      "columnInsertIndex": 18,
      "description": "Create column titel_id at index 18 based on column E|BIB using expression grel:value.split('\u001f')[0].slice(1).replace(/^0+/,'')"
    }
  ]
JSON
then
  log "transformed ${exemplare} (${projects[$exemplare]})"
else
  error "transform ${exemplare} (${projects[$exemplare]}) failed!"
fi
echo

# ---------------------------- Exemplare anreichern -------------------------- #

echo "Exemplare anreichern..."
columns=( "E|001" "E|002a" "E|003" "E|004" "E|027" "E|030" "E|050" "E|100" "E|115" "E|120" "E|123" "E|A02" "E|A72" "E|A73" "E|A87" "E|A91" "E|A95" "E|BIB" "E|CAT" "E|FMT" "E|IDN" "E|LDR" "E|STA" "E|SUB" "E|105" "E|107" "E|A94" "E|125" "E|072" "E|A98" "E|HOL" "E|A86" "E|A63" "E|A70" "E|A83" "E|A85" "E|ABO" "E|A97" "E|A82" "E|002" "E|ORD" )
for column in "${columns[@]}"; do
  cat << JSON >> "${workdir}/${titel}.tmp"
[
  {
    "op": "core/column-addition",
    "engineConfig": {
      "facets": [],
      "mode": "row-based"
    },
    "baseColumnName": "id",
    "expression": "grel:forEach(value.cross('${exemplare}','titel_id'),r,forNonBlank(r.cells['${column}'].value,v,v,'')).join('␞')",
    "onError": "set-to-blank",
    "newColumnName": "${column}",
    "columnInsertIndex": 13
  },
  {
    "op": "core/multivalued-cell-split",
    "columnName": "${column}",
    "keyColumnName": "M|001",
    "mode": "separator",
    "separator": "␞",
    "regex": false
  }
]
JSON
done
if "${jq}" -s add "${workdir}/${titel}.tmp" | curl -fs \
  --data project="${projects[$titel]}" \
  --data-urlencode operations@- \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null
then
  log "transformed ${titel} (${projects[$titel]})"
  rm "${workdir}/${titel}.tmp"
else
  error "transform ${titel} (${projects[$titel]}) failed!"
fi
echo

# ================================== EXPORT ================================== #

checkpoint "Export"; echo

format="tsv"
p="${titel%%-*}" # Projektname ohne Zusatz
echo "export ${titel} to ${format} file..."
if curl -fs \
  --data project="${projects[$titel]}" \
  --data format="${format}" \
  --data engine='{"facets":[],"mode":"row-based"}' \
  "${endpoint}/command/core/export-rows" \
  > "${workdir}/${p}.${format}"
then
  log "exported ${titel} (${projects[$titel]}) to ${workdir}/${p}.${format}"
else
  error "export of ${titel} (${projects[$titel]}) failed!"
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
