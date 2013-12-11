#!/bin/bash
set -e

if [ $# -lt 7 ]; then
    echo "Usage: $0 <esxi_1_user> <esxi_1_host> <esxi_2_user> <esxi_2_host> <scripts_datastore> <templates_datastore> <datastore>"
    exit 1
fi

ESXI_1_USER=$1
ESXI_1_HOST=$2

ESXI_2_USER=$3
ESXI_2_HOST=$4

SCRIPTS_DATASTORE=$5
TEMPLATES_DATASTORE=$6
DATASTORE=$7

RDO_NAME=rdo-esxi-$RANDOM

ESXI_PUBLIC_SWITCH=vSwitch0
ESXI_PUBLIC_VMNIC=vmnic0

LINUX_TEMPLATE_VMDK=/vmfs/volumes/$TEMPLATES_DATASTORE/centos-6.5-template-100G/centos-6.5-template-100G.vmdk

BASEDIR=$(dirname $0)

echo "Deploying RDO ESXi: $RDO_NAME"

$BASEDIR/deploy-rdo-esxicompute.sh $ESXI_1_USER $ESXI_1_HOST $ESXI_2_USER $ESXI_2_HOST "$SCRIPTS_DATASTORE" "$DATASTORE" "$RDO_NAME" "$ESXI_PUBLIC_SWITCH" $ESXI_PUBLIC_VMNIC "$LINUX_TEMPLATE_VMDK" 