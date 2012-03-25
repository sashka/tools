#!/bin/bash

#buildir base
BUILDDIR="/usr/src"

#building tools, like make-kpkg
NEEDPACKAGES="build-essential kernel-package"


#kernel.org url for vanilla kernel
KERNEL_BASE_URL="http://www.kernel.org/pub/linux/kernel/v2.6"
OPENVZ_BASE_URL="http://download.openvz.org/kernel/branches"

declare -A KERNELINFO
KERNELINFO["base"]="2.6.32"
KERNELINFO["ovzname"]="042stab049.6"
KERNELINFO["rhelid"]="6"
KERNELINFO["rhelbranch"]="rhel6-2.6.32"
KERNELINFO["arch"]="x86_64"
#http://download.openvz.org/kernel/branches/rhel6-2.6.32/042stab049.6/configs/config-2.6.32-042stab049.6.x86_64
#http://download.openvz.org/kernel/branches/rhel6-2.6.32/042stab049.6/patches/patch-042stab049.6-combined.gz
#http://www.kernel.org/pub/linux/kernel/v2.6/linux-2.6.32.tar.bz2

#runtime configuration
kernel_name="linux-${KERNELINFO["base"]}"
patch_url="${OPENVZ_BASE_URL}/${KERNELINFO["rhelbranch"]}/${KERNELINFO["ovzname"]}/patches/patch-${KERNELINFO["ovzname"]}-combined.gz"
patch_filename="patch-${KERNELINFO["ovzname"]}-combined"
config_url="${OPENVZ_BASE_URL}/${KERNELINFO["rhelbranch"]}/${KERNELINFO["ovzname"]}/configs/config-${KERNELINFO["base"]}-${KERNELINFO["ovzname"]}.${KERNELINFO["arch"]}"
config_filename="config-${KERNELINFO["base"]}-${KERNELINFO["ovzname"]}.${KERNELINFO["arch"]}"

############
cd $BUILDDIR || exit 1

#checking packages
do_exit=0
for i in $NEEDPACKAGES;do
    dpkg -p "$i" >/dev/null
    if [ $? -ne 0 ];then
        echo "missing package $i"
        do_exit=1
    fi
done
if [ $do_exit -ne 0 ];then echo "exiting";exit 1;fi

#need to download compressed kernel image if it doesn't exist yet
if ! [ -f "$kernel_name.tar.bz2" ];then
    wget "${KERNEL_BASE_URL}/${kernel_name}.tar.bz2" -O "${kernel_name}.tar.bz2"
    if [ $? -ne 0 ];then #failed
        echo "download kernel tarball failed, exiting"
        exit 1
    fi
else
    echo "kernel tarball already exists, skipping download"
fi

#clearing old build directory, just in case
if [ -d "./${kernel_name}" ];then
    echo "removing old dir ./${kernel_name}"
    rm -rf "./${kernel_name}"
    if [ $? -ne 0 ];then #failed
        echo "remove failed, exiting"
        exit 1
    fi
fi

#unpacking archive
tar -xf "${kernel_name}.tar.bz2"
if [ $? -ne 0 ];then #failed
    echo "unpacking failed, exiting"
    exit 1
fi

#downloading config
if ! [ -f "$config_filename" ];then
    wget "$config_url" -O "$config_filename"
    if [ $? -ne 0 ];then #failed
        echo "download config failed, exiting"
        exit 1
    fi
else
    echo "config file already exists, skipping download"
fi

#..patch now
if ! [ -f "$patch_filename" ];then
    wget "$patch_url" -O "$patch_filename.gz"
    if [ $? -ne 0 ];then #failed
        echo "download patch failed, exiting"
        exit 1
    fi
    gzip -d "$patch_filename"
    if [ $? -ne 0 ];then #failed
        echo "unzip of patch failed, exiting"
        exit 1
    fi
 
else
    echo "patch file already exists, skipping download"
fi

#everything is downloaded, patching now
set -e
cd ${kernel_name}
#dry run for patch
patch --dry-run --verbose -p1 < "../$patch_filename" > ../patch.log
patch_retcode=$?
if [ $patch_retcode -ne 0 ];then
    echo "patch failed to apply clean. check ../patch.log. exiting"
    exit 1
fi

set +e

#checking if patch has failed hunks
fgrep -q 'FAILED at' "../patch.log"
if [ $? -eq 0 ]; then #grep found some failed strings or just patch failed, we should abort now
    echo "patch failed to apply clean. check ../patch.log. exiting"
    exit 1
else
    echo "patch should apply clean now, trying..."
    patch --verbose -p1 < "../$patch_filename" > ../patch.log
    if [ $? -ne 0 ]; then #patch failed somehow anyway
        echo "patch failed to apply clean. check ../patch.log. exiting"
        exit 1
    fi
fi

#kernel is patched now, copying config
cp ../"$config_filename" .config

#compiling
#how much cpu we have?
cpucount=$(fgrep processor /proc/cpuinfo|wc -l)
CMD="make-kpkg --jobs $cpucount --initrd --arch_in_name --append-to-version -${KERNELINFO["ovzname"]}-el${KERNELINFO["rhelid"]}-openvz --revision ${KERNELINFO["base"]}~coolcold binary-arch kernel_source"
echo $CMD
