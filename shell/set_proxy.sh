#!/bin/bash
# 
# Author: lework
# Desc:   Set the proxy address of the software source.
# Date:   2020/03/10


set -o errexit          # Exit on most errors (see the manual)
set -o errtrace         # Make sure any error trap is inherited
set -o nounset          # Disallow expansion of unset variables
set -o pipefail         # Use last non-zero exit code in a pipeline


######################################################################################################
# environment configuration
######################################################################################################

OS=`cat /etc/*-release | grep '^ID=' | \
  sed 's/^ID=["]*\([a-zA-Z]*\).*$/\1/' | \
  tr '[:upper:]' '[:lower:]'`


PIP_PROXY="https://pypi.tuna.tsinghua.edu.cn/simple"
GEM_PROXY="https://gems.ruby-china.com/"
NODEJS_PROXY="https://registry.npm.taobao.org"
GO_PROXY="https://mirrors.aliyun.com/goproxy/"
DOCKER_CE_PROXY="mirrors.ustc.edu.cn"
DOCKER_HUB_PROXY="http://hub-mirror.c.163.com"
DOCKER_HTTP_PROXY=""
DOCKER_HTTPS_PROXY=""
CONTAINERD_HTTP_PROXY=""
CONTAINERD_HTTPS_PROXY=""
CENTOS_PROXY="mirrors.ustc.edu.cn"
DEBAIN_PROXY="mirrors.ustc.edu.cn"
DEBAIN_ARCHIVE_PROXY="http://mirrors.163.com/debian-archive"
UBUNTU_PROXY="mirrors.tuna.tsinghua.edu.cn"
ALPINE_PROXY="mirrors.aliyun.com"
KUBERNETES_PROXY="https://mirrors.aliyun.com"


######################################################################################################
# function
######################################################################################################

_get_proxy() {
 echo "SoftWare: ${FUNCNAME[1]}" >&2
 local proxy=${1:-${2:-}}
 while [ -z ${proxy} ]; do
   read -p "Input ${3:-}Proxy: " proxy
 done
 echo -e "Set: ${proxy}\n" >&2
 echo "${proxy}"
}


centos() {
local _proxy=$(_get_proxy ${1:-} $CENTOS_PROXY)

sed -e 's!^#baseurl=!baseurl=!g' \
       -e 's!^mirrorlist=!#mirrorlist=!g' \
       -e "s!mirror.centos.org!${_proxy}!g" \
       -i  /etc/yum.repos.d/CentOS-*.repo

yum install -y epel-release
sed -e 's!^mirrorlist=!#mirrorlist=!g' \
    -e 's!^#baseurl=!baseurl=!g' \
    -e 's!^metalink!#metalink!g' \
    -e "s!//download\.fedoraproject\.org/pub!//${_proxy}!g" \
    -i /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel-testing.repo
}

debian() {
local _proxy=$(_get_proxy ${1:-} $DEBAIN_PROXY)
sudo sed -i "s/deb.debian.org/${_proxy}/g" /etc/apt/sources.list
sudo apt-get update
}

debiani_archive() {
local _proxy=$(_get_proxy ${1:-} $DEBAIN_ARCHIVE_PROXY)
[ -f "/etc/apt/sources.list" ] && cp -f /etc/apt/sources.list{,-bak}
cat << EOF > /etc/apt/sources.list
deb ${_proxy}/debian/ wheezy main non-free contrib
deb ${_proxy}/debian/ wheezy-backports main non-free contrib
deb-src ${_proxy}/debian/ wheezy main non-free contrib
deb-src ${_proxy}/debian/ wheezy-backports main non-free contrib
deb ${_proxy}/debian-security/ wheezy/updates main non-free contrib
deb-src ${_proxy}/debian-security/ wheezy/updates main non-free contrib
EOF

sudo apt-get -o Acquire::Check-Valid-Until=false update
}

ubuntu() {
local _proxy=$(_get_proxy ${1:-} $UBUNTU_PROXY)
sudo sed -i "s/archive.ubuntu.com/${_proxy}/g" /etc/apt/sources.list
sudo apt-get update
}

alpine() {
local _proxy=$(_get_proxy ${1:-} $ALPINE_PROXY)
sed -i "s/dl-cdn.alpinelinux.org/${_proxy}/g" /etc/apk/repositories
}

easy_install() {
local _proxy=$(_get_proxy ${1:-} $PIP_PROXY)

cat <<EOF > ~/.pydistutils.cfg  
[easy_install]
index-url = ${_proxy}
EOF

}

pip() {
local _proxy=$(_get_proxy ${1:-} $PIP_PROXY)

local d=~/.pip
[ ! -d "${d}" ] && mkdir "${d}"

cat << EOF >  ${d}/pip.conf
[global]
index-url = ${_proxy}
EOF

easy_install ${_proxy}
}

ruby() {
local _proxy=$(_get_proxy ${1:-} $GEM_PROXY)
gem sources --add ${_proxy} --remove https://rubygems.org/
}

npm() {
local _proxy=$(_get_proxy ${1:-} $NODEJS_PROXY)
env npm config set registry ${_proxy}
}

yarn() {
local _proxy=$(_get_proxy ${1:-} $NODEJS_PROXY)
env yarn config set registry ${_proxy}
}

go() {
local _proxy=$(_get_proxy ${1:-} $GO_PROXY)
export GO111MODULE=on
export GOPROXY=${_proxy}

cat << EOF >> /etc/profile
export GO111MODULE=on
export GOPROXY=${_proxy}
EOF
}

docker-ce() {
local _proxy=$(_get_proxy ${1:-} $DOCKER_CE_PROXY)

case "$OS" in
  centos)
    curl -s -o /etc/yum.repos.d/docker-ce.repo https://${_proxy}/docker-ce/linux/centos/docker-ce.repo
    sed -i "s#download.docker.com#${_proxy}/docker-ce#g" /etc/yum.repos.d/docker-ce.repo
    yum makecache
    ;;
  debian)
    curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
    sudo add-apt-repository \
      "deb [arch=amd64] http://${_proxy}/docker-ce/linux/debian \
      $(lsb_release -cs) stable"
    sudo apt-get update
    ;;
  ubuntu)
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository \
       "deb [arch=amd64] https://${_proxy}/docker-ce/linux/ubuntu \
       $(lsb_release -cs) stable"
    sudo apt-get update
    ;;
  *)
    echo "不支持${OS}系统"
    ;;
esac
}


kubernetes() {
local _proxy=$(_get_proxy ${1:-} $KUBERNETES_PROXY)

case "$OS" in
  centos)
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=${_proxy}/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=${_proxy}/kubernetes/yum/doc/yum-key.gpg ${_proxy}/kubernetes/yum/doc/rpm-package-key.gpg
EOF
  ;;
  debian)
    apt-get update && apt-get install -y apt-transport-https
    curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
    cat << EOF >/etc/apt/sources.list.d/kubernetes.list
deb ${_proxy}/kubernetes/apt/ kubernetes-xenial main
EOF
    apt-get update
  ;;
  *)
    echo "不支持${OS}系统"
    ;;
esac
}


docker-hub() {
local _proxy=$(_get_proxy ${1:-} $DOCKER_HUB_PROXY)
local d=/etc/docker
[ ! -d "${d}" ] && mkdir ${d}
[ -f "${d}/daemon.json" ] && cp -f ${d}/daemon.json{,-bak}
cat > ${d}/daemon.json <<EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "3"
    },
    "live-restore": true,
    "max-concurrent-downloads": 10,
    "max-concurrent-uploads": 10,
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "exec-opts": ["native.cgroupdriver=systemd"],
    "registry-mirrors": [
        "${_proxy}"
    ]
}
EOF
systemctl restart docker
}

docker-http() {
local _http_proxy=$(_get_proxy ${1:-''} ${DOCKER_HTTP_PROXY:-''} "http ")
local _https_proxy=$(_get_proxy ${1:-''} ${DOCKER_HTTPS_PROXY:-''} "https ")

local d=/etc/systemd/system/docker.service.d
[ ! -d "${d}" ] && mkdir ${d}

cat << EOF > ${d}/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${_http_proxy}"
Environment="HTTPS_PROXY=${_https_proxy}"
EOF

systemctl daemon-reload
systemctl restart docker
}

containerd-hub() {
local _proxy=$(_get_proxy ${1:-} $DOCKER_HUB_PROXY)
# containerd config default > /etc/containerd/config.toml
sed -i "s#https://registry-1.docker.io#${_proxy}#g" /etc/containerd/config.toml
}

containerd-http() {
local _http_proxy=$(_get_proxy ${1:-''} ${CONTAINERD_HTTP_PROXY:-''} "http ")
local _https_proxy=$(_get_proxy ${1:-''} ${CONTAINERD_HTTPS_PROXY:-''} "https ")
local d=/etc/systemd/system/containerd.service.d
[ ! -d "${d}" ] && mkdir ${d}

cat << EOF > ${d}/http-proxy.conf
[Service]
Environment="HTTP_PROXY=${_http_proxy}"
Environment="HTTPS_PROXY=${_https_proxy}"
EOF

systemctl daemon-reload
systemctl restart containerd
}

podman() {
local _proxy=$(_get_proxy ${1:-} $DOCKER_HUB_PROXY)
local d=/etc/containers
[ ! -d "${d}" ] && mkdir ${d}
[ -f "${d}/registries.conf" ] && cp -f ${d}/registries.conf{,.bak}
cat << EOF > ${d}/registries.conf 
unqualified-search-registries = ["docker.io","quay.io"]

[[registry]]
prefix = "docker.io"
location = "${_proxy}"
EOF
}

_help() {
  cat <<EOM

Set the proxy address of the software source.
 
  Usage:
    $(basename $0) [[-p|--proxy] software] | [-l] | [-h]
      -p,--proxy      Specify proxy node url
      -l,--list       Supported software list 
      -h,--help       View help

  Example:
    $(basename $0) pip
    $(basename $0) -p http://mirrors.aliyun.com/pypi/simple pip
    $(basename $0) docker-hub
EOM
 exit 1

}

_list() {
  echo -e "\nSupported software list:\n"
  echo $FUNCS | sed 's/ /\n/g'
}

######################################################################################################
# main 
######################################################################################################
proxy=""

FUNCS=$(declare -F | cut -d ' ' -f3 | sort | grep -v -E '^_.*')

[ "$#" == "0" ] && _help


while [ "${1:-}" != "" ]; do
    case ${1} in
        -p | --proxy )          shift
                                proxy=${1}
                                ;;
         $([[ "${FUNCS[@]}" =~ "${1}" ]] && echo "*"))  ${1} ${proxy}; exit
                                ;;
        -l | --list )           _list
                                ;;
        -h | --help )           _help
                                ;;
        * )                     _help
    esac
    shift
done
