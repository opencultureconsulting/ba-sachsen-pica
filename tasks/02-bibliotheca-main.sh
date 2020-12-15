#!/bin/bash
# Bibliotheca Hauptverarbeitung
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
zip -j "${workdir}/bibliotheca.zip" "${inputdir}"/*.tsv
projects["bibliotheca"]="${workdir}/bibliotheca.zip"

# Neues Projekt erstellen aus Zip-Archiv
p="bibliotheca"
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

echo "Spalten sortieren: Beginnen mit 1. M|MEDNR, 2. E|EXNR, 3. File..."
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
      "columnName": "E|EXNR",
      "index": 0
    },
    {
      "op": "core/column-move",
      "columnName": "M|MEDNR",
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

# ------------------------- E-Books löschen (Bautzen) ------------------------ #

# spec_Z_01
# - M|MEDGR > Facet > Text facet > eBook
# -- show as: records
# --- All > Edit rows > Remove all matching rows

echo "E-Books löschen (Bautzen)..."
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
            "name": "M|MEDGR",
            "expression": "value",
            "columnName": "M|MEDGR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "eBook",
                  "l": "eBook"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "record-based"
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

# ------------------ Zeitschriften und Teile von MTM löschen ----------------- #

# spec_Z_02
# siehe auch Spezifikation in CBS-Titeldaten Bibliotheca
echo "Zeitschriften und Teile von MTM löschen..."
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
            "name": "M|ART",
            "expression": "value",
            "columnName": "M|ART",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "GH",
                  "l": "GH"
                }
              },
              {
                "v": {
                  "v": "Z",
                  "l": "Z"
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
      "op": "core/row-removal",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|ART",
            "expression": "value",
            "columnName": "M|ART",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "G",
                  "l": "G"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|UART",
            "expression": "value",
            "columnName": "M|UART",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "R",
                  "l": "R"
                }
              },
              {
                "v": {
                  "v": "Z",
                  "l": "Z"
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
            "type": "list",
            "name": "M|ART",
            "expression": "value",
            "columnName": "M|ART",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "G",
                  "l": "G"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|MEDNR",
            "expression": "grel:forEach(value.cross('bibliotheca','M|NRPRE'),r,if(and(r.cells['File'].value == cells['File'].value, isNonBlank(r.cells['M|BANDB'].value)),'vorhanden','fehlt')).inArray('vorhanden')",
            "columnName": "M|MEDNR",
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
            "selectError": true
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

# ------------------------- Makulierte Medien löschen ------------------------ #

# spec_Z_03
# löscht alle Titel+Exemplare, die ausschließlich makulierte Ex. enthalten

echo "Makulierte Medien löschen..."
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
            "name": "E|EXSTA",
            "expression": "grel:row.record.cells[columnName].value.uniques().join(',') == 'M'",
            "columnName": "E|EXSTA",
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
        "mode": "record-based"
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
      "expression": "grel:with([ ['bautzen.tsv','BZ'], ['breitenbrunn.tsv','BB'], ['dresden.tsv','DD'],  ['glauchau.tsv','GC'], ['plauen.tsv','PL'] ], mapping, forEach(mapping, m, if(value == m[0], m[1], '')).join(''))",
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

# -------------------------------- 0100 / 0110 ------------------------------- #

# spec_B_T_01
# 8-stellige aus Dresden sind SWN ohne Prüfziffer, dort wird Prüfziffer ergänzt
# Zuordnung 9-stellige abhängig von ersten Zeichen und M026 / M026k
# Zuordnung 10-stellige abhängig von erstem Zeichen
echo "PPNs in 0100 (K10plus) und 0110 (SWB)..."
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
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 8,
                  "l": "8"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "M|IDNR",
      "expression": "grel:value + with(11 - mod(sum(forRange(0,9,1,i,toNumber(value[i])*(9-i))),11),pz,if(pz == 11, '0', if(pz == 10, 'X', pz)))",
      "onError": "set-to-blank",
      "newColumnName": "0110",
      "columnInsertIndex": 4
    },
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 9,
                  "l": "9"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value[0,2]",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "53",
                  "l": "53"
                }
              },
              {
                "v": {
                  "v": "54",
                  "l": "54"
                }
              },
              {
                "v": {
                  "v": "55",
                  "l": "55"
                }
              },
              {
                "v": {
                  "v": "56",
                  "l": "56"
                }
              },
              {
                "v": {
                  "v": "57",
                  "l": "57"
                }
              },
              {
                "v": {
                  "v": "13",
                  "l": "13"
                }
              },
              {
                "v": {
                  "v": "14",
                  "l": "14"
                }
              },
              {
                "v": {
                  "v": "58",
                  "l": "58"
                }
              },
              {
                "v": {
                  "v": "15",
                  "l": "15"
                }
              },
              {
                "v": {
                  "v": "59",
                  "l": "59"
                }
              },
              {
                "v": {
                  "v": "16",
                  "l": "16"
                }
              },
              {
                "v": {
                  "v": "17",
                  "l": "17"
                }
              },
              {
                "v": {
                  "v": "18",
                  "l": "18"
                }
              },
              {
                "v": {
                  "v": "19",
                  "l": "19"
                }
              },
              {
                "v": {
                  "v": "21",
                  "l": "21"
                }
              },
              {
                "v": {
                  "v": "22",
                  "l": "22"
                }
              },
              {
                "v": {
                  "v": "23",
                  "l": "23"
                }
              },
              {
                "v": {
                  "v": "24",
                  "l": "24"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "M|IDNR",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "0100",
      "columnInsertIndex": 4
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 9,
                  "l": "9"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value[0,1]",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "6",
                  "l": "6"
                }
              },
              {
                "v": {
                  "v": "7",
                  "l": "7"
                }
              },
              {
                "v": {
                  "v": "8",
                  "l": "8"
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
      "expression": "grel:cells['M|IDNR'].value",
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
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 9,
                  "l": "9"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value[0,2]",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "00",
                  "l": "00"
                }
              },
              {
                "v": {
                  "v": "10",
                  "l": "10"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "0110",
      "expression": "grel:cells['M|IDNR'].value",
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
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 9,
                  "l": "9"
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
          },
          {
            "type": "list",
            "name": "0110",
            "expression": "isBlank(value)",
            "columnName": "0110",
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
          },
          {
            "type": "list",
            "name": "M|026",
            "expression": "grel:value[0,3]",
            "columnName": "M|026",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "GBV",
                  "l": "GBV"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|026k",
            "expression": "grel:value == cells['M|IDNR'].value",
            "columnName": "M|026k",
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
      "expression": "grel:cells['M|IDNR'].value",
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
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 9,
                  "l": "9"
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
          },
          {
            "type": "list",
            "name": "0110",
            "expression": "isBlank(value)",
            "columnName": "0110",
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
          },
          {
            "type": "list",
            "name": "M|026",
            "expression": "grel:value[0,3]",
            "columnName": "M|026",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "HBZ",
                  "l": "HBZ"
                }
              },
              {
                "v": {
                  "v": "KXP",
                  "l": "KXP"
                }
              },
              {
                "v": {
                  "v": "OBV",
                  "l": "OBV"
                }
              },
              {
                "v": {
                  "v": "DNB",
                  "l": "DNB"
                }
              },
              {
                "v": {
                  "v": "BVB",
                  "l": "BVB"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|026k",
            "expression": "isBlank(value)",
            "columnName": "M|026k",
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
          }
        ],
        "mode": "row-based"
      },
      "columnName": "0100",
      "expression": "grel:cells['M|IDNR'].value",
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
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 9,
                  "l": "9"
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
          },
          {
            "type": "list",
            "name": "0110",
            "expression": "isBlank(value)",
            "columnName": "0110",
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
      "columnName": "0110",
      "expression": "grel:cells['M|IDNR'].value",
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
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 10,
                  "l": "10"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value[0]",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "1",
                  "l": "1"
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
      "expression": "grel:cells['M|IDNR'].value",
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
            "name": "M|IDNR",
            "expression": "grel:value.length()",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": 10,
                  "l": "10"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "M|IDNR",
            "expression": "grel:value[0]",
            "columnName": "M|IDNR",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "9",
                  "l": "9"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "0110",
      "expression": "grel:cells['M|IDNR'].value",
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

# ------------------------------------ 2199 ---------------------------------- #

# spec_B_T_49
echo "Nummern aus Datenkonversion 2199..."
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
      "baseColumnName": "M|MEDNR",
      "expression": "grel:'BA' + cells['File'].value + value",
      "onError": "set-to-blank",
      "newColumnName": "2199",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 7100j ---------------------------------- #

# spec_B_E_15
echo "Abteilungsnummer 7100j..."
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
      "baseColumnName": "File",
      "expression": "grel:with(if(value=='DD',forNonBlank(cells['E|ZWGST'].value,v,v,value),value),x,x.replace('BB','0002').replace('BZ','0001').replace('DD','0003').replace('EH','0008').replace('GC','0004').replace('PL','0007'))",
      "onError": "set-to-blank",
      "newColumnName": "7100j",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 7100f ---------------------------------- #

# spec_B_E_13, spec_Z_03 und spec_B_E_08
echo "Zweigstelle 7100f"
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
      "baseColumnName": "File",
      "expression": "grel:if(value=='DD',forNonBlank(cells['E|ZWGST'].value,v,v,value),value)",
      "onError": "set-to-blank",
      "newColumnName": "7100f",
      "columnInsertIndex": 3
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BB",
                  "l": "BB"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Medienschrank",
                  "l": "Medienschrank"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' +'MS'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BB",
                  "l": "BB"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Medientrog",
                  "l": "Medientrog"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'MT'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BB",
                  "l": "BB"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Thekenbereich",
                  "l": "Thekenbereich"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'TH'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BB",
                  "l": "BB"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Tonwerkstatt",
                  "l": "Tonwerkstatt"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'TW'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Andachtsraum",
                  "l": "Andachtsraum"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Andacht'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "apfe",
                  "l": "apfe"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'apfe'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Ausleihtheke",
                  "l": "Ausleihtheke"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Theke'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Brückenkurs",
                  "l": "Brückenkurs"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Bruecke'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "eFlex",
                  "l": "eFlex"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Flex'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "GesundKompMigrantInnen",
                  "l": "GesundKompMigrantInnen"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'GKM'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Handbestand Bibliothek",
                  "l": "Handbestand Bibliothek"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'HBBib'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Integra",
                  "l": "Integra"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Integra'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "IQ",
                  "l": "IQ"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'IQ'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "KBS",
                  "l": "KBS"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'KBS'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "KBZ",
                  "l": "KBZ"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'KBZ'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Lehrbuchsammlung",
                  "l": "Lehrbuchsammlung"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'LBS'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "MAV",
                  "l": "MAV"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'MAV'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Mittendrin",
                  "l": "Mittendrin"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Mitte'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Modulapparat",
                  "l": "Modulapparat"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Modul'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Neuerwerbungsregal",
                  "l": "Neuerwerbungsregal"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Neu'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "PRAWIMA",
                  "l": "PRAWIMA"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Praw'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Silqua",
                  "l": "Silqua"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Silqua'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "SmarteJugArb",
                  "l": "SmarteJugArb"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'SJA'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Verwaltung",
                  "l": "Verwaltung"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Verw'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Welcome",
                  "l": "Welcome"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Wel'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "Wohnformen",
                  "l": "Wohnformen"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Wohn'",
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "ZUSe",
                  "l": "ZUSe"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100f",
      "expression": "grel:value + '-' + 'Zuse'",
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

# ----------------------------------- 7100a ---------------------------------- #

# spec_B_E_07
echo "Standort 7100a..."
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
      "baseColumnName": "E|STA1",
      "expression": "grel:value.replace('␟',' ').replace(/ +/,' ')",
      "onError": "set-to-blank",
      "newColumnName": "7100a",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 2000 ----------------------------------- #

# TODO: ISMN in 2020
# spec_B_T_04, spec_B_T_05
echo "ISBN 2000..."
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
        "mode": "record-based"
      },
      "baseColumnName": "M|ISBN",
      "expression": "grel:[ forNonBlank(cells['M|ISBN'].value,v,if(isNumeric(v[0]),v,null),null), forNonBlank(cells['M|ISBN2'].value,v,if(isNumeric(v[0]),v,null),null) ].uniques().join('␟').replace('-','').toUppercase()",
      "onError": "set-to-blank",
      "newColumnName": "2000",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- E0XX ----------------------------------- #

# spec_B_E_10
echo "Zugangsdatum E0XX..."
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
            "name": "E|EXNR",
            "expression": "isBlank(value)",
            "columnName": "E|EXNR",
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
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "E|ZUDAT",
      "expression": "grel:forNonBlank(value,v,v[0,2] + '-' + v[3,5] + '-' + v[8,10],'22-07-20')",
      "onError": "set-to-blank",
      "newColumnName": "E0XX",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- E0XXb ---------------------------------- #

# spec_B_E_14, spec_Z_03, spec_B_E16
# leer für Exemplare, die nicht konvertiert werden sollen:
# - makulierte Exemplare
# - ACQ-Datensätze
echo "Selektionsschlüssel E0XXb..."
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
          "name": "E|EXNR",
          "expression": "isBlank(value)",
          "columnName": "E|EXNR",
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
          "name": "E|EXSTA",
          "expression": "value",
          "columnName": "E|EXSTA",
          "invert": true,
          "omitBlank": false,
          "omitError": false,
          "selection": [
            {
              "v": {
                "v": "M",
                "l": "M"
              }
            }
          ],
          "selectBlank": false,
          "selectError": false
        },
        {
          "type": "list",
          "name": "E|MEKZ",
          "expression": "value",
          "columnName": "E|MEKZ",
          "invert": true,
          "omitBlank": false,
          "omitError": false,
          "selection": [
            {
              "v": {
                "v": "ACQ",
                "l": "ACQ"
              }
            }
          ],
          "selectBlank": false,
          "selectError": false
        }
      ],
      "mode": "row-based"
    },
    "baseColumnName": "File",
    "expression": "grel:with(if(value=='DD',forNonBlank(cells['E|ZWGST'].value,v,v,value),value),x,'n'+x.toLowercase())",
    "onError": "set-to-blank",
    "newColumnName": "E0XXb",
    "columnInsertIndex": 3
  }
]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 0500 ----------------------------------- #

# spec_B_T_56
# TODO: Differenzierung nach MEDGR
echo "Gattung und Status 0500..."
read -r -d '' expression << EXPRESSION
if(
  or(
    value == 'M',
    value == 'L'
  ),
  'Aan',
if(
  value == 'U',
  'Asn',
if(
  or(
    value == 'A',
    value == 'V'
  ),
  'Ban',
if(
  and(
    value == 'P',
    forNonBlank(cells['M|MEDGR'].value,v,if(v == 'SPIEL', true, false),false)
  ),
  'Van',
if(
  value == 'P',
  'Lax',
if(
  value == 'G',
  'Acn',
if(
  value == 'S',
  'AFn',
if(
  value == 'Z',
  'Abn',
null
))))))))
EXPRESSION
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << JSON
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "M|ART",
      "expression": $(echo "grel:${expression}" | ${jq} -s -R '.'),
      "onError": "set-to-blank",
      "newColumnName": "0500",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 1140 ----------------------------------- #

# spec_B_T_53
# TODO: Differenzierung nach MEDGR
echo "Veröffentlichungsart 1140..."
read -r -d '' expression << EXPRESSION
if(
  value == 'A',
  'muto',
if(
  value == 'V',
  'vide',
if(
  value == 'L',
  'lo',
null
)))
EXPRESSION
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << JSON
  [
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "baseColumnName": "M|ART",
      "expression": $(echo "grel:${expression}" | ${jq} -s -R '.'),
      "onError": "set-to-blank",
      "newColumnName": "1140",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 4000a ---------------------------------- #

# spec_B_T_17
echo "Haupttitel 4000a..."
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
        "mode": "record-based"
      },
      "baseColumnName": "M|HST",
      "expression": "grel:if(value.contains('¬'),with(value.split('¬'), v, v[0].trim() + ' @' + v[1].trim()),value)",
      "onError": "set-to-blank",
      "newColumnName": "4000a",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 8200 ----------------------------------- #

# spec_B_E_02
echo "Verbuchungsnummer 8200..."
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
      "baseColumnName": "E|BARCO",
      "expression": "grel:cells['File'].value + value",
      "onError": "set-to-blank",
      "newColumnName": "8200",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 1100 ----------------------------------- #

# spec_B_T_02
# 1100a normiert mit zahlreichen Ersetzungen
# TODO: Jahr (Ende) in Sortierform in 1100b
echo "Jahresangaben 1100a und 1100n..."
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
            "name": "M|MEDNR",
            "expression": "isBlank(value)",
            "columnName": "M|MEDNR",
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
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "M|JAHR",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "1100n",
      "columnInsertIndex": 3
    },
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|MEDNR",
            "expression": "isBlank(value)",
            "columnName": "M|MEDNR",
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
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "M|JAHR",
      "expression": "grel:with(with(with(value.replace('[','').replace(']','').replace('(','').replace(')','').replace(' ','').replace('?','').replace('.','').replace('ca','').replace('c','').replace('ff',''),x,forNonBlank(x.split('/')[1],v,v,x)),y,y.split('-')[0]),z,if(and(z.length()==4,isNumeric(z)),z,if(z=='19XX','19XX',null))))",
      "onError": "set-to-blank",
      "newColumnName": "1100a",
      "columnInsertIndex": 3
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "M|MEDNR",
            "expression": "isBlank(value)",
            "columnName": "M|MEDNR",
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
            "name": "1100a",
            "expression": "isBlank(value)",
            "columnName": "1100a",
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
      "columnName": "1100a",
      "expression": "grel:if(cells['M|JAHR'].value.contains('19'),'19XX','20XX')",
      "onError": "keep-original",
      "repeat": false,
      "repeatCount": 10
    },
    {
      "op": "core/column-addition",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "M|JAHR",
            "columnName": "M|JAHR",
            "query": "-",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "M|JAHR",
      "expression": "grel:value.split('-')[1].replace('[','').replace(']','').replace('(','').replace(')','').replace(' ','').replace('?','').replace('.','')",
      "onError": "set-to-blank",
      "newColumnName": "1100b",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 8515 ----------------------------------- #

# spec_B_E_01
# nur für Bautzen
echo "Ausleihhinweis 8515..."
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
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BZ",
                  "l": "BZ"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "E|AUHIN",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "8515",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 7100d ---------------------------------- #

# spec_B_E_04, spec_B_E_05 und spec_B_E_08
echo "Exemplarstatus 7100d..."
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "H",
                  "l": "H"
                }
              },
              {
                "v": {
                  "v": "I",
                  "l": "I"
                }
              },
              {
                "v": {
                  "v": "T",
                  "l": "T"
                }
              },
              {
                "v": {
                  "v": "U",
                  "l": "U"
                }
              },
              {
                "v": {
                  "v": "V",
                  "l": "V"
                }
              },
              {
                "v": {
                  "v": "v",
                  "l": "v"
                }
              },
              {
                "v": {
                  "v": "Z",
                  "l": "Z"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "E|EXSTA",
      "expression": "grel:'u'",
      "onError": "set-to-blank",
      "newColumnName": "7100d",
      "columnInsertIndex": 3
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "list",
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "A",
                  "l": "A"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "PL",
                  "l": "PL"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'z'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "A",
                  "l": "A"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'a'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "B",
                  "l": "B"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'a'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "G",
                  "l": "G"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'g'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "K",
                  "l": "K"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'i'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "N",
                  "l": "N"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'u'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "P",
                  "l": "P"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BB",
                  "l": "BB"
                }
              },
              {
                "v": {
                  "v": "GC",
                  "l": "GC"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'s'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "P",
                  "l": "P"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              },
              {
                "v": {
                  "v": "BZ",
                  "l": "BZ"
                }
              },
              {
                "v": {
                  "v": "PL",
                  "l": "PL"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'i'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "W",
                  "l": "W"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "PL",
                  "l": "PL"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'c'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "W",
                  "l": "W"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "DD",
                  "l": "DD"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'z'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "W",
                  "l": "W"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BB",
                  "l": "BB"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'z'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "w",
                  "l": "w"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "File",
            "expression": "value",
            "columnName": "File",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "BB",
                  "l": "BB"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'z'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "E",
                  "l": "E"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|ESORG",
            "expression": "value",
            "columnName": "E|ESORG",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "P",
                  "l": "P"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'i'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "E",
                  "l": "E"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|ESORG",
            "expression": "value",
            "columnName": "E|ESORG",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "K",
                  "l": "K"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'u'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "E",
                  "l": "E"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "E|ESORG",
            "expression": "value",
            "columnName": "E|ESORG",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "W",
                  "l": "W"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'c'",
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
            "name": "E|EXSTA",
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "E",
                  "l": "E"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          },
          {
            "type": "list",
            "name": "7100d",
            "expression": "isBlank(value)",
            "columnName": "7100d",
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
      "columnName": "7100d",
      "expression": "grel:'u'",
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
            "name": "E|STA2",
            "expression": "value",
            "columnName": "E|STA2",
            "invert": false,
            "omitBlank": false,
            "omitError": false,
            "selection": [
              {
                "v": {
                  "v": "MAV",
                  "l": "MAV"
                }
              },
              {
                "v": {
                  "v": "eFlex",
                  "l": "eFlex"
                }
              },
              {
                "v": {
                  "v": "Verwaltung",
                  "l": "Verwaltung"
                }
              },
              {
                "v": {
                  "v": "Tonwerkstatt",
                  "l": "Tonwerkstatt"
                }
              }
            ],
            "selectBlank": false,
            "selectError": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "7100d",
      "expression": "grel:'i'",
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

# ----------------------------------- 8011 ----------------------------------- #

# spec_B_E_06
echo "Mediengruppe 8011..."
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
      "baseColumnName": "E|MEDGR",
      "expression": "grel:'MEDGR: ' + value",
      "onError": "set-to-blank",
      "newColumnName": "8011",
      "columnInsertIndex": 3
    }
  ]
JSON
then
  log "transformed ${p} (${projects[$p]})"
else
  error "transform ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- 8100 ----------------------------------- #

# spec_B_E_11 und spec_B_E_12
echo "Zugangsnummer 8100..."
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
      "baseColumnName": "E|ZUNR",
      "expression": "grel:cells['File'].value + ' ' + value.replace('-','/')",
      "onError": "set-to-blank",
      "newColumnName": "8100",
      "columnInsertIndex": 3
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [
          {
            "type": "text",
            "name": "E|ZUS",
            "columnName": "E|ZUS",
            "query": "Notation",
            "mode": "text",
            "caseSensitive": false,
            "invert": false
          }
        ],
        "mode": "row-based"
      },
      "columnName": "8100",
      "expression": "grel:value + ' ' + cells['E|ZUS'].value.replace('Notation||','')",
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

# ----------------------------------- 1500 ----------------------------------- #

# spec_B_T_03
echo "Sprachcode in 1500..."
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
      "baseColumnName": "M|SPRA",
      "expression": "grel:forEach(value.split(/,|#|\\+|;/),v,forNonBlank(v.replace('.','').replace('-','').replace(' ','').\nreplace(/^arab$/,'ara').\nreplace(/^Arabisch$/,'ara').\nreplace(/^aram$/,'arc').\nreplace(/^daen$/,'dan').\nreplace(/^Deutsch$/,'ger').\nreplace(/^DEUTSCH$/,'ger').\nreplace(/^deutsch$/,'ger').\nreplace(/^dt$/,'ger').\nreplace(/^engl$/,'eng').\nreplace(/^Englisch$/,'eng').\nreplace(/^ENGLISCH$/,'eng').\nreplace(/^englisch$/,'eng').\nreplace(/^Finnisch$/,'fin').\nreplace(/^franz$/,'fre').\nreplace(/^Französisch$/,'fre').\nreplace(/^griech$/,'gre').\nreplace(/^hebr$/,'heb').\nreplace(/^hrv$/,'').\nreplace(/^ital$/,'ita').\nreplace(/^Italienisch$/,'ita').\nreplace(/^ITALIENISCH$/,'ita').\nreplace(/^Litauisch$/,'lit').\nreplace(/^n$/,'').\nreplace(/^Niederländisch$/,'dut').\nreplace(/^pers$/,'per').\nreplace(/^poln$/,'pol').\nreplace(/^Polnisch$/,'pol').\nreplace(/^polygl$/,'mul').\nreplace(/^portug$/,'por').\nreplace(/^Portugiesisch$/,'por').\nreplace(/^Portugisisch$/,'por').\nreplace(/^ru$/,'rus').\nreplace(/^Rumänisch$/,'rum').\nreplace(/^russ$/,'rus').\nreplace(/^Russisch$/,'rus').\nreplace(/^schwed$/,'swe').\nreplace(/^Schwedisch$/,'swe').\nreplace(/^slowak$/,'slo').\nreplace(/^sp$/,'spa').\nreplace(/^span$/,'spa').\nreplace(/^Spanisch$/,'spa').\nreplace(/^tschech$/,'cze').\nreplace(/^Tschechisch$/,'cze').\nreplace(/^tuerk$/,'tur').\nreplace(/^Türkisch$/,'tur').\nreplace(/^Ukrainisch$/,'ukr').\nreplace(/^ungar$/,'hun').\nreplace(/^Ungarisch$/,'hun')\n,x,x,null)).join('␟')",
      "onError": "set-to-blank",
      "newColumnName": "1500",
      "columnInsertIndex": 3
    },
    {
      "op": "core/text-transform",
      "engineConfig": {
        "facets": [],
        "mode": "row-based"
      },
      "columnName": "1500",
      "expression": "grel:forEachIndex(value.split('␟'),i,v,if(i != 0, if(inArray(value.split('␟')[0,i],v),null,v), v)).join('␟')",
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
            "name": "M|MEDNR",
            "expression": "isBlank(value)",
            "columnName": "M|MEDNR",
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
            "name": "1500",
            "expression": "isBlank(value)",
            "columnName": "1500",
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
      "columnName": "1500",
      "expression": "grel:'und'",
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

# Export der PICA3-Spalten als CSV
# Spalte 2199 muss vorne stehen, weil später für Sortierung benötigt
format="csv"
echo "export ${p} to ${format} file using template..."
IFS= read -r -d '' template << "TEMPLATE"
{{
with(
  [
    '2199',
    '0100',
    '0110',
    '0500',
    '1100a',
    '1100b',
    '1100n',
    '1140',
    '1500',
    '2000',
    '4000a',
    '7100j',
    '7100f',
    '7100a',
    '7100d',
    '8011',
    '8100',
    '8200',
    '8515',
    'E0XX',
    'E0XXb'
  ],
  columns,
  if(
    row.index == 0,
    forEach(
        columns,
        cn,
        cn.escape('csv')
      ).join(',')
      + '\n'
      + with(
        forEach(
          columns,
          cn,
          forNonBlank(
            cells[cn].value,
            v,
            v.escape('csv'),
            '␀'
          )
        ).join(',').replace('␀',''),
        r,
        if(
          isNonBlank(r.split(',').join(',')),
          r + '\n',
          ''
        )
      ),
    with(
      forEach(
        columns,
        cn,
        forNonBlank(
          cells[cn].value,
          v,
          v.escape('csv'),
          '␀'
        )
      ).join(',').replace('␀',''),
      r,
      if(
        isNonBlank(r.split(',').join(',')),
        r + '\n',
        ''
      )
    )
  )
)
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
