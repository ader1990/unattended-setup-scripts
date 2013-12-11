#!/bin/bash
set -e

if [ $# -ne 10 ]; then
    echo "Usage: $0 <esxi_1_user> <esxi_1_host> <esxi_2_user> <esxi_2_host> 
	<scripts_datastore> <datastore> <rdo_name> <esxi_public_switch> <esxi_public_vnic> <linux_template_vmdk>"
    exit 1
fi

ESXI_1_USER=$1
ESXI_1_HOST=$2
ESXI_2_USER=$3
ESXI_2_HOST=$4
SCRIPTS_DATASTORE=$5
DATASTORE=$6
RDO_NAME=$7
ESXI_PUBLIC_SWITCH=$8
ESXI_PUBLIC_VMNIC=$9
LINUX_TEMPLATE_VMDK=$10


BASEDIR=$(dirname $0)

. $BASEDIR/utils.sh

ESXI_BASEDIR=/vmfs/volumes/$SCRIPTS_DATASTORE/unattended-scripts
RDO_VM_IPS_FILE=`mktemp -u /tmp/rdo_ips.XXXXXX`

ssh $ESXI_1_USER@$ESXI_1_HOST $ESXI_BASEDIR/deploy-rdo-esxicompute-vms.sh $DATASTORE $RDO_NAME "CONTROLLER" $ESXI_PUBLIC_SWITCH $ESXI_PUBLIC_VNIC "$LINUX_TEMPLATE_VMDK" $RDO_VM_IPS_FILE
read CONTROLLER_VM_NAME CONTROLLER_VM_IP <<< `ssh $ESXI_USER@$ESXI_HOST "cat $RDO_VM_IPS_FILE" | perl -n -e'/^(.+)\:(.+)$/ && print "$1\n$2\n"'`

ssh $ESXI_2_USER@$ESXI_2_HOST $ESXI_BASEDIR/deploy-rdo-esxicompute-vms.sh $DATASTORE $RDO_NAME "COMPUTE" $ESXI_PUBLIC_SWITCH $ESXI_PUBLIC_VNIC "$LINUX_TEMPLATE_VMDK" $RDO_VM_IPS_FILE
read COMPUTE_VM_NAME COMPUTE_VM_IP <<< `ssh $ESXI_USER@$ESXI_HOST "cat $RDO_VM_IPS_FILE" | perl -n -e'/^(.+)\:(.+)$/ && print "$1\n$2\n"'`



#SSH_KEY_FILE=`mktemp -u /tmp/rdo_ssh_key.XXXXXX`
#ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096

#$BASEDIR/configure-rdo.sh $OPENSTACK_RELEASE $SSH_KEY_FILE $CONTROLLER_VM_NAME $CONTROLLER_VM_IP $NETWORK_VM_NAME $NETWORK_VM_IP $QEMU_COMPUTE_VM_NAME $QEMU_COMPUTE_VM_IP $HYPERV_COMPUTE_VM_NAME $HYPERV_COMPUTE_VM_IP

