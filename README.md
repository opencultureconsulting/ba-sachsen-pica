# Transformation von Bibliotheca und Alephino nach PICA+

1. Exporte bereitstellen mit folgenden Dateinamen:
    * input/bautzen.imp
    * input/breitenbrunn.imp
    * input/dresden.imp
    * input/glauchau.imp
    * input/leipzig-exemplare.txt
    * input/leipzig-titel.txt
    * input/plauen.imp
    * input/riesa-exemplare.txt
    * input/riesa-titel.txt
2. Datenverarbeitung: `./main.sh`
3. Ergebnisse prüfen: `wc -l output/*/*.tsv`
