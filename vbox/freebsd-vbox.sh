#!/bin/sh

# Make freebsd vm

# fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/VM-IMAGES/10.1-RELEASE/amd64/Latest/FreeBSD-10.1-RELEASE-amd64.raw.xz

VM="FreeBSD10"
RAW_IMG="$1"
BASE_IMG="${RAW_IMG%.raw}"
VMDK_IMG="${BASE_IMG}.vmdk"
OSTYPE="FreeBSD_64"
OVA_IMG="${VM}.ova"
set -e
if VBoxManage list vms | sed -e 's/^"//' -e 's/".*//g' | grep "^${VM}\$" ; then
    echo "VM '$VM' already exists.  delete? (y/N)"
    read resp
    if [ "$resp" = "y" -o "$resp" = "Y" ] ; then
	VBoxManage unregistervm "$VM" --delete
    fi
fi
set -x
rm -f "${VMDK_IMG}" "${OVA_IMG}"

# storage controller
STORAGE_CONTROLLER_NAME="IDE Controller"
VBoxManage convertfromraw "${RAW_IMG}" "${VMDK_IMG}" --format VMDK
VBoxManage createvm --name "$VM" --ostype "${OSTYPE}" --register
#VBoxManage storagectl "$VM" --name "SATA Controller" --add sata --controller IntelAHCI
VBoxManage storagectl "$VM" --name "${STORAGE_CONTROLLER_NAME}" --add ide --controller PIIX4
VBoxManage storageattach "$VM" --storagectl "${STORAGE_CONTROLLER_NAME}" \
    --port 0 --device 0 --type hdd --medium "${VMDK_IMG}"

VBoxManage modifyvm "$VM" --ioapic on --boot1 disk --memory 768 --vram 12
# XXX: NAT instead?  
VBoxManage modifyvm "$VM" --nic1 nat
VBoxManage modifyvm "$VM" --macaddress1 auto
# seems to be most stable NIC under virtualbox, might want to try virtio later?
VBoxManage modifyvm "$VM" --nictype1 82540EM

# Turn off PAE
VBoxManage modifyvm "$VM" --pae off

VBoxManage export "$VM" -o "${VM}.ova"

