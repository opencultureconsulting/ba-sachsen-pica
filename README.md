# Transformation von Bibliotheca und Alephino nach PICA+ für die Bibliotheken der Berufsakademie Sachsen

## Vorbereitung

1. Exporte bereitstellen mit folgenden Dateinamen:
    * alephino/input/leipzig-exemplare.txt
    * alephino/input/leipzig-titel.txt
    * alephino/input/riesa-exemplare.txt
    * alephino/input/riesa-titel.txt
    * bibliotheca/input/bautzen.imp
    * bibliotheca/input/breitenbrunn.imp
    * bibliotheca/input/dresden.imp
    * bibliotheca/input/glauchau.imp
    * bibliotheca/input/plauen.imp
    
2. Installation Task 3.2.2

    a) RPM-based (Fedora, CentOS, SLES, etc.)

    ```sh
    wget https://github.com/go-task/task/releases/download/v3.2.2/task_linux_amd64.rpm
    sudo dnf install ./task_linux_amd64.rpm && rm task_linux_amd64.rpm
    ```

    b) DEB-based (Debian, Ubuntu etc.)

    ```sh
    wget https://github.com/go-task/task/releases/download/v3.2.2/task_linux_amd64.deb
    sudo apt install ./task_linux_amd64.deb && rm task_linux_amd64.deb
    ```

3. Installation OpenRefine 3.4.1 und openrefine-client 0.3.10

    ```
    task install
    ```

## Nutzung

Datenverarbeitung sequentiell

```
task default
```

Datenverarbeitung (teil)parallelisiert (benötigt bis zu 16 GB RAM)

```
task pica+:main
```

Analyse dubletter Barcodes

```
task barcodes:main
```

## Hinweise

* Ursprünglich war eine Zusammenführung der Daten aus Bibliotheca und Alephino bei der Datenmigration geplant. Der Task "pica+" ist dafür ausgelegt, aber wurde letztlich nur für Bibliotheca genutzt. Für Alephino erfolgt der Export in pica+ direkt im Job "Alephino" ohne Zwischenschritt.

## Systemvoraussetzungen

* GNU/Linux (getestet auf Fedora 32)
* JAVA 8+ (für OpenReifne)
* 8 GB freien Arbeitsspeicher

## Verwendete Tools

* [OpenRefine](https://openrefine.org/)
* [openrefine-client](https://github.com/opencultureconsulting/openrefine-client)
* [Task](https://github.com/go-task/task)
