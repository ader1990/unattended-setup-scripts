#!/bin/bash
set -e

if [ $# -ne 12 ]; then
    echo "Usage: $0 <esxi_1_host> <esxi_1_user> <esxi_1_password> <esxi_2_host> <esxi_2_user> <esxi_2_password> 
	<scripts_datastore> <datastore> <rdo_name> <esxi_public_switch> <esxi_public_vnic> <linux_template_vmdk>"
    exit 1
fi

ESXI_1_HOST=$1
ESXI_1_USER=$2
ESXI_1_PASS=$3

ESXI_2_HOST=$4
ESXI_2_USER=$5
ESXI_2_PASS=$6

SCRIPTS_DATASTORE=$7
DATASTORE=$8
RDO_NAME=$9
ESXI_PUBLIC_SWITCH=${10}
ESXI_PUBLIC_VMNIC=${11}
LINUX_TEMPLATE_VMDK=${12}


BASEDIR=$(dirname $0)

. $BASEDIR/utils.sh

ESXI_BASEDIR=/vmfs/volumes/$SCRIPTS_DATASTORE/unattended-scripts
RDO_VM_IPS_FILE_1=`mktemp -u /tmp/rdo_ips.XXXXXX`

RDO_VM_IPS_FILE_2=`mktemp -u /tmp/rdo_ips.XXXXXX`

ssh $ESXI_1_USER@$ESXI_1_HOST $ESXI_BASEDIR/deploy-rdo-esxicompute-vms.sh $DATASTORE $RDO_NAME "CONTROLLER" $ESXI_PUBLIC_SWITCH $ESXI_PUBLIC_VMNIC "$LINUX_TEMPLATE_VMDK" $RDO_VM_IPS_FILE_1 

ssh $ESXI_2_USER@$ESXI_2_HOST $ESXI_BASEDIR/deploy-rdo-esxicompute-vms.sh $DATASTORE $RDO_NAME "COMPUTE" $ESXI_PUBLIC_SWITCH $ESXI_PUBLIC_VMNIC "$LINUX_TEMPLATE_VMDK" $RDO_VM_IPS_FILE_2

read CONTROLLER_VM_NAME CONTROLLER_VM_IP <<< `ssh $ESXI_1_USER@$ESXI_1_HOST "cat $RDO_VM_IPS_FILE_1" | perl -n -e'/^(.+)\:(.+)$/ && print "$1\n$2\n"'`
echo $CONTROLLER_VM_NAME
echo $CONTROLLER_VM_IP

read COMPUTE_VM_NAME COMPUTE_VM_IP <<< `ssh $ESXI_2_USER@$ESXI_2_HOST "cat $RDO_VM_IPS_FILE_2" | perl -n -e'/^(.+)\:(.+)$/ && print "$1\n$2\n"'`

SSH_KEY_FILE=`mktemp -u /tmp/rdo_ssh_key.XXXXXX`
ssh-keygen -q -t rsa -f $SSH_KEY_FILE -N "" -b 4096

$BASEDIR/configure-rdo-esxicompute.sh $SSH_KEY_FILE $CONTROLLER_VM_NAME $CONTROLLER_VM_IP $COMPUTE_VM_NAME $COMPUTE_VM_IP $ESXI_1_HOST $ESXI_1_USER $ESXI_1_PASS $ESXI_2_HOST $ESXI_2_USER $ESXI_2_PASS

