#!/bin/bash
# Scripte zur Transformation von Bibliotheca und Alephino nach PICA+

# download task if necessary
task="$(readlink -m "${BASH_SOURCE%/*}/lib/task")"
if [[ -z "$(readlink -e "${task}")" ]]; then
  echo "Download task..."
  mkdir -p "$(dirname "${task}")"
  curl -L --output task.tar.gz \
    "https://github.com/go-task/task/releases/download/v3.0.0-preview4/task_linux_amd64.tar.gz"
  tar -xzf task.tar.gz -C "$(dirname "${task}")" task --totals
  rm -f task.tar.gz
fi

# execute default task (cf. Taskfile.yml)
"${task}"
