# Alephino Vorverarbeitung
# - Exporte der fünf Standorte importieren
# - in Tabellenformat umwandeln
# - als eine Datei exportieren







# Alephino
for i in leipzig riesa; do
    echo "===== ${i} ====="
    date
    openrefine/openrefine-client -P ${port} --create input/${i}-titel.txt --format=fixed-width --columnWidths=5 --columnWidths=1000000 --storeBlankRows=false --encoding=UTF-8 --projectName=${i}-titel
    openrefine/openrefine-client -P ${port} --create input/${i}-exemplare.txt --format=fixed-width --columnWidths=5 --columnWidths=1000000 --storeBlankRows=false --encoding=UTF-8 --projectName=${i}-exemplare
    openrefine/openrefine-client -P ${port} --apply config/alephino-01-titel.json ${i}-titel
    openrefine/openrefine-client -P ${port} --apply config/alephino-01-exemplare-${i}.json ${i}-exemplare
    openrefine/openrefine-client -P ${port} --export --output${workspace}/${date}/${i}.tsv ${i}-exemplare
    echo ""
done
