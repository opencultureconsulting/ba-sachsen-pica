#!/bin/bash
# Scripte zur Transformation von Bibliotheca und Alephino nach PICA+

# ================================ ENVIRONMENT =============================== #

# make script executable from another directory
cd "${BASH_SOURCE%/*}/" || exit 1

# source the main script
source bash-refine.sh

# override default config
memory="8G"

# check requirements, set trap, create workspace and tee to logfile
init

# ================================= WORKFLOW ================================= #

checkpoint "Bibliotheca Vorverarbeitung"; echo
source config/bibliotheca-01.sh

checkpoint "Bibliotheca Hauptverarbeitung"; echo
source config/bibliotheca-02.sh

# ================================= STATS ================================= #

# calculate run time based on checkpoints
checkpoint_stats; echo

# word count on all files in workspace
count_output
