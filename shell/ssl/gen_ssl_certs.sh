#!/usr/bin/env bash

set -e

ROOT_DOMAIN=$1
SYS_DOMAIN=sys.$ROOT_DOMAIN
APPS_DOMAIN=apps.$ROOT_DOMAIN

DOMAIN_DIR="${ROOT_DOMAIN}_cert"
SSL_FILE=sslconf-${ROOT_DOMAIN}.conf

[ ! -d "${DOMAIN_DIR}" ] && mkdir "${DOMAIN_DIR}"
cd "${DOMAIN_DIR}"

#Generate SSL Config with SANs
if [ ! -f $SSL_FILE ]; then
  cat > $SSL_FILE <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
[req_distinguished_name]
countryName_default = CN
stateOrProvinceName_default = ShangHai
localityName_default = ShangHai
organizationalUnitName_default = Devops
[ v3_req ]
# Extensions to add to a certificate request
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${ROOT_DOMAIN}
DNS.2 = *.${ROOT_DOMAIN}
DNS.3 = *.${SYS_DOMAIN}
DNS.4 = *.${APPS_DOMAIN}
EOF
fi

openssl genrsa -out RootCA.key 4096
openssl req -new -x509 -days 3650 -key RootCA.key -out RootCA.pem -subj "/C=CN/O=ShangHai/OU=IT/CN=ROOT-CN"

openssl genrsa -out ${ROOT_DOMAIN}.key 2048
openssl req -new -out ${ROOT_DOMAIN}.csr -subj "/CN=*.${ROOT_DOMAIN}/O=Devops/C=CN" -key ${ROOT_DOMAIN}.key -config ${SSL_FILE}
openssl x509 -req -days 3650 -CA RootCA.pem -CAkey RootCA.key -set_serial 01 -in ${ROOT_DOMAIN}.csr -out ${ROOT_DOMAIN}.crt -extensions v3_req -extfile ${SSL_FILE}
openssl x509 -in ${ROOT_DOMAIN}.crt -text -noout

cat ${ROOT_DOMAIN}.crt RootCA.pem > ${ROOT_DOMAIN}_fullchain.pem
openssl dhparam -out dhparam.pem 2048

rm ${ROOT_DOMAIN}.csr
