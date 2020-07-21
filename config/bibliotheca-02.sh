# Bibliotheca Hauptverarbeitung
# - Datenbereinigungen
# - Für PICA+ umformen
# - TSV und PICA+ (via Template) generieren

# ================================== CONFIG ================================== #

# TSV-Exporte aller Einzelprojekte in ein Zip-Archiv packen
zip -j "${workspace}/bibliotheca.zip" \
  "${workspace}/bautzen.tsv" \
  "${workspace}/breitenbrunn.tsv" \
  "${workspace}/dresden.tsv" \
  "${workspace}/glauchau.tsv" \
  "${workspace}/plauen.tsv"

projects["bibliotheca"]="${workspace}/bibliotheca.zip"

# ================================= STARTUP ================================== #

refine_start; echo

# ================================== IMPORT ================================== #

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
  > "${workspace}/${p}.id"
then
  log "imported ${projects[$p]} as ${p}"
else
  error "import of ${projects[$p]} failed!"
fi
refine_store "${p}" "${workspace}/${p}.id" || error "import of ${p} failed!"
echo

# ================================ TRANSFORM ================================= #

# --------------------------- 01 Spalten sortieren --------------------------- #

# damit Records-Mode erhalten bleibt
# - M|MEDGR > Facet > Text facet > eBook
# -- show as: records
# --- All > Edit rows > Remove all matching rows

echo "Spalten sortieren: Beginnen mit 1. M|MEDNR, 2. E|EXNR, 3. File"
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

# ----------------------- 02 E-Books löschen (Bautzen) ----------------------- #

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

# ------------- 03 Zeitschriften löschen (Breitenbrunn, Dresden) ------------- #

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

# ----------------------- 04 Makulierte Medien löschen ----------------------- #

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

# ---------------------------------- 05 0100 --------------------------------- #

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

# ---------------------------------- 06 2199 --------------------------------- #

# spec_B_T_49
# TODO: Titeldaten ohne Exemplare
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
      "expression": "grel:'BA' + cells['E|ZWGST'].value + value",
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

# --------------------------------- 07 7100B --------------------------------- #

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
      "baseColumnName": "E|ZWGST",
      "expression": "grel:value.replace('BB','Brt 1').replace('BZ','Bn 3').replace('DD','D 161').replace('EH','D 275').replace('GC','Gla 1').replace('PL','Pl 11')",
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

# ================================== EXPORT ================================== #

# ------------------------------------ TSV ----------------------------------- #

format="tsv"
echo "export ${p} to ${format} file..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data format="${format}" \
  --data engine='{"facets":[],"mode":"row-based"}' \
  "${endpoint}/command/core/export-rows" \
  > "${workspace}/${p}.${format}"
then
  log "exported ${p} (${projects[$p]}) to ${workspace}/${p}.${format}"
else
  error "export of ${p} (${projects[$p]}) failed!"
fi
echo

# ----------------------------------- PICA+ ---------------------------------- #

format="pic"
echo "export ${p} to pica+ file using template..."
IFS= read -r -d '' template << "TEMPLATE"
{{
if(row.index - row.record.fromRowIndex == 0, '' + '\n', '')
}}{{
forNonBlank(cells['0100'].value, v, '003@' + ' 0' + v + '\n', '')
}}{{
forNonBlank(cells['2199'].value, v, '006Y' + ' 0' + v + '\n', '')
}}{{
if(isNonBlank(cells['E|EXNR'].value), '209A/' + with(rowIndex - row.record.fromRowIndex + 1, i, '00'[0,2-i.length()] + i) + ' B' + cells['7100B'].value + 'f' + cells['E|ZWGST'].value + forNonBlank(cells['E|STA1'].value, v, 'a' + v, '') + 'x00' + '\n', '')
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
  > "${workspace}/${p}.${format}"
then
  log "exported ${p} (${projects[$p]}) to ${workspace}/${p}.${format}"
else
  error "export of ${p} (${projects[$p]}) failed!"
fi
echo

# ================================== FINISH ================================== #

refine_stop; echo
