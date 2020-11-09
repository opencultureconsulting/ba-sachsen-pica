#!/bin/bash
# bash-refine v1.3.4: bash-refine.sh, Felix Lohmeier, 2020-11-02
# https://gist.github.com/felixlohmeier/d76bd27fbc4b8ab6d683822cdf61f81d
# license: MIT License https://choosealicense.com/licenses/mit/

# TODO: support for macOS

# ================================== CONFIG ================================== #

endpoint="${REFINE_ENDPOINT:-http://localhost:3333}"
memory="${REFINE_MEMORY:-1400M}"
csrf="${REFINE_CSRF:-true}"
date="$(date +%Y%m%d_%H%M%S)"
if [[ -n "$(readlink -e "${REFINE_WORKDIR}")" ]]; then
  workdir="$(readlink -e "${REFINE_WORKDIR}")"
else
  workdir="$(readlink -m "${BASH_SOURCE%/*}/output/${date}")"
fi
if [[ -n "$(readlink -f "${REFINE_LOGFILE}")" ]]; then
  logfile="$(readlink -f "${REFINE_LOGFILE}")"
else
  logfile="$(readlink -m "${BASH_SOURCE%/*}/log/${date}.log")"
fi
if [[ -n "$(readlink -e "${REFINE_JQ}")" ]]; then
  jq="$(readlink -e "${REFINE_JQ}")"
else
  jq="$(readlink -m "${BASH_SOURCE%/*}/lib/jq")"
fi
if [[ -n "$(readlink -e "${REFINE_REFINE}")" ]]; then
  refine="$(readlink -e "${REFINE_REFINE}")"
else
  refine="$(readlink -m "${BASH_SOURCE%/*}/lib/openrefine/refine")"
fi

declare -A checkpoints # associative array for stats
declare -A pids # associative array for monitoring background jobs
declare -A projects # associative array for OpenRefine projects

# =============================== REQUIREMENTS =============================== #

function requirements {
  # check existence of java and cURL
  if [[ -z "$(command -v java 2> /dev/null)" ]] ; then
    echo 1>&2 "ERROR: OpenRefine requires JAVA runtime environment (jre)" \
      "https://openjdk.java.net/install/"
    exit 1
  fi
  if [[ -z "$(command -v curl 2> /dev/null)" ]] ; then
    echo 1>&2 "ERROR: This shell script requires cURL" \
      "https://curl.haxx.se/download.html"
    exit 1
  fi
  # download jq and OpenRefine if necessary
  if [[ -z "$(readlink -e "${jq}")" ]]; then
    echo "Download jq..."
    mkdir -p "$(dirname "${jq}")"
    # jq 1.4 has much faster startup time than 1.5 and 1.6
    curl -L --output "${jq}" \
      "https://github.com/stedolan/jq/releases/download/jq-1.4/jq-linux-x86_64"
    chmod +x "${jq}"; echo
  fi
  if [[ -z "$(readlink -e "${refine}")" ]]; then
    echo "Download OpenRefine..."
    mkdir -p "$(dirname "${refine}")"
    curl -L --output openrefine.tar.gz \
      "https://github.com/OpenRefine/OpenRefine/releases/download/3.4/openrefine-linux-3.4.tar.gz"
    echo "Install OpenRefine in subdirectory $(dirname "${refine}")..."
    tar -xzf openrefine.tar.gz -C "$(dirname "${refine}")" --strip 1 --totals
    rm -f openrefine.tar.gz
    # do not try to open OpenRefine in browser
    sed -i '$ a JAVA_OPTIONS=-Drefine.headless=true' \
      "$(dirname "${refine}")"/refine.ini
    # set min java heap space to allocated memory
    sed -i 's/-Xms$REFINE_MIN_MEMORY/-Xms$REFINE_MEMORY/' \
      "$(dirname "${refine}")"/refine
    # set autosave period from 5 minutes to 25 hours
    sed -i 's/#REFINE_AUTOSAVE_PERIOD=60/REFINE_AUTOSAVE_PERIOD=1500/' \
      "$(dirname "${refine}")"/refine.ini
    echo
  fi
}

# ============================== OPENREFINE API ============================== #

function refine_start {
  echo "start OpenRefine server..."
  local dir
  dir="$(readlink -e "${workdir}")"
  ${refine} -v warn -m "${memory}" -p "${endpoint##*:}" -d "${dir}" &
  pid_server=${!}
  timeout 30s bash -c "until curl -s \"${endpoint}\" \
    | cat | grep -q -o 'OpenRefine' ; do sleep 1; done" \
    || error "starting OpenRefine server failed!"
}

function refine_stats {
  # print server load
  ps -o start,etime,%mem,%cpu,rss -p "${pid_server}"
}

function refine_kill {
  # kill OpenRefine immediately; SIGKILL (kill -9) prevents saving projects
  { kill -9 "${pid_server}" && wait "${pid_server}"; } 2>/dev/null
  # delete temporary OpenRefine projects
  (cd "${workdir}" && rm -rf ./*.project* && rm -f workspace.json)
}

function refine_check {
  if grep -i 'exception\|error' "${logfile}"; then
    error "log contains warnings!"
  else
    log "checked log file, all good!"
  fi
}

function refine_stop {
  echo "stop OpenRefine server and print server load..."
  refine_stats
  echo
  refine_kill
  echo "check log for any warnings..."
  refine_check
}

function refine_csrf {
  # get CSRF token (introduced in OpenRefine 3.3)
  if [[ "${csrf}" = true ]]; then
      local response
      response=$(curl -fs "${endpoint}/command/core/get-csrf-token")
      if [[ "${response}" != '{"token":"'* ]]; then
        error "getting CSRF token failed!"
      else
        echo "?csrf_token=$(echo "$response" | cut -d \" -f 4)"
      fi
  fi
}

function refine_store {
  # check and store project id from import in associative array projects
  if [[ $# = 2 ]]; then
    projects[$1]=$(cut -d '=' -f 2 "$2")
  else
    error "invalid arguments supplied to import function!"
  fi
  if [[ "${#projects[$1]}" != 13 ]]; then
    error "returned project id is not valid!"
  else
    rm "$2"
  fi
  # check if project contains at least one row (may be skipped to gain ~40ms)
  local rows
  rows=$(curl -fs --get \
    --data project="${projects[$1]}" \
    --data limit=0 \
    "${endpoint}/command/core/get-rows" \
    | tr "," "\n" | grep total | cut -d ":" -f 2)
  if [[ "$rows" = "0" ]]; then
    error "imported project contains 0 rows!"
  fi
}

# ============================ SCRIPT ENVIRONMENT ============================ #

function log {
  # log status message
  echo "$(date +%H:%M:%S.%3N) [                   client] $1"
}

function error {
  # log error message and exit
  echo 1>&2 "ERROR: $1"
  refine_kill; pkill -P $$; exit 1
}

function monitor {
  # store pid of last execution
  pids[$1]="$!"
}

function monitoring {
  # wait for stored pids, remove them from array and check log for errors
  for pid in "${!pids[@]}"; do
    wait "${pids[$pid]}" \
    || error "${pid} (${projects[$pid]}) failed!" \
    && unset pids["$pid"]
  done
  refine_check
}

function checkpoint {
  # store timestamp in associative array checkpoints and print checkpoint
  checkpoints[$1]=$(date +%s.%3N)
  printf '%*.*s %s %*.*s\n' \
    0 "$(((80-2-${#1})/2))" "$(printf '%0.1s' ={1..40})" \
    "${#checkpoints[@]}. $1" \
    0 "$(((80-1-${#1})/2))" "$(printf '%0.1s' ={1..40})"
}

function checkpoint_stats {
  # calculate run time based on checkpoints
  local k keys values i diffsec
  echo "starting time and run time (hh:mm:ss) of each step..."
  # sort keys by value and store in array key
  readarray -t keys < <(
    for k in "${!checkpoints[@]}"; do
      echo "${checkpoints[$k]}:::$k"
    done | sort | awk -F::: '{print $2}')
  # remove milliseconds from corresponding values and store in array values
  readarray -t values < <(
    for k in "${keys[@]}" ; do
      echo "${checkpoints[$k]%.*}"
    done)
  # add final timestamp for calculation
  values+=("$(date +%s)")
  # calculate and print run time for each step
  for i in "${!keys[@]}"; do
    diffsec=$(( values[$((i + 1))] - values[i] ))
    printf "%35s %s %s %s\n" "${keys[$i]}" "($((i + 1)))" \
      "$(date -d @"${values[$i]}")" \
      "($(date -d @${diffsec} -u +%H:%M:%S))"
  done
  # calculate and print total run time
  diffsec=$(( values[${#keys[@]}] - values[0] ))
  printf "%80s\n%80s\n" "----------" "($(date -d @${diffsec} -u +%H:%M:%S))"
}

function count_output {
  # word count on all files in workdir
  echo "files (number of lines / size in bytes) in ${workdir}..."
  (cd "${workdir}" && wc -c -l ./*)
}

function init {
  # check requirements and download software if necessary
  requirements
  # set trap, create directories and tee to log file
  trap 'error "script interrupted!"' HUP INT QUIT TERM
  mkdir -p "${workdir}" "$(dirname "${logfile}")"
  exec &> >(tee -i -a "${logfile}")
}
