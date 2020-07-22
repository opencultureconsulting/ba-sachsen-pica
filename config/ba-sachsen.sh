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

# --------------------------- 01 Exemplare clustern -------------------------- #

# TODO
# spec_Z_07

# ================================== EXPORT ================================== #

# Export in PICA+
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
if(isNonBlank(cells['7100f'].value), '209A/' + with(rowIndex - row.record.fromRowIndex + 1, i, '00'[0,2-i.length()] + i) + ' B' + cells['7100B'].value + 'f' + cells['7100f'].value + forNonBlank(cells['209Aa'].value, v, 'a' + v, '') + 'x00' + '\n', '')
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
