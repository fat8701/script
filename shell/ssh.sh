SSH_PASSWORD="r00tme"
SSH_USER="root"
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

type sshpass || (echo "sshpass is not installed" && exit 1)

ssh_exec() {
    node=$1
    shift
    sshpass -p ${SSH_PASSWORD} ssh ${SSH_OPTIONS} ${SSH_USER}@${node} "$@"
}

scp_exec() {
    node=$1
    src=$2
    dst=$3
    sshpass -p ${SSH_PASSWORD} scp ${SSH_OPTIONS} ${2} ${SSH_USER}@${node}:${3}
}