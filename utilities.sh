#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

source $DIR/text_input.sh
source $DIR/list_input.sh
source $DIR/checkbox_input.sh

set +e
base64_args=""
$(base64 --wrap=0 <(echo "test") >/dev/null 2>&1)
if [ $? -eq 0 ]; then
    base64_args="--wrap=0"
fi
set -e

control_c() {
  echo_completed "Exiting"
  stty sane
  tput cnorm
  stty echo
  exit $?
}

trap control_c SIGINT

_spinner() {
    local on_success=" Completed "
    local on_fail="  Failed   "
    local green
    local red
    green="$(tput setaf 2)"
    red="$(tput setaf 5)"
    nc="$(tput sgr0)"
    case $1 in
        start)
            let column=$(tput cols)-${#2}+10
            echo -ne ${2}
            printf "%${column}s"
            i=0
            sp=( "[$(echo -e '\xE2\x97\x8F')          ]"
                 "[ $(echo -e '\xE2\x97\x8F')         ]"
                 "[  $(echo -e '\xE2\x97\x8F')        ]"
                 "[   $(echo -e '\xE2\x97\x8F')       ]"
                 "[    $(echo -e '\xE2\x97\x8F')      ]"
                 "[     $(echo -e '\xE2\x97\x8F')     ]"
                 "[      $(echo -e '\xE2\x97\x8F')    ]"
                 "[       $(echo -e '\xE2\x97\x8F')   ]"
                 "[        $(echo -e '\xE2\x97\x8F')  ]"
                 "[         $(echo -e '\xE2\x97\x8F') ]"
                 "[          $(echo -e '\xE2\x97\x8F')]"
                 "[         $(echo -e '\xE2\x97\x8F') ]"
                 "[        $(echo -e '\xE2\x97\x8F')  ]"
                 "[       $(echo -e '\xE2\x97\x8F')   ]"
                 "[      $(echo -e '\xE2\x97\x8F')    ]"
                 "[     $(echo -e '\xE2\x97\x8F')     ]"
                 "[    $(echo -e '\xE2\x97\x8F')      ]"
                 "[   $(echo -e '\xE2\x97\x8F')       ]"
                 "[  $(echo -e '\xE2\x97\x8F')        ]"
                 "[ $(echo -e '\xE2\x97\x8F')         ]"
                 "[$(echo -e '\xE2\x97\x8F')          ]")
            delay=0.04
            trap control_c EXIT SIGINT
            while :
            do
                printf "\b\b\b\b\b\b\b\b\b\b\b\b\b${sp[i]}"
                i=$((i+1))
                i=$((i%20))
                sleep $delay
            done
            ;;
        stop)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi

            kill $3 > /dev/null 2>&1
            echo -ne "\r"
            echo -ne "${4}"
            let column=$(tput cols)-${#4}+10
            printf "%${column}s"
            # inform the user uppon success or failure
            echo -en "\b\b\b\b\b\b\b\b\b\b\b\b\b["
            if [[ $2 -eq 0 ]]; then
                echo -en "${green}${on_success}${nc}"
            else
                echo -en "${red}${on_fail}${nc}"
            fi
            echo -e "]"
            ;;
        update)
            if [[ -z ${3} ]]; then
                echo "spinner is not running.."
                exit 1
            fi
            kill $3 > /dev/null 2>&1
            echo -ne "\r"
            ;;
        *)
            echo "invalid argument, try {start/stop}"
            exit 1
            ;;
    esac
}

start_spinner() {
    _spinner "start" "${1}" &
    _sp_pid=$!
    disown
}

stop_spinner() {
    _spinner "stop" 0 $_sp_pid "$1"
    unset _sp_pid
}

update_spinner() {
    _spinner "update" 0 $_sp_pid
    unset _sp_pid
    start_spinner "${1}"
}

echo_pending() {
  local str
  str="${CYAN}${NORMAL}$1"
  if [ -z "$2" ]; then :; else
      str="${CYAN}[$2]${NORMAL} $1"
  fi
  start_spinner "$str"
}

echo_update() {
  local str
  str="${CYAN}${NORMAL}$1"
  if [ -z "$2" ]; then :; else
      str="${CYAN}[$2]${NORMAL} $1"
  fi
  update_spinner "$str"
}

echo_completed() {
  local str
  str="${CYAN}${NORMAL}$1"
  if [ -z "$2" ]; then :; else
      str="${CYAN}[$2]${NORMAL} $1"
  fi
  stop_spinner "$str"
}

CYAN=$(tput setaf 6)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)

check_dep() {
    command -v $1 >/dev/null 2>&1 || { echo "Please install \`${BOLD}$1${NORMAL}\` before running this script." >&2; exit 1; }
}

echo_pending() {
  local str
  str="${CYAN}${NORMAL}$1"
  if [ -z "$2" ]; then :; else
      str="${CYAN}[$2]${NORMAL} $1"
  fi
  start_spinner "$str"
}

echo_update() {
  local str
  str="${CYAN}${NORMAL}$1"
  if [ -z "$2" ]; then :; else
      str="${CYAN}[$2]${NORMAL} $1"
  fi
  update_spinner "$str"
}

echo_completed() {
  local str
  str="${CYAN}${NORMAL}$1"
  if [ -z "$2" ]; then :; else
      str="${CYAN}[$2]${NORMAL} $1"
  fi
  stop_spinner "$str"
}

linode_api() {
    args=(-F "api_action=$1") ; shift
    for arg in "$@" ; do
        args+=(-F "$arg")
    done
    curl -s -X POST "https://api.linode.com/"  -H 'cache-control: no-cache' \
         -H 'content-type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW' \
         -F "api_key=$API_KEY" "${args[@]}"
}

wait_jobs() {
    LINODE_ID=$1
    while true ; do
        if ( linode_api linode.job.list LinodeID=$LINODE_ID pendingOnly=1 | jq -Mje '.DATA == []' >/dev/null ) ; then
            break
        fi
        sleep 3
    done
}

wait_boot() {
    LINODE_ID=$1
    while true ; do
        if ( linode_api linode.job.list LinodeID=$LINODE_ID | jq ".DATA" | grep "Lassie initiated boot: CoreOS" >/dev/null ) ; then
            break
        fi
        sleep 3
    done
    sleep 10
}

get_status() {
  linode_api linode.list LinodeID=$1 | jq ".DATA" | jq -c ".[] | .STATUS" | sed -n 1p
}

list_worker_ids() {
  linode_api linode.list | jq ".DATA" | jq -c "[ .[] | select(.LPM_DISPLAYGROUP | contains (\"$DOMAIN\")) ]" | jq -c ".[] | select(.LABEL | startswith(\"worker_\")) | .LINODEID"
}

get_master_id() {
  linode_api linode.list | jq ".DATA" | jq -c "[ .[] | select(.LPM_DISPLAYGROUP | contains (\"$DOMAIN\")) ]" | jq -c ".[] | select(.LABEL | startswith(\"master_\")) | .LINODEID" | sed -n 1p
}

is_provisioned() {
  local IS_PROVISIONED=false
  if [ $( linode_api linode.list LinodeID=$1 | jq ".DATA" | jq -c ".[] | .LPM_DISPLAYGROUP == \"$DOMAIN\"") = true ] ; then
    IS_PROVISIONED=true
  fi
  echo $IS_PROVISIONED
}

reset_linode() {
    local LINODE_ID=$1
    local DISK_IDS
    local CONFIG_IDS
    local STATUS
    STATUS=$( get_status $LINODE_ID )

    if [ $STATUS = 1 ]; then
      echo_update "Shutting down linode" $LINODE_ID
      linode_api linode.shutdown LinodeID=$LINODE_ID >/dev/null
      wait_jobs $LINODE_ID
    fi

    echo_update "Retrieving disk list" $LINODE_ID
    DISK_IDS=$( linode_api linode.disk.list LinodeID=$LINODE_ID | jq ".DATA" | jq -c ".[] | .DISKID" )

    for DISK_ID in $DISK_IDS; do
        echo_update "Deleting disk $DISK_ID" $LINODE_ID
        linode_api linode.disk.delete LinodeID=$LINODE_ID DiskID=$DISK_ID >/dev/null
    done

    echo_update "Retrieving config list" $LINODE_ID
    CONFIG_IDS=$( linode_api linode.config.list LinodeID=$LINODE_ID | jq ".DATA" | jq -c ".[] | .ConfigID" )

    for CONFIG_ID in $CONFIG_IDS; do
        echo_update "Deleting config $CONFIG_ID" $LINODE_ID
        linode_api linode.config.delete LinodeID=$LINODE_ID ConfigID=$CONFIG_ID >/dev/null
    done

    echo_update "Waiting for all jobs to complete" $LINODE_ID
    wait_jobs $LINODE_ID
}

get_ip() {
  local LINODE_ID=$1
  local IP
  eval IP=\$IP_$LINODE_ID
  if ! [[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] 2>/dev/null; then
      IP="$( linode_api linode.ip.list LinodeID=$LINODE_ID | jq -Mje '.DATA[] | select(.ISPUBLIC==1) | .IPADDRESS' | sed -n 1p )"
  fi
  echo $IP
}

gen_master_certs() {
  MASTER_IP=$1
  LINODE_ID=$2
  echo_update "Generating master certificates" $LINODE_ID
  mkdir -p ~/.kube-linode/certs >/dev/null
  [ -e ~/.kube-linode/certs/openssl.cnf ] && rm ~/.kube-linode/certs/openssl.cnf >/dev/null
  cat > ~/.kube-linode/certs/openssl.cnf <<-EOF
    [req]
    req_extensions = v3_req
    distinguished_name = req_distinguished_name
    [req_distinguished_name]
    [ v3_req ]
    basicConstraints = CA:FALSE
    keyUsage = nonRepudiation, digitalSignature, keyEncipherment
    subjectAltName = @alt_names
    [alt_names]
    DNS.1 = kubernetes
    DNS.2 = kubernetes.default
    DNS.3 = kubernetes.default.svc
    DNS.4 = kubernetes.default.svc.cluster.local
    IP.1 = 10.3.0.1
    IP.2 = $MASTER_IP
EOF
  openssl genrsa -out ~/.kube-linode/certs/ca-key.pem 2048 >/dev/null 2>&1
  openssl req -x509 -new -nodes -key ~/.kube-linode/certs/ca-key.pem -days 10000 -out ~/.kube-linode/certs/ca.pem -subj "/CN=kube-ca" >/dev/null 2>&1
  openssl genrsa -out ~/.kube-linode/certs/apiserver-key.pem 2048 >/dev/null 2>&1
  openssl req -new -key ~/.kube-linode/certs/apiserver-key.pem -out ~/.kube-linode/certs/apiserver.csr -subj "/CN=kube-apiserver" -config ~/.kube-linode/certs/openssl.cnf >/dev/null 2>&1
  openssl x509 -req -in ~/.kube-linode/certs/apiserver.csr -CA ~/.kube-linode/certs/ca.pem -CAkey ~/.kube-linode/certs/ca-key.pem -CAcreateserial -out ~/.kube-linode/certs/apiserver.pem -days 365 -extensions v3_req -extfile ~/.kube-linode/certs/openssl.cnf >/dev/null 2>&1
  openssl genrsa -out ~/.kube-linode/certs/admin-key.pem 2048 >/dev/null 2>&1
  openssl req -new -key ~/.kube-linode/certs/admin-key.pem -out ~/.kube-linode/certs/admin.csr -subj "/CN=kube-admin" >/dev/null 2>&1
  openssl x509 -req -in ~/.kube-linode/certs/admin.csr -CA ~/.kube-linode/certs/ca.pem -CAkey ~/.kube-linode/certs/ca-key.pem -CAcreateserial -out ~/.kube-linode/certs/admin.pem -days 365 >/dev/null 2>&1
}

gen_worker_certs() {
  WORKER_FQDN=$1
  WORKER_IP=$1
  LINODE_ID=$2
  echo_update "Generating worker certificates" $LINODE_ID
  if [ -f ~/.kube-linode/certs/worker-openssl.cnf ] ; then : ; else
      cat > ~/.kube-linode/certs/worker-openssl.cnf <<-EOF
        [req]
        req_extensions = v3_req
        distinguished_name = req_distinguished_name
        [req_distinguished_name]
        [ v3_req ]
        basicConstraints = CA:FALSE
        keyUsage = nonRepudiation, digitalSignature, keyEncipherment
        subjectAltName = @alt_names
        [alt_names]
        IP.1 = \$ENV::WORKER_IP
EOF
  fi

  openssl genrsa -out ~/.kube-linode/certs/${WORKER_FQDN}-worker-key.pem 2048 >/dev/null 2>&1
  WORKER_IP=${WORKER_IP} openssl req -new -key ~/.kube-linode/certs/${WORKER_FQDN}-worker-key.pem -out ~/.kube-linode/certs/${WORKER_FQDN}-worker.csr -subj "/CN=${WORKER_FQDN}" -config ~/.kube-linode/certs/worker-openssl.cnf >/dev/null 2>&1
  WORKER_IP=${WORKER_IP} openssl x509 -req -in ~/.kube-linode/certs/${WORKER_FQDN}-worker.csr -CA ~/.kube-linode/certs/ca.pem -CAkey ~/.kube-linode/certs/ca-key.pem -CAcreateserial -out ~/.kube-linode/certs/${WORKER_FQDN}-worker.pem -days 365 -extensions v3_req -extfile ~/.kube-linode/certs/worker-openssl.cnf >/dev/null 2>&1
}

install() {
    local NODE_TYPE
    local LINODE_ID
    local PLAN
    local ROOT_PASSWORD
    local COREOS_OLD_DISK_SIZE
    local COREOS_DISK_SIZE
    local STORAGE_DISK_SIZE
    NODE_TYPE=$1
    LINODE_ID=$2
    reset_linode $LINODE_ID
    echo_update "Installing $NODE_TYPE node" $LINODE_ID
    ROOT_PASSWORD=$( openssl rand -base64 32 )

    echo_update "Retrieving current plan" $LINODE_ID
    PLAN=$( linode_api linode.list LinodeID=$LINODE_ID | jq ".DATA[0].PLANID" )

    echo_update "Retrieving maximum available disk size" $LINODE_ID
    TOTAL_DISK_SIZE=$( echo "$( linode_api avail.linodeplans PlanID=$PLAN | jq ".DATA[0].DISK" )" "*1024" | bc )
    INSTALL_DISK_SIZE=1024
    STORAGE_DISK_SIZE=10240
    COREOS_OLD_DISK_SIZE=$( echo "${TOTAL_DISK_SIZE}-${INSTALL_DISK_SIZE}-${STORAGE_DISK_SIZE}" | bc )
    COREOS_DISK_SIZE=$( echo "${TOTAL_DISK_SIZE}-${STORAGE_DISK_SIZE}" | bc )
    #echo_completed "CoreOS disk size: ${COREOS_DISK_SIZE}mb" $LINODE_ID
    #echo_completed "Storage disk size: ${STORAGE_DISK_SIZE}mb" $LINODE_ID
    #echo_completed "Install disk size: ${INSTALL_DISK_SIZE}mb" $LINODE_ID
    #echo_completed "Total disk size: ${TOTAL_DISK_SIZE}mb" $LINODE_ID

    echo_update "Creating storage disk" $LINODE_ID
    STORAGE_DISK_ID="$( linode_api linode.disk.create LinodeID=$LINODE_ID \
       Label="LocalStorage" Type=ext4 Size=$STORAGE_DISK_SIZE | jq '.DATA.DiskID' )"

    echo_update "Creating CoreOS disk" $LINODE_ID
    DISK_ID="$( linode_api linode.disk.create LinodeID=$LINODE_ID \
       Label="CoreOS" Type=raw Size=$COREOS_OLD_DISK_SIZE | jq '.DATA.DiskID' )"

    eval IP=\$IP_$LINODE_ID
    if [ "$NODE_TYPE" = "master" ] ; then
        gen_master_certs $IP $LINODE_ID
        echo_update "Initializing stackscript parameters" $LINODE_ID
        PARAMS=$( cat <<-EOF
          {
              "admin_key_cert": "$( base64 $base64_args < ~/.kube-linode/certs/admin-key.pem )",
              "admin_cert": "$( base64 $base64_args < ~/.kube-linode/certs/admin.pem )",
              "apiserver_key_cert": "$( base64 $base64_args < ~/.kube-linode/certs/apiserver-key.pem )",
              "apiserver_cert": "$( base64 $base64_args < ~/.kube-linode/certs/apiserver.pem )",
              "ca_key_cert": "$( base64 $base64_args < ~/.kube-linode/certs/ca-key.pem )",
              "ca_cert": "$( base64 $base64_args < ~/.kube-linode/certs/ca.pem )",
              "ssh_key": "$( cat ~/.ssh/id_rsa.pub )",
              "ip": "$IP",
              "node_type": "$NODE_TYPE",
              "advertise_ip": "$IP",
              "etcd_endpoint" : "http://${MASTER_IP}:2379",
              "k8s_ver": "v1.7.0-beta.2_coreos.0",
              "dns_service_ip": "10.3.0.10",
              "k8s_service_ip": "10.3.0.1",
              "service_ip_range": "10.3.0.0/24",
              "pod_network": "10.2.0.0/16",
              "USERNAME": "$USERNAME",
              "DOMAIN" : "$DOMAIN",
              "EMAIL" : "$EMAIL",
              "MASTER_IP" : "$MASTER_IP",
              "AUTH" : "$( base64 $base64_args < ~/.kube-linode/auth )",
              "LINODE_ID": "$LINODE_ID"
          }
EOF
        )
    fi

    if [ "$NODE_TYPE" = "worker" ] ; then
        gen_worker_certs $IP $LINODE_ID
        echo_update "Initializing stackscript parameters" $LINODE_ID
        PARAMS=$( cat <<-EOF
          {
              "worker_key_cert": "$( base64 $base64_args < ~/.kube-linode/certs/${IP}-worker-key.pem )",
              "worker_cert": "$( base64 $base64_args < ~/.kube-linode/certs/${IP}-worker.pem )",
              "ca_cert": "$( base64 $base64_args < ~/.kube-linode/certs/ca.pem )",
              "ssh_key": "$( cat ~/.ssh/id_rsa.pub )",
              "ip": "$IP",
              "node_type": "$NODE_TYPE",
              "advertise_ip": "$IP",
              "etcd_endpoint" : "http://${MASTER_IP}:2379",
              "k8s_ver": "v1.7.0-beta.2_coreos.0",
              "dns_service_ip": "10.3.0.10",
              "k8s_service_ip": "10.3.0.1",
              "service_ip_range": "10.3.0.0/24",
              "pod_network": "10.2.0.0/16",
              "USERNAME": "$USERNAME",
              "DOMAIN" : "$DOMAIN",
              "EMAIL" : "$EMAIL",
              "MASTER_IP" : "$MASTER_IP",
              "AUTH" : "$( base64 $base64_args < ~/.kube-linode/auth )",
              "LINODE_ID": "$LINODE_ID"
          }
EOF
        )
    fi

    # Create the install OS disk from script
    echo_update "Creating install disk" $LINODE_ID
    INSTALL_DISK_ID=$(linode_api linode.disk.createfromstackscript LinodeID=$LINODE_ID StackScriptID=$SCRIPT_ID \
        DistributionID=140 Label=Installer Size=$INSTALL_DISK_SIZE \
        StackScriptUDFResponses="$PARAMS" rootPass="$ROOT_PASSWORD" | jq ".DATA.DiskID" )

    # Configure the installer to boot
    echo_update "Creating boot configuration" $LINODE_ID
    CONFIG_ID=$(linode_api linode.config.create LinodeID=$LINODE_ID KernelID=138 Label="Installer" \
        DiskList=$DISK_ID,$INSTALL_DISK_ID RootDeviceNum=2 | jq ".DATA.ConfigID" )

    echo_update "Booting installer" $LINODE_ID
    linode_api linode.boot LinodeID=$LINODE_ID ConfigID=$CONFIG_ID >/dev/null
    wait_jobs $LINODE_ID

    echo_update "Updating CoreOS config" $LINODE_ID
    linode_api linode.config.update LinodeID=$LINODE_ID ConfigID=$CONFIG_ID Label="CoreOS" \
        DiskList=$DISK_ID,$STORAGE_DISK_ID KernelID=213 RootDeviceNum=1 >/dev/null

    echo_update "Installing CoreOS (might take a while)" $LINODE_ID
    wait_boot $LINODE_ID

    echo_update "Shutting down CoreOS" $LINODE_ID
    linode_api linode.shutdown LinodeID=$LINODE_ID >/dev/null

    echo_update "Deleting install disk $INSTALL_DISK_ID" $LINODE_ID
    linode_api linode.disk.delete LinodeID=$LINODE_ID DiskID=$INSTALL_DISK_ID >/dev/null

    echo_update "Resizing CoreOS disk $DISK_ID" $LINODE_ID
    linode_api linode.disk.resize LinodeID=$LINODE_ID DiskID=$DISK_ID Size=$COREOS_DISK_SIZE >/dev/null

    echo_update "Booting CoreOS" $LINODE_ID
    linode_api linode.boot LinodeID=$LINODE_ID ConfigID=$CONFIG_ID >/dev/null

    wait_jobs $LINODE_ID
    sleep 10

    echo_update "Waiting for CoreOS to be ready" $LINODE_ID
    sleep 15
    if [ "$NODE_TYPE" = "master" ] ; then
        if [ -e ~/.kube-linode/acme.json ] ; then
            echo_update "Transferring acme.json" $LINODE_ID
            ssh -i ~/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -tt "${USERNAME}@$IP" \
            "sudo truncate -s 0 /etc/traefik/acme/acme.json; echo '$( base64 $base64_args < ~/.kube-linode/acme.json )' \
             | base64 --decode | sudo tee --append /etc/traefik/acme/acme.json" 2>/dev/null >/dev/null
        fi
    fi

    echo_completed "Starting to provision $NODE_TYPE node" $LINODE_ID
    tput cuu1
    tput el

    ssh -i ~/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -tt "${USERNAME}@$IP" \
            "./bootstrap.sh" 2>/dev/null

    tput cuu1
    tput el

    echo_pending "Deleting bootstrap script" $LINODE_ID
    ssh -i ~/.ssh/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -tt "${USERNAME}@$IP" \
            "rm bootstrap.sh" 2>/dev/null

    echo_update "Changing status to provisioned" $LINODE_ID
    linode_api linode.update LinodeID=$LINODE_ID Label="${NODE_TYPE}_${LINODE_ID}" lpm_displayGroup="$DOMAIN" >/dev/null
}

update_script() {
  SCRIPT_ID=$( linode_api stackscript.list | jq ".DATA" | jq -c '.[] | select(.LABEL == "CoreOS_Kube_Cluster") | .STACKSCRIPTID' | sed -n 1p )
  if ! [[ $SCRIPT_ID =~ ^[0-9]+$ ]] 2>/dev/null; then
      SCRIPT_ID=$( linode_api stackscript.create DistributionIDList=140 Label=CoreOS_Kube_Cluster script="$( cat ~/.kube-linode/install-coreos.sh )" \
                  | jq ".DATA.StackScriptID" )
  else
      linode_api stackscript.update StackScriptID=${SCRIPT_ID} script="$( cat ~/.kube-linode/install-coreos.sh )" >/dev/null
  fi
}

read_api_key() {
  if ! [[ $API_KEY =~ ^[0-9a-zA-Z]+$ ]] 2>/dev/null; then
      while ! [[ $API_KEY =~ ^-?[0-9a-zA-Z]+$ ]] 2>/dev/null; do
         text_input "Enter Linode API Key (https://manager.linode.com/profile/api) : " API_KEY
      done
      while ! linode_api test.echo | jq -e ".ERRORARRAY == []" >/dev/null; do
         text_input "Enter Linode API Key (https://manager.linode.com/profile/api) : " API_KEY
      done
      echo "API_KEY=$API_KEY" >> ~/.kube-linode/settings.env
  else
      if ! linode_api test.echo | jq -e ".ERRORARRAY == []" >/dev/null; then
        while ! linode_api test.echo | jq -e ".ERRORARRAY == []" >/dev/null; do
           text_input "Enter Linode API Key (https://manager.linode.com/profile/api) : " API_KEY
        done
        echo "API_KEY=$API_KEY" >> ~/.kube-linode/settings.env
      fi
  fi
  tput civis
}

read_master_plan() {
  if ! [[ $MASTER_PLAN =~ ^[0-9]+$ ]] 2>/dev/null; then
      while ! [[ $MASTER_PLAN =~ ^-?[0-9]+$ ]] 2>/dev/null; do
         IFS=$'\n'
         echo_pending "Retrieving plans"
         local plan_data=$(linode_api avail.linodeplans | jq ".DATA | sort_by(.PRICE)")
         echo_completed "Retrieved plans"
         tput cuu1
         tput el
         local plan_ids=($(echo $plan_data | jq -r '.[] | .PLANID'))
         local plan_list=($(echo $plan_data | jq -r '.[] | [.RAM, .PRICE] | @csv' | \
           awk -v FS="," '{ram=$1/1024; printf "%3sGB (\$%s/mo)%s",ram,$2,ORS}' 2>/dev/null))
         list_input_index "Select a master plan (https://www.linode.com/pricing)" plan_list selected_disk_id

         MASTER_PLAN=${plan_ids[$selected_disk_id]}
      done
      echo "MASTER_PLAN=$MASTER_PLAN" >> ~/.kube-linode/settings.env
  fi

}

read_worker_plan() {
  if ! [[ $WORKER_PLAN =~ ^[0-9]+$ ]] 2>/dev/null; then
      while ! [[ $WORKER_PLAN =~ ^-?[0-9]+$ ]] 2>/dev/null; do
         IFS=$'\n'
         echo_pending "Retrieving plans"
         local plan_data=$(linode_api avail.linodeplans | jq ".DATA | sort_by(.PRICE)")
         echo_completed "Retrieved plans"
         tput cuu1
         tput el
         local plan_ids=($(echo $plan_data | jq -r '.[] | .PLANID'))
         local plan_list=($(echo $plan_data | jq -r '.[] | [.RAM, .PRICE] | @csv' | \
           awk -v FS="," '{ram=$1/1024; printf "%3sGB (\$%s/mo)%s",ram,$2,ORS}' 2>/dev/null))
         list_input_index "Select a worker plan (https://www.linode.com/pricing)" plan_list selected_disk_id

         WORKER_PLAN=${plan_ids[$selected_disk_id]}
      done
      echo "WORKER_PLAN=$WORKER_PLAN" >> ~/.kube-linode/settings.env
  fi

}

read_datacenter() {
  if ! [[ $DATACENTER_ID =~ ^[0-9]+$ ]] 2>/dev/null; then
      while ! [[ $DATACENTER_ID =~ ^-?[0-9]+$ ]] 2>/dev/null; do
         IFS=$'\n'
         echo_pending "Retrieving datacenters"
         datacenters_data=$(linode_api avail.datacenters | jq ".DATA | sort_by(.LOCATION)")
         echo_completed "Retrieved datacenters"
         tput cuu1
         tput el
         datacenters_ids=($(echo $datacenters_data | jq -r '.[] | .DATACENTERID'))
         datacenters_list=($(echo $datacenters_data | jq -r '.[] | .LOCATION'))
         list_input_index "Select a datacenter" datacenters_list selected_data_center_index
         DATACENTER_ID=${datacenters_ids[$selected_data_center_index]}
      done
      echo "DATACENTER_ID=$DATACENTER_ID" >> ~/.kube-linode/settings.env
  fi
}

read_domain() {
  if ! [[ $DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]] 2>/dev/null; then
      while ! [[ $DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]] 2>/dev/null; do
         text_input "Enter Domain Name: " DOMAIN "^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$" "Please enter a valid domain name"
      done
      echo "DOMAIN=$DOMAIN" >> ~/.kube-linode/settings.env
  fi
  tput civis
}

read_email() {
  email_regex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
  if ! [[ $EMAIL =~ $email_regex ]] 2>/dev/null; then
      while ! [[ $EMAIL =~ $email_regex ]] 2>/dev/null; do
         text_input "Enter Email: " EMAIL "^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$" "Please enter a valid email"
      done
      echo "EMAIL=$EMAIL" >> ~/.kube-linode/settings.env
  fi
  tput civis
}

update_dns() {
  local LINODE_ID=$1
  local DOMAIN_ID
  local IP
  local IP_ADDRESS_ID
  local RESOURCE_IDS
  eval IP=\$IP_$LINODE_ID
  echo_update "Updating DNS record for $DOMAIN" $LINODE_ID
  DOMAIN_ID=$( linode_api domain.list | jq ".DATA" | jq -c ".[] | select(.DOMAIN == \"$DOMAIN\") | .DOMAINID" )
  if ! [[ $DOMAIN_ID =~ ^[0-9]+$ ]] 2>/dev/null; then
      linode_api domain.create DomainID=$DOMAIN_ID Domain="$DOMAIN" TTL_sec=300 axfr_ips="none" Expire_sec=604800 \
                               SOA_Email="$EMAIL" Retry_sec=300 status=1 Refresh_sec=300 Type=master >/dev/null
  fi
  DOMAIN_ID=$( linode_api domain.list | jq ".DATA" | jq -c ".[] | select(.DOMAIN == \"$DOMAIN\") | .DOMAINID" )
  linode_api domain.update DomainID=$DOMAIN_ID Domain="$DOMAIN" TTL_sec=300 axfr_ips="none" Expire_sec=604800 \
                           SOA_Email="$EMAIL" Retry_sec=300 status=1 Refresh_sec=300 Type=master >/dev/null

  echo_update "Retrieving list of resources for $DOMAIN" $LINODE_ID
  RESOURCE_IDS=$( linode_api domain.resource.list DomainID=$DOMAIN_ID | jq ".DATA" | jq ".[] | .RESOURCEID" )

  for RESOURCE_ID in $RESOURCE_IDS; do
      echo_update "Deleting domain resource record $RESOURCE_ID" $LINODE_ID
      linode_api domain.resource.delete DomainID=$DOMAIN_ID ResourceID=$RESOURCE_ID >/dev/null
  done

  echo_update "Adding 'A' DNS record to $DOMAIN with target $IP" $LINODE_ID
  linode_api domain.resource.create DomainID=$DOMAIN_ID \
             TARGET="$IP" TTL_SEC=0 PORT=80 PROTOCOL="" PRIORITY=10 WEIGHT=5 TYPE="A" NAME="" >/dev/null

  echo_update "Adding wildcard 'CNAME' record with target $DOMAIN" $LINODE_ID
  linode_api domain.resource.create DomainID=$DOMAIN_ID \
             TARGET="$DOMAIN" TTL_SEC=0 PORT=80 PROTOCOL="" PRIORITY=10 WEIGHT=5 TYPE="CNAME" NAME="*" >/dev/null

  echo_update "Updating reverse DNS record of $IP to $DOMAIN" $LINODE_ID
  IP_ADDRESS_ID=$( linode_api linode.ip.list | jq ".DATA" | jq -c ".[] | select(.IPADDRESS == \"$IP\") | .IPADDRESSID" | sed -n 1p )
  linode_api linode.ip.setrdns IPAddressID=$IP_ADDRESS_ID Hostname="$DOMAIN" >/dev/null
}

read_no_of_workers() {
  if ! [[ $NO_OF_WORKERS =~ ^[0-9]+$ ]] 2>/dev/null; then
      while ! [[ $NO_OF_WORKERS =~ ^[0-9]+$ ]] 2>/dev/null; do
         text_input "Enter number of workers: " NO_OF_WORKERS "^[0-9]+$" "Please enter a number"
      done
      echo "NO_OF_WORKERS=$NO_OF_WORKERS" >> ~/.kube-linode/settings.env
  fi
  tput civis
}
