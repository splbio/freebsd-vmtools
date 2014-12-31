#!/bin/sh

# Make freebsd vm

# fetch ftp://ftp.freebsd.org/pub/FreeBSD/releases/VM-IMAGES/10.1-RELEASE/amd64/Latest/FreeBSD-10.1-RELEASE-amd64.raw.xz

VM="FreeBSD10"
RAW_IMG="$1"

set -e
if VBoxManage list vms | sed -e 's/^"//' -e 's/".*//g' | grep "^${VM}\$" ; then
    echo "VM '$VM' already exists.  delete? (y/N)"
    read resp
    if [ "$resp" = "y" -o "$resp" = "Y" ] ; then
	VBoxManage unregistervm "$VM" --delete
    fi
fi

if echo "$RAW_IMG" | grep -q '.vmdk' ; then
    # remove .vmdk -> .2.vmdk
    VMDK_IMG="${RAW_IMG%.vmdk}.2.vmdk"
    echo copying "$RAW_IMG" to "$VMDK_IMG"
    set -x
    cp  "$RAW_IMG" "$VMDK_IMG"
    import_vmdk="false"
else
    set -x
    BASE_IMG="${RAW_IMG%.raw}"
    VMDK_IMG="${BASE_IMG}.vmdk"
    import_vmdk="true"
fi

OSTYPE="FreeBSD_64"
OVA_IMG="${VM}.ova"
set -x

rm -f "${OVA_IMG}"

# storage controller
STORAGE_CONTROLLER_NAME="IDE Controller"
if $import_vmdk ; then
    rm -f "${VMDK_IMG}"
    VBoxManage convertfromraw "${RAW_IMG}" "${VMDK_IMG}" --format VMDK
fi
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

# Usb is nice too.  Makes it easier for user to later add pass-through.
VBoxManage modifyvm "$VM" --usb on

# sound is nice to have
case `uname` in
    Darwin) AUDIO="coreaudio" ;;
    FreeBSD) AUDIO="oss" ;;
    *) AUDIO="null" ;;
esac
# Might want to disable this line if we get errors loading the VM
# on hosts, problem is that there doesn't seem to be a way to just
# say "use the default driver that plays audio" instead you can only
# say "none" or "null" in a platform independent way.
VBoxManage modifyvm "$VM" --audio "$AUDIO"


VBoxManage modifyvm "$VM" --audiocontroller ac97

VBoxManage export "$VM" -o "${VM}.ova"

# Clean up the generated vm?
# VBoxManage unregistervm "$VM" --delete

