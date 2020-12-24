#!/bin/bash
# 
# Author: lework
# Desc:   Use cfssl tool to conveniently generate self-signed certificates.
# Date:   2020/07/01

set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline


######################################################################################################
# environment configuration
######################################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PLAIN='\033[0m'


CFSSL_VERSION="1.4.1"


######################################################################################################
# function
######################################################################################################

echo_title() {
  echo -e "${GREEN}$1${PLAIN}"
}

function check() {  
  for bin in cfssl cfssl-certinfo cfssljson
  do
    if ! $(command -v ${bin} > /dev/null 2>&1);then
      echo_title "[Installing] $bin..."
      curl -sSL https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/{$bin}_${CFSSL_VERSION}_linux_amd64 > /tmp/${bin}
      sudo install /tmp/${bin} /usr/local/bin/${bin}
    fi
  done
  
  if ! $(command -v openssl > /dev/null 2>&1);then
      echo_title "[Installing] openssl..."
      command -v yum > /dev/null 2>&1 && yum -y install openssl
      command -v apt-get > /dev/null 2>&1 && apt-get install openssl -y
  fi
}


function ca() {
  project=${1:-demo}
  server_hostname="${2:-server.${project}.com}"
  client_hostname="${3:-client.${project}.com}"
  
  [ ! -d "${project}_ca" ] && mkdir "${project}_ca"
  cd "${project}_ca"
  
  echo_title "\n[Generating] cfssl config..."
  cat << EOF > cfssl-config.json
{
    "signing": {
        "default": {
            "expiry": "87600h",
            "usages": [
                    "signing",
                    "digital signature",
                    "key encipherment",
                    "server auth",
                    "client auth"
            ]
        },
        "profiles": {
            "peer": {
                "expiry": "87600h",
                "usages": [
                    "signing",
                    "digital signature",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            },
            "server": {
                "expiry": "87600h",
                "usages": [
                    "signing",
                    "digital signature",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "87600h",
                "usages": [
                    "signing",
                    "digital signature",
                    "key encipherment",
                    "client auth"
                ]
            }
        }
    }
}
EOF

  echo_title "\n[Generating] ca csr..."
  cat << EOF > ca-csr.json
{
    "CN": "${project^^} CA",
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "${project}",
            "OU": "${project^^} Service"
        }
    ]
}
EOF

  echo_title "\n[Generating] csr..."
  cat << EOF > csr.json
{
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "CN",
            "ST": "Shanghai",
            "L": "Shanghai",
            "O": "${project}",
            "OU": "${project^^} Service"
        }
    ]
}
EOF
  
  echo_title "\n[Generating] certificate authority..."
  cfssl gencert -initca ca-csr.json | cfssljson -bare ca
  
  echo_title "\n[Generating] server certificate..."
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=cfssl-config.json \
		-hostname="${server_hostname},localhost,127.0.0.1" csr.json  \
		| cfssljson -bare server

  echo_title "\n[Generating] client certificate..."
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=cfssl-config.json \
		-hostname="${client_hostname},localhost,127.0.0.1" csr.json  \
		| cfssljson -bare client
        
  echo_title "\n[Generating] server and client node certificate..."
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=cfssl-config.json \
		-hostname="${server_hostname},${client_hostname},localhost,127.0.0.1" csr.json  \
		| cfssljson -bare dev
        
  echo_title "\n[Generating] user certificates..."
  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=cfssl-config.json \
		-profile=client csr.json  | cfssljson -bare user
  openssl pkcs12 -export -inkey user-key.pem -in user.pem -out user.pfx -password pass:

  echo_title "\n[Generating] The $(pwd) directory file list..."
  ls -al .
}


usage_help() {
  cat <<EOM

Use cfssl tool to conveniently generate self-signed certificates.
 
  Usage:
    $(basename $0) [ -h | --help ] [project_name server_hostname client_hostname]

  Example:
    $(basename $0)           # Generate demo self-signed certificate
    $(basename $0) -h        # View help.
    $(basename $0) project web-server.project.com,api-server.project.com rpc-client.project.com,api-client.project.com
EOM
 exit 1
}



######################################################################################################
# main 
######################################################################################################


case ${1-} in
    -h | --help )           usage_help
                            ;;
    * )                     check
                            ca $@
esac
