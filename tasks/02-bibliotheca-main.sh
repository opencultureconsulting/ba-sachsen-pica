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
# - M|MEDGR > Facet > Text facet > eBook
# -- show as: records
# --- All > Edit rows > Remove all matching rows

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
      "index": 0,
      "description": "Move column File to position 0"
    },
    {
      "op": "core/column-move",
      "columnName": "E|EXNR",
      "index": 0,
      "description": "Move column E|EXNR to position 0"
    },
    {
      "op": "core/column-move",
      "columnName": "M|MEDNR",
      "index": 0,
      "description": "Move column M|MEDNR to position 0"
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

# --------------- Zeitschriften löschen (Breitenbrunn, Dresden) -------------- #

# spec_Z_02
# - M|ART > Facet > Text facet > "Z" und "GH"
# -- show as: records
# --- All > Edit rows > Remove all matching rows

echo "Zeitschriften löschen (Breitenbrunn, Dresden)..."
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
# - E|EXSTA > Facet > Text facet > "M"
# -- show as: rows
# --- All > Edit rows > Remove all matching rows

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
            "expression": "value",
            "columnName": "E|EXSTA",
            "invert": false,
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

# ------------------------------------ 0100 ---------------------------------- #

# spec_B_T_01
# TODO: Aufteilung in 0100 / 0110 nach Nummernkreisen
# TODO: Korrekturen für <9 und >10-stellige
echo "K10plus-PPNs in 0100..."
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
                  "v": 9,
                  "l": "9"
                }
              },
              {
                "v": {
                  "v": 10,
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
      "baseColumnName": "M|IDNR",
      "expression": "grel:value",
      "onError": "set-to-blank",
      "newColumnName": "0100",
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

# ----------------------------------- 7100B ---------------------------------- #

# spec_B_E_15
echo "Bibliothekssigel 7100B..."
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
      "expression": "grel:with(if(value=='DD',forNonBlank(cells['E|ZWGST'].value,v,v,value),value),x,x.replace('BB','Brt 1').replace('BZ','Bn 3').replace('DD','D 161').replace('EH','D 275').replace('GC','Gla 1').replace('PL','Pl 11'))",
      "onError": "set-to-blank",
      "newColumnName": "7100B",
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

# spec_B_E_13
echo "Zweigstelle 7100f..."
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
      "expression": "grel:value.replace('␟',' ')",
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

# spec_B_E_14
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
          }
        ],
        "mode": "row-based"
      },
      "baseColumnName": "File",
      "expression": "grel:with(if(value=='DD',forNonBlank(cells['E|ZWGST'].value,v,v,value),value),x,x.toLowercase())",
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
  'Ban',
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

# ----------------------------------- 4000 ----------------------------------- #

# spec_B_T_17
echo "Haupttitel 4000..."
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
      "newColumnName": "4000",
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
echo "Verbuchungsnummer 4000..."
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
    '0500',
    '1100a',
    '1100n',
    '1140',
    '2000',
    '4000',
    '7100B',
    '7100f',
    '7100a',
    '8200',
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
