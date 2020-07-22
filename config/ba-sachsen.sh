# Generierung PICA+ aus CSV-Exporten

# ================================== CONFIG ================================== #

# TODO: Zusammenführung mit Alephino
zip -j "${workspace}/ba-sachsen.zip" \
  "${workspace}/bibliotheca.csv"

projects["ba-sachsen"]="${workspace}/ba-sachsen.zip"

# ================================= STARTUP ================================== #

refine_start; echo

# ================================== IMPORT ================================== #

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
  > "${workspace}/${p}.id"
then
  log "imported ${projects[$p]} as ${p}"
else
  error "import of ${projects[$p]} failed!"
fi
refine_store "${p}" "${workspace}/${p}.id" || error "import of ${p} failed!"
echo

# ================================ TRANSFORM ================================= #

# ------------------------ 01 PPN anreichern über ISBN ----------------------- #

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

# --------------------------- 02 Exemplare clustern -------------------------- #

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

# Export in PICA+
format="pic"
echo "export ${p} to pica+ file using template..."
IFS= read -r -d '' template << "TEMPLATE"
{{
if(row.index - row.record.fromRowIndex == 0,
'' + '\n'
+ forNonBlank(cells['0100'].value, v, '003@' + ' 0' + v + '\n', '')
+ forNonBlank(cells['2000'].value, v, forEach(v.split('␟'),x,'004A' + ' 0' + x + '\n').join(''), '')
+ forNonBlank(cells['2199'].value, v, '006Y' + ' 0' + v + '\n', '')
,'')
}}{{
if(isNonBlank(cells['7100f'].value),
with(with(rowIndex - row.record.fromRowIndex + 1, i, '00'[0,2-i.length()] + i),exnr,
'208@/' + exnr + ' a' + cells['E0XX'].value + 'bn' + cells['E0XXb'].value + '\n'
+ '209A/' + exnr + ' B' + cells['7100B'].value + 'f' + cells['7100f'].value + forNonBlank(cells['7100a'].value, v, 'a' + v, '') + 'x00' + '\n'
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
  > "${workspace}/${p}.${format}"
then
  log "exported ${p} (${projects[$p]}) to ${workspace}/${p}.${format}"
else
  error "export of ${p} (${projects[$p]}) failed!"
fi
echo

# ================================== FINISH ================================== #

refine_stop; echo
