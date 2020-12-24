#!/bin/env bash
###################################################################
#Script Name	:
#Description	:
#Args           : 
#Update Date    :
#Author       	: lework
#Email         	: lework@yeah.net
###################################################################

set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline


######################################################################################################
# environment configuration
######################################################################################################


TAG="CMD"
LOG_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/logs"
LOG_FILE="$LOG_PATH/example_`date +"%Y%m%d"`.log"
HIDE_LOG=true



######################################################################################################
# function
######################################################################################################


function log() {
    [ ! -d "$LOG_PATH" ] && mkdir -p $LOG_PATH
    if [ $HIDE_LOG ]; then
        echo -e "[`date +"%Y/%m/%d:%H:%M:%S %z"`] [`whoami`] [$TAG] $@" >> $LOG_FILE
    else
        echo "[`date +"%Y/%m/%d:%H:%M:%S %z"`] [`whoami`] [$TAG] $@" | tee -a $LOG_FILE
    fi
}

function script_trap_err() {
    local exit_code=1

    # Disable the error trap handler to prevent potential recursion
    trap - ERR

    # Consider any further errors non-fatal to ensure we run to completion
    set +o errexit
    set +o pipefail

    log "[E] ERROR"

    exit "$exit_code"
}

function script_trap_exit() {
    log "[I] shell exec done."
}

function main() {
    trap script_trap_err ERR
    trap script_trap_exit EXIT

    log "[I] shell start"

}

######################################################################################################
# main 
######################################################################################################


main "${@}"
