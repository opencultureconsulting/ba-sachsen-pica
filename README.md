# Transformation von Bibliotheca und Alephino nach PICA+ für die Bibliotheken der Berufsakademie Sachsen

## Nutzung

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
2. Installation und initiale Datenverarbeitung: `./main.sh`
3. Weitere Datenverarbeitungen:
    * `lib/task` um den gesamten Workflow zu starten
    * `lib/task --list` für eine Liste der verfügbaren Tasks

## Systemvoraussetzungen

* Linux mit Bash, cURL und JAVA (getestet auf Fedora 32)
* 7 GB freien Arbeitsspeicher

## Verwendete Tools

* [OpenRefine](https://openrefine.org/)
* [bash-refine](https://gist.github.com/felixlohmeier/d76bd27fbc4b8ab6d683822cdf61f81d)
* [Task](https://github.com/go-task/task)
