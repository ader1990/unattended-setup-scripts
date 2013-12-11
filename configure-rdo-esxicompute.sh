#!/bin/bash
set -e

if [ $# -lt 11 ]; then
    echo "Usage: $0 <ssh_key_file> <controller_host_name> <controller_host_ip> <compute_host_name> <compute_host_ip> <esxi_1_host> <esxi_1_username> <esxi_1_password> <esxi_2_host> <esxi_2_username> <esxi_2_password> "
    exit 1
fi

SSH_KEY_FILE=$1

CONTROLLER_VM_NAME=$2
CONTROLLER_VM_IP=$3

COMPUTE_VM_NAME=$4
COMPUTE_VM_IP=$5

ESXI_1_HOST=$6
ESXI_1_USERNAME=$7
ESXI_1_PASSWORD=$8

ESXI_2_HOST=$9
ESXI_2_USERNAME=${10}
ESXI_2_PASSWORD=${11}


RDO_ADMIN=root
RDO_ADMIN_PASSWORD=Passw0rd

ANSWERS_FILE=packstack_answers.conf
NOVA_CONF_FILE=/etc/nova/nova.conf
OPENSTACK_RELEASE="havana"
DOMAIN=localdomain

MAX_WAIT_SECONDS=600

BASEDIR=$(dirname $0)

. $BASEDIR/utils.sh

if [ ! -f "$SSH_KEY_FILE" ]; then
    ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096
fi
SSH_KEY_FILE_PUB=$SSH_KEY_FILE.pub

echo "Configuring SSH public key authentication on the RDO hosts"

configure_ssh_pubkey_auth $RDO_ADMIN $CONTROLLER_VM_IP $SSH_KEY_FILE_PUB $RDO_ADMIN_PASSWORD
configure_ssh_pubkey_auth $RDO_ADMIN $COMPUTE_VM_IP $SSH_KEY_FILE_PUB $RDO_ADMIN_PASSWORD

echo "Sync hosts date and time"
update_host_date $RDO_ADMIN@$CONTROLLER_VM_IP
update_host_date $RDO_ADMIN@$COMPUTE_VM_IP

config_openstack_network_adapter () {
    SSHUSER_HOST=$1
    ADAPTER=$2

    run_ssh_cmd_with_retry $SSHUSER_HOST "cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$ADAPTER
DEVICE="$ADAPTER"
BOOTPROTO="none"
MTU="1500"
ONBOOT="yes"
EOF"

    run_ssh_cmd_with_retry $SSHUSER_HOST "ifup $ADAPTER"
}

echo "Configuring networking"

config_openstack_network_adapter $RDO_ADMIN@$CONTROLLER_VM_IP eth1
config_openstack_network_adapter $RDO_ADMIN@$CONTROLLER_VM_IP eth2
set_hostname $RDO_ADMIN@$CONTROLLER_VM_IP $CONTROLLER_VM_NAME.$DOMAIN $CONTROLLER_VM_IP

config_openstack_network_adapter $RDO_ADMIN@$COMPUTE_VM_IP eth1
config_openstack_network_adapter $RDO_ADMIN@$COMPUTE_VM_IP eth2
set_hostname $RDO_ADMIN@$COMPUTE_VM_IP $COMPUTE_VM_NAME.$DOMAIN $COMPUTE_VM_IP

echo "Installing RDO RPMs on controller"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y http://rdo.fedorapeople.org/openstack/openstack-$OPENSTACK_RELEASE/rdo-release-$OPENSTACK_RELEASE.rpm || true"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y openstack-packstack"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum -y install http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm || true"
run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "yum install -y crudini"

echo "Generating Packstack answer file"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "packstack --gen-answer-file=$ANSWERS_FILE"

echo "Configuring Packstack answer file"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "\
crudini --set $ANSWERS_FILE general CONFIG_SSH_KEY /root/.ssh/id_rsa.pub && \
crudini --set $ANSWERS_FILE general CONFIG_NTP_SERVERS 0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org,3.pool.ntp.org && \
crudini --set $ANSWERS_FILE general CONFIG_CINDER_VOLUMES_SIZE 20G && \
crudini --set $ANSWERS_FILE general CONFIG_NEUTRON_INSTALL n && \
crudini --set $ANSWERS_FILE general CONFIG_CEILOMETER_INSTALL n && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_COMPUTE_PRIVIF eth1&& \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_NETWORK_PUBIF eth2 && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_NETWORK_PRIVIF eth1 && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_NETWORK_FLOATRANGE 10.7.205.0/24 && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_NETWORK_FIXEDRANGE 10.0.5.0/24 && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_NETWORK_MANAGER nova.network.manager.VlanManager && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_NETWORK_HOSTS $CONTROLLER_VM_IP\",\"$COMPUTE_VM_IP && \
crudini --set $ANSWERS_FILE general CONFIG_NOVA_COMPUTE_HOSTS $CONTROLLER_VM_IP\",\"$COMPUTE_VM_IP && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_DB_PW && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_L3_HOSTS && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_L3_EXT_BRIDGE && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_DHCP_HOSTS && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_L2_PLUGIN && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_METADATA_HOSTS && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_METADATA_PW && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_OVS_BRIDGE_MAPPINGS && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_LB_TENANT_NETWORK_TYPE && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_LB_VLAN_RANGES && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_LB_INTERFACE_MAPPINGS && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_OVS_TENANT_NETWORK_TYPE && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_OVS_VLAN_RANGES && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_OVS_BRIDGE_IFACES && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_OVS_TUNNEL_RANGES && \
crudini --del $ANSWERS_FILE general CONFIG_NEUTRON_OVS_TUNNEL_IF"

echo "Deploying SSH private key on $CONTROLLER_VM_IP"

scp -i $SSH_KEY_FILE -o 'PasswordAuthentication no' $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP:.ssh/id_rsa
scp -i $SSH_KEY_FILE -o 'PasswordAuthentication no' $SSH_KEY_FILE_PUB $RDO_ADMIN@$CONTROLLER_VM_IP:.ssh/id_rsa.pub

echo "Running Packstack"

run_ssh_cmd_with_retry $RDO_ADMIN@$CONTROLLER_VM_IP "packstack --answer-file=$ANSWERS_FILE"

set_rdo_esxi_conf(){
COMPUTE_ESXI_IP=$1
COMPUTE_ESXI_USERNAME=$2
COMPUTE_ESXI_PASSWORD=$3
ESX_LINUX_HOST=$4
COMPUTE_ESXI_VLAN=vmnic0
CONF_FILE=/etc/nova/nova.conf
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "sed -i 's/#host_ip=<None>/host_ip=$COMPUTE_ESXI_IP/g' $CONF_FILE"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "sed -i 's/#host_username=<None>/host_username=$COMPUTE_ESXI_USERNAME/g' $CONF_FILE"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "sed -i 's/#host_password=<None>/host_password=$COMPUTE_ESXI_PASSWORD/g' $CONF_FILE"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "sed -i 's/#vlan_interface=vmnic0/vlan_interface=$COMPUTE_ESXI_VLAN/g' $CONF_FILE"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "sed -i 's/compute_driver=libvirt.LibvirtDriver/compute_driver=vmwareapi.VMwareESXDriver/g' $CONF_FILE"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "yum install python-suds -y"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "/sbin/iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "/sbin/iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "/sbin/iptables -A FORWARD -i eth1 -o eth2 -m state --state RELATED,ESTABLISHED -j ACCEPT"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "service iptables save"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "/sbin/iptables -A FORWARD -i eth2 -o eth1 -j ACCEPT"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "service openstack-nova-compute restart"
run_ssh_cmd_with_retry $RDO_ADMIN@$ESX_LINUX_HOST "service openstack-nova-network restart"
}

set_rdo_esxi_conf $ESXI_1_HOST $ESXI_1_USERNAME $ESXI_1_PASSWORD $CONTROLLER_VM_IP
set_rdo_esxi_conf $ESXI_2_HOST $ESXI_2_USERNAME $ESXI_2_PASSWORD $COMPUTE_VM_IP

echo "RDO installed!"
echo "SSH access:"
echo "ssh -i $SSH_KEY_FILE $RDO_ADMIN@$CONTROLLER_VM_IP"

