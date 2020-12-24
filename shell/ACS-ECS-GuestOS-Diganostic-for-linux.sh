#!/bin/bash
set -u

LOG_DIR=/var/log/diagnostic
LOG_FILE_NAME="i-uf63gv6j947wbfm1zodq20201104165109"
LOG_FILE=${LOG_DIR}/${LOG_FILE_NAME}
OSS_URL=""
OS_RELEASE="aliyun"
OS_BIG_VERSION='2'

function check_fs() {
    echo "###fs-state"
	IFS_old=$IFS
	IFS=$'\n'
	for i in $(blkid)
	do
		blk=$(echo $i | awk -F: '{print $1}')
		fs_type=$(echo $i | egrep -o "TYPE=\"ext[0-9]\"|TYPE=\"xfs\"" | egrep -o "ext[0-9]|xfs")
		if [[ "${fs_type}" =~ "ext" ]]
		then
			echo ${blk}
			fsck -n /dev/vda1 > /dev/null 2>&1; echo $?
		elif [[ "${fs_type}" =~ "xfs" ]]
		then
			echo ${blk}
			xfs_repair -n ${blk} > /dev/null 2>&1 ; echo $?
		fi
	done
	IFS=$IFS_old
}

function get_os() {
    if ! test -f "/etc/os-release"; then
        if test -f "/etc/redhat-release"; then
            OS_RELEASE="centos"
        else
            OS_RELEASE="freebsd"
        fi


        match=$(awk -F'=' '/^VERSION_ID/ {gsub("\"","",$NF); print $NF}' /etc/os-release)
        OS_BIG_VERSION=${match%%.*}
    fi

    if grep "Ubuntu" "/etc/os-release"; then
        OS_RELEASE="ubuntu"
    fi

    if grep  "Debian" "/etc/os-release"; then
        OS_RELEASE="debian"
    fi

    if grep  "CentOS" "/etc/os-release"; then
        OS_RELEASE="centos"
    fi

    if grep  "SLES" "/etc/os-release"; then
        OS_RELEASE="suse"
    fi

    if grep -i "CoreOS" "/etc/os-release"; then
        OS_RELEASE="coreos"
    fi

    if grep  "Aliyun" "/etc/os-release"; then
        OS_RELEASE="aliyun"
    fi
}


function eth0_network_dhcp(){

    network_service_array=("Networking" "NetworkManager" "systemd-networkd" "netplan" "wicked" "others")
    network_service='${network_service[5]}'
    net_process_exit=false
    net_proto='static'

    #echo "***default"
    #mac=$(curl -s --connect-timeout 2 --fail 100.100.100.200/latest/meta-data/network/interfaces/macs/)
    #gateway=$(curl -s --connect-timeout 2 --fail 100.100.100.200/latest/meta-data/network/interfaces/macs/$mac/gateway)

    if [ "$OS_RELEASE"X == "centos"X ]; then
        echo "***centos"
        if [ "$OS_BIG_VERSION" == "7" ];then
            if [[ $(systemctl is-active  network.service) == 'active' ]];then
                network_service=${network_service_array[0]}
            elif [[ $(systemctl is-active NetworkManager) == 'active' ]];then
                network_service=${network_service_array[1]}
            elif [[ $(systemctl is-active systemd-networkd) == 'active' ]];then
                network_service=${network_service_array[2]}
            else
                network_service=${network_service_array[5]}
            fi
        elif [ "$OS_BIG_VERSION" == "8" ];then
            network_service=${network_service_array[1]}
        else
            network_service=${network_service_array[0]}
        fi

        net_proto=$(grep "^BOOTPROTO=" /etc/sysconfig/network-scripts/ifcfg-eth0 | awk -F'=' '{print $2}')
    elif [ "$OS_RELEASE"X == "aliyun"X ];then
        echo "***aliyun"
        network_service=${network_service_array[2]}
        systemd_dir=/etc/systemd/network/*.network
        for inet in `ls $systemd_dir`;
        do
            if grep -q "eth0" $inet && grep -q "DHCP=yes" $inet;then
                net_proto="dhcp"
                break
            fi
        done

    elif [ "$OS_RELEASE"X == "ubuntu"X ];then
        echo "***ubuntu"
        network_service=${network_service_array[2]}
        net_proto="static"
        if [ "$OS_BIG_VERSION" -ge 18 ];then
            net_dir=/etc/netplan/*.yaml
            for inet in `ls $netplan_dir`;
            do
                if grep -q "eth0" $inet && grep -q "dhcp4:[[:space:]]*yes" $inet;then
                    net_proto="dhcp"
                    break
                fi
            done
        else
            interface_cfg=/etc/network/interfaces
            if  grep -q "eth0[[:space:]]*inet[[:space:]]*dhcp" $interface_cfg;then
                net_proto="dhcp"
            fi
        fi
    elif [ "$OS_RELEASE"X == "debian"X ];then
        echo "***debian"
        network_service=${network_service_array[2]}
        net_proto='static'
        interface_cfg=/etc/network/interfaces
        if  grep -q "eth0[[:space:]]*inet[[:space:]]*dhcp" $interface_cfg;then
            net_proto="dhcp"
        fi
    elif [ "$OS_RELEASE"X == "suse"X ];then
        echo "***suse"
        network_service=${network_service_array[4]}
        net_proto='static'
        sysconfig_cfg=/etc/sysconfig/network/ifcfg-eth0
        if grep -qE "^BOOTPROTO='dhcp4'|^BOOTPROTO='dhcp'" $sysconfig_cfg;then
            net_proto='dhcp'
        fi
    else
        echo "network_service:unknow"
        echo "net_proto:unknow"
        echo "net_process:unknow"
        return

    fi

    if [[ $network_service == ${network_service_array[0]} ]];then
        process="dhclient"
    elif [[ $network_service == ${network_service_array[1]} ]];then
        process="NetworkManager"
    elif [[ $network_service == ${network_service_array[2]} ]];then
        process="systemd-networkd"
    elif [[ $network_service == ${network_service_array[4]} ]];then
        process="wickedd"
    fi

    ps aux |grep $process |grep -v grep >/dev/null
    if [[ $? == 0 ]];then
        net_process_exit=true
    fi

    echo "network_service:$network_service"
    echo "net_proto:$net_proto"
    echo "net_process_exit:$net_process_exit"
}

function get_configs() {
    echo "##*problem_total_analyse"

    # check  osinfo
    echo "###osinfo"
    if test -f "/etc/os-release"; then
        cat /etc/os-release | egrep "^NAME=|^VERSION="
    else
        echo "no os-release"
        echo "no os-release"
    fi
    if test -f "/etc/redhat-release" ; then
        echo "redhat-release:" $(cat /etc/redhat-release)
    else
        echo "no redhat-release"
    fi
    echo "uname: " $(uname -a)
    echo "uname short\: " $(uname -r)

    # check the passwd format
    echo "###dos-ff"
    elf_pas="`cat /etc/passwd | hexdump |head -n 2|head -n 1 |awk '{print $NF}'|cut -c 1-2`"
    elf_sha="`cat /etc/shadow | hexdump |head -n 2|head -n 1 |awk '{print $NF}'|cut -c 1-2`"
    #elf_pam="`cat /etc/pam.d/* | hexdump |head -n 2|head -n 1 |awk '{print $NF}'|cut -c 1-2`"
    if [ "elf_pas" != "3a" ];then
        echo "/etc/passwd: ASCII text"
    else
        echo "/etc/passwd: ASCII text, with no line terminators"
    fi
    if [ "elf_sha" != "3a" ];then
        echo "/etc/shadow: ASCII text"
    else
        echo "/etc/shadow: ASCII text, with no line terminators"
    fi

    # check the limits
    echo "###limits"
    cat /etc/security/limits.conf | grep -Ev "^$|[#;]"

    # check the virtio driver exists
    echo "###virtio-net-multiqueue"
    for i in $(ip link | grep -E "^[0-9]+: .*:" -o | cut -d ":" -f 2 | grep -v lo); do 
        echo $i 
        ethtool -l $i 2>/dev/null | grep Combined
    done

    # check eth0 newtork dhcp
    echo "###eth0-network-dhcp"
    eth0_network_dhcp


    # check passwd only
    echo "###passwd"
    cat /etc/passwd

    echo "###cpu-top-5"
    top -b -n 1 | grep "%Cpu(s):"
    ps -eT -o%cpu,pid,tid,ppid,comm | grep -v CPU | sort -n -r | head -5

    # check ssh permission format
    echo "###ssh-perm"
	if [ "$OS_RELEASE"X == "centos"X ]; then
        echo "***centos"
        ls -l /etc/passwd /etc/shadow /etc/group /etc/gshadow /var/empty/* /etc/securetty* /etc/security/* /etc/ssh/*
    fi

    if [ "$OS_RELEASE"X == "ubuntu"X ]; then
        echo "***ubuntu"
        ls -l /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/securetty* /etc/security/* /etc/ssh/*
    fi

    if [ "$OS_RELEASE"X == "debian"X ]; then
        echo "***debian"
        ls -l /etc/passwd /etc/shadow /etc/group /etc/gshadow /etc/securetty* /etc/security/* /etc/ssh/*
    fi
    if [ "$OS_RELEASE"X == "coreos"X ]; then
        echo "***coreos"
        ls -l /etc/passwd /etc/shadow /etc/group /etc/gshadow /var/empty/* /etc/securetty* /etc/security/* /etc/ssh/*
    fi
    
    # check blkid
    echo "###blkid"
    blkid
    
    # check the softlink
    echo "###softlink"
    ls -l / | grep "\->"

    # check iptables
    echo "###iptables"

    echo "***centos-5"
    service iptables status

    echo "***centos-6"
    service iptables status

    echo "***centos-7"
    firewall-cmd --state

    echo "***centos-8"
    firewall-cmd --state

    echo "***ubuntu"
    ufw status
    
    echo "***coreos"
    status="`systemctl status  iptables 2>&1`"
    echo "$status"

    echo "***default"
    iptables -L

    # check the sysctl configuration
    echo "###sysctl"
    cat /etc/sysctl.conf | grep nr_hugepages
    echo -n "net.ipv4.tcp_tw_recycle=" 
    cat /proc/sys/net/ipv4/tcp_tw_recycle
    echo -n "net.ipv4.tcp_timestamps="
    cat /proc/sys/net/ipv4/tcp_timestamps
    echo -n "fs.nr_open=" 
    cat /proc/sys/fs/nr_open
    echo -n "net.ipv4.tcp_sack=" && cat /proc/sys/net/ipv4/tcp_sack

    # check fstab configuration
    echo "###fstab"
    if [ "$OS_RELEASE"X == "coreos"X ]; then
        cat /etc/mtab | grep -v 'proc\|sys\|tmpfs\|securityfs\|cgroup\|devpts\|selinux\|debug\|mqueue\|huge\|pstore\|bpf'
    else
        cat /etc/fstab | grep -Ev "^$|[#;]"
    fi


    # check dmesg info
    echo "###dmesg"
    cat /proc/uptime
    dmesg | grep "invoked oom-killer" | tail -n 1

    # check the port usage
    # echo "###port-usage"
    # echo "***default"
    # netstat -tapn | grep LISTEN | grep -E 'sshd'
    # netstat -tapn | grep LISTEN | grep -E '0.0.0.0:80'
    # netstat -tapn | grep LISTEN | grep -E '0.0.0.0:443'
    # echo "***coreos"
    # #coreos sshd hosts by systemd 
    # netstat -tapn | grep LISTEN | grep -E 'systemd'
    # netstat -tapn | grep LISTEN | grep -E '0.0.0.0:80'
    # netstat -tapn | grep LISTEN | grep -E '0.0.0.0:443'

    # check if the selinux on
    echo "###selinux"
    echo "***default"
    getenforce

    echo "***ubuntu"
    service selinux status > /dev/null; echo $?
    echo "***debian-8"
    service selinux status > /dev/null; echo $?
    echo "***debian-9"
    sestatus | grep "SELinux status"
    echo "***debian-10"
    sestatus | grep "SELinux status"

    # check the memroy info
    echo "###meminfo"
    cat /proc/meminfo | grep Hugepagesize
    cat /proc/meminfo | grep MemTotal

    # check fs state
    check_fs

    # check sshd-config
    echo "###sshd-config"
    cat /etc/ssh/sshd_config | egrep "PermitRootLogin|AllowUsers|AllowGroups|DenyUsers|DenyGroups" | egrep -v "^$|[#;]"

    # check inode usage
    echo "###disk-inode"
    df -i | egrep "/dev/x?vd"
}


# upload logs to OSS
function upload() {
    cd $LOG_DIR
    curl -i -q  -X PUT -T ${LOG_FILE} ${OSS_URL}
}

function rmlog() {
	test -f ${LOG_FILE} && rm -f ${LOG_FILE}
} 

function main() {
    test -e ${LOG_DIR} || mkdir -p ${LOG_DIR}
    get_os
    get_configs >${LOG_FILE} 2>&1
    upload
}

main "$@"