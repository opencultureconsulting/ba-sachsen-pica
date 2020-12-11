#!/bin/bash
# Scripte zur Transformation von Bibliotheca und Alephino nach PICA+

# check and install requirements for bash-refine
source "${BASH_SOURCE%/*}/bash-refine.sh" || exit 1
requirements

# download task runner
task="$(readlink -m "${BASH_SOURCE%/*}/lib/task")"
if [[ -z "$(readlink -e "${task}")" ]]; then
  echo "Download task..."
  mkdir -p "$(dirname "${task}")"
  curl -L --output task.tar.gz \
    "https://github.com/go-task/task/releases/download/v3.0.0/task_linux_amd64.tar.gz"
  tar -xzf task.tar.gz -C "$(dirname "${task}")" task --totals
  rm -f task.tar.gz
fi

# make script executable from another directory
cd "${BASH_SOURCE%/*}/" || exit 1

# create folders
"${task}" mkdir

# execute default task (cf. Taskfile.yml)
"${task}"
