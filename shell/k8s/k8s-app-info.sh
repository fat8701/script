#!/usr/bin/env bash
###################################################################
#Script Name	: k8s_app_info.sh
#Description	: get app info.
#Create Date    : 2020-11-19
#Author       	: lework
#Email         	: lework@yeah.net
###################################################################


[[ -n $DEBUG ]] && set -x || true
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline


######################################################################################################
# environment configuration
######################################################################################################

NAMESPACE="${NAMESPACE:-default}"
APPNAME="${APPNAME:-}"
SELECTOR="${SELECTOR:-}"
INFO_FILE="k8s-app-info_$(date +%s).md"

######################################################################################################
# function
######################################################################################################

function log::echo {
  local code=$1
  local space=$2
  local text=$3
  [[ "$code" == "0" ]] && code=32 || { code=31; text="ERROR"; }
  echo -e "\033[0;${code}m  $(head -c $((12-${space})) /dev/zero |tr '\0' '.')........................  ${text}\033[0m"

}

function file::write {
  printf "%s\n" "$*" >> $INFO_FILE
}

function exec::kubectl {
  local result
  local code

  result="$(kubectl -n $NAMESPACE $* 2>/dev/null)"
  code="$?"
  if [[ "$code" == "0" ]]; then
  file::write "
\`\`\`bash
# kubectl -n $NAMESPACE $*
${result}
\`\`\`"
  fi
  return "$code"
}


function get::selector {
  echo -ne "Get Selector"
  if [[ "${SELECTOR}" == "" ]]; then
    selflink=$(kubectl -n $NAMESPACE get deployment $APPNAME -o yaml --ignore-not-found 2>/dev/null | awk '/selfLink:/ {print $2}')
    SELECTOR=$(kubectl get --raw "${selflink}/scale" 2>/dev/null | sed 's/.*selector":"\(.*\)".*/\1/g')
  fi

  if [[ "${SELECTOR}" == "" ]]; then
   resource="service job cronjob replicaset daemonset statefulset"
   for r in $resource
   do
     SELECTOR=$(kubectl -n kube-system get ${r} ${APPNAME} --ignore-not-found --show-labels --no-headers 2>/dev/null | awk '{print $NF}' | grep -v '<none>' |head -1)
     if [[ "${SELECTOR}" != "" ]]; then break;fi
   done
  fi

  if [[ "${SELECTOR}" == "" ]]; then
    echo -e "\n\033[0;31m[Error] not found $APPNAME selector.\033[0m"
    exit 1
  fi
  file::write "
# [INFO]
namespace: \`${NAMESPACE}\`$(if [[ "$APPNAME" != "" ]];then echo -e "\nname: \`${APPNAME}\`";fi)
selector: \`${SELECTOR}\`
"
   log::echo "0" "8" "OK"
}

function get::describe {
   control=$1
  
   echo -ne "Get ${control^}"
   file::write "# [${control^}]"
   names=$(kubectl -n $NAMESPACE get $control -l "$SELECTOR" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}')

   [[ "$names" == "" && "$APPNAME" != "" ]] && names=$(kubectl -n $NAMESPACE get $control $APPNAME --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}')
  
   for i in $names; do
     file::write "## $i"
     exec::kubectl describe $control $i
     exec::kubectl get $control $i -o yaml
   done
   log::echo "$?" "${#control}" "$(echo $names | wc -w)"
}

function get::pods_log {
   echo -ne "Get Pod log"
   file::write "# [Pod Log]"
   names=$(kubectl -n $NAMESPACE get pods -l "$SELECTOR" --no-headers --ignore-not-found 2>/dev/null | awk '{print $1}' 2>/dev/null)
   log::echo "$?" "7" "$(echo $names | wc -w)"
   for i in $names; do
     echo "Get Pod: $i"
     file::write "## $i"
     exec::kubectl logs --tail 200 $i --all-containers
   done
}

function get::k8s_event {
   echo -ne "Get k8s Event"
   file::write "# [Event]"
   exec::kubectl get event
   log::echo "$?" "9" "OK"
}

function get::cluster {
   echo -ne "Get Cluster"
   file::write "# [Cluster]"
   exec::kubectl top node
   log::echo "$?" "7" "OK"
}


function get::info {
  get::selector
 
  get::describe ingress
  get::describe service
  get::describe endpoints
  get::describe deployment
  get::describe replicaset
  get::describe daemonset
  get::describe cronjob
  get::describe job
  get::describe pod
  get::describe configmaps
  get::describe secrets
  get::describe pvc
  get::describe pv
  get::pods_log
  get::k8s_event
  get::cluster
 
}
 
function help::usage {
  # 使用帮助
  
  cat << EOF

Get k8s app info.

Usage:
  $(basename $0) [flag]
  
Flag:
  -ns,--namespace  namespace
  -n,--name        name
  -l,--selector    selector
EOF

 exit 1
}
 
 ######################################################################################################
# main
######################################################################################################


[ "$#" == "0" ] && help::usage || true

while [ "${1:-}" != "" ]; do
  case $1 in
    -ns | --namespace )     shift
                            NAMESPACE=${1:-$NAMESPACE}
                            ;;
    -n  | --name )          shift
                            APPNAME=${1:-$APPNAME}
                            ;;
    -l | --selector )       shift
                            SELECTOR=${1:-$SELECTOR}
                            ;;
    * )                     help::usage
  esac
  shift
done

[[ "${APPNAME}" == "" && "${SELECTOR}" == "" ]] && help::usage
[ -f "${INFO_FILE}" ] && rm -f "${INFO_FILE}" 

get::info
echo -e "\nFile: ${INFO_FILE}"
