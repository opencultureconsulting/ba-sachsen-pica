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

# -------------------------- 01 Spalte File ans Ende ------------------------- #

# damit Records-Mode erhalten bleibt
# - M|MEDGR > Facet > Text facet > eBook
# -- show as: records
# --- All > Edit rows > Remove all matching rows

echo "Spalte File ans Ende..."
if curl -fs \
  --data project="${projects[$p]}" \
  --data-urlencode "operations@-" \
  "${endpoint}/command/core/apply-operations$(refine_csrf)" > /dev/null \
  << "JSON"
  [
    {
      "op": "core/column-move",
      "columnName": "File",
      "index": 132,
      "description": "Move column File to position 132"
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

# ---------------------------- 05 Bibliothekssigel --------------------------- #

echo "Bibliothekssigel..."
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
      "newColumnName": "sigel",
      "columnInsertIndex": 37
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
if(isNonBlank(cells['M|MEDNR'].value), '' + '\n', '')
}}{{
forNonBlank(cells['M|ART'].value, v, '002@' + ' 0' + v + 'au' + '\n', '')
}}{{
forNonBlank(cells['M|IDNR'].value, v, '003@' + ' 0' + v + '\n', '')
}}{{
forNonBlank(cells['E|ZWGST'].value, v, '006Y' + ' 0' + 'BA' + v + cells['M|MEDNR'].value + '\n', '')
}}{{
forNonBlank(cells['E|BARCO'].value, v, '209A/' + with(rowIndex - row.record.fromRowIndex + 1, i, '00'[0,2-i.length()] + i) + ' B' + cells['sigel'].value + 'f' + cells['E|ZWGST'].value + 'a' + cells['E|STA1'].value + 'x00' + '\n', '')
}}{{
forNonBlank(cells['E|BARCO'].value, v, '209G/' + with(rowIndex - row.record.fromRowIndex + 1, i, '00'[0,2-i.length()] + i) + ' a' + v + '\n', '')
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
