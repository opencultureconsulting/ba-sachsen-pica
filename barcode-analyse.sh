#!/bin/bash
# Ermitteln von Dubletten in Barcodes

mkdir -p output output/barcodes

# Bibliotheca Barcodes extrahieren
for f in input/*.imp; do
  grep '^\*I BARCO ' "$f" | dos2unix | cut -c 10- > output/barcodes/"${f##*/}.txt"
done
# Alephino Barcodes extrahieren
for f in input/*-exemplare.txt; do
  grep '^120 ' "$f" | cut -c 6- > output/barcodes/"${f##*/}.txt"
done

# Dubletten ermitteln
sort output/barcodes/*.txt | uniq -d > output/barcodes/duplicates
(cd output/barcodes && for f in *.txt ; do
  grep -FxH -f duplicates "$f" | sort | join -o 2.1 -t ':' -a1 -2 2 duplicates - | cut -d '.' -f 1 > "${f}".tmp
done)
paste output/barcodes/duplicates output/barcodes/*.tmp | awk -F $'\t' '{sub($1, "\"&\""); print}' > output/barcodes/duplicates.tsv && rm output/barcodes/*.tmp
