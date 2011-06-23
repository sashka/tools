#!/bin/bash
# Copyright © 2090 Alexey Maximov <amax@mail.ru>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the BSD License
#
#####################################################################################################################
#
# check user input for correct values
#
if [ -z "$1" ] ; then
    echo "Usage: $0 <arch> <path>";
    echo "<arch> should be i386 or amd64"
    echo "<path> default to /tmp"
    echo "example to run: $0 i386 /var/tmp"
    exit 1
fi

#####################################################################################################################
#
# define local variables
#
#export http_proxy="http://192.168.0.1:3128/"
VZ="/var/lib/vz"
RELEASE="squeeze"
REPOS="main contrib non-free"
MIRROR="http://ftp.de.debian.org"
MINBASE="netbase,net-tools,ifupdown,procps,locales,nano,iputils-ping,sudo,less,vim-nox,tcpdump,tcpflow,mc,iptraf,psmisc,zip,unzip,bzip2,openssh-server,telnet,dialog"
ARCH="$1"
MY_SSH_KEYS[1]="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAsOPDZ+dZ9h3WVXZjU0S9x8412ZifCRYA0dZVW/uUH8ZyuboKxkQe91R0UAPP8LMl5UgqiXeajkA9q0nBeFhwfJUI7qphiMM0fNrfDH/BEzXCcvQC8II5AtnLwQvFis9F0zEiplju6nUiyBzOUpQyFsgl4wfaNLcJgxnJXHs05xc= rsa-key-20101024"
MY_SSH_KEYS[2]="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq7Ygask78BlVQUKV/lU3Dh45pm1fa7SY+rwiP3WVE+NUtxIaSZVJmRy/YQtPmFa86AR50ICCr8BoCSDumnjAhzNXdKKxKWXjNHZtCjLiHRW5ClUJCvqKEPXh35t++WtYXdnaQG0lKUjYrBNR+1YaI/Kxs8PRvZO8w9UmLevpN1hUu9Vu37ffso3Ss1zdbkKuSS/8pTUj0yHP+fWzee8b9xK/r/QGY8IiQUvhkC+cILQSBNKUQ+0B4h/ENlkDVog5ZXQBs9i+jdgi683/e/PU+3lFfAqHGzwiHPlzSC6krMiQg80mfDDQm9tkcymUkg9lNYfu3vuKI317wCbFXOKFZQ== amax@amazing.local"
TIMEZONE="Europe/Moscow"
BASE_PKG="rsyslog wget cron iptables traceroute logrotate exim4-daemon-light exim4-config bsd-mailx"


#exit 1
VE=$(mktemp -d)
if [ ! -z "$2" ] ; then
 VE=$(mktemp -d --tmpdir "$2")
fi

#####################################################################################################################
#
# create new minimal VE
#
if ! [ -x /usr/sbin/debootstrap ];then
    echo "/usr/sbin/debootstrap not found or not executable, consider installing debootstrap package"
    exit 1
fi
debootstrap --arch=$ARCH --variant=minbase --include=$MINBASE $RELEASE $VE $MIRROR/debian
if [ $? -ne 0 ];then
    echo "deboostrap failed, process aborted, removing $VE"
    echo rm -rf $VE
    exit 1
fi
cp /etc/resolv.conf $VE/etc/
cat << EOF > $VE/usr/sbin/policy-rc.d
#!/bin/sh
exit 101
EOF
chmod +x $VE/usr/sbin/policy-rc.d
mount -t proc proc $VE/proc
mount -t devpts devpts $VE/dev/pts -o rw,noexec,nosuid,gid=5,mode=620

#####################################################################################################################
#
# Prepare locale settings
#
echo "LANG=en_US.UTF-8" > $VE/etc/default/locale
cat << EOF > $VE/etc/locale.gen
en_US.UTF-8 UTF-8
ru_RU.CP1251 CP1251
ru_RU.UTF-8 UTF-8
ru_RU.KOI8-R KOI8-R
EOF
echo -n > $VE/etc/locale.alias
chroot $VE sh -c "locale-gen"


#####################################################################################################################
#
# tune VE settings
#
chroot $VE sh -c "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
chroot $VE sh -c "ln -sf /proc/mounts /etc/mtab"

echo "APT::Install-Recommends \"false\";" > $VE/etc/apt/apt.conf.d/00InstallRecommends
chmod 700 $VE/root
sed -i -e "/getty/d" $VE/etc/inittab
sed -i -e "s:RAMRUN=no:RAMRUN=yes:g" $VE/etc/default/rcS
sed -i -e "s:RAMLOCK=no:RAMLOCK=yes:g" $VE/etc/default/rcS
echo "HWCLOCKACCESS=no" >> $VE/etc/default/rcS
echo "ulimit -s 1024" > $VE/etc/lsb-base-logging.sh

cat << EOF > $VE/etc/default/tmpfs
# SHM_SIZE sets the maximum size (in bytes) that the /dev/shm tmpfs can use.
# If this is not set then the size defaults to the value of TMPFS_SIZE
# if that is set; otherwise to the kernel's default.
#
# The size will be rounded down to a multiple of the page size, 4096 bytes.
SHM_SIZE=
TMPFS_SIZE=
RUN_SIZE=2M
LOCK_SIZE=2M
RW_SIZE=2M
EOF


#####################################################################################################################
#
# create new VE sources.list
#
cat << EOF > $VE/etc/apt/sources.list
deb $MIRROR/debian $RELEASE $REPOS
#deb-src $MIRROR/debian $RELEASE $REPOS
deb http://security.debian.org/ $RELEASE/updates $REPOS
#deb-src http://security.debian.org/ $RELEASE/updates $REPOS
deb $MIRROR/debian $RELEASE-updates $REPOS
#deb-src $MIRROR/debian $RELEASE-updates $REPOS
EOF


#####################################################################################################################
#
# update VE
#
chroot $VE sh -c "DEBIAN_FRONTEND=noninteractive apt-get -y update"
chroot $VE sh -c "DEBIAN_FRONTEND=noninteractive apt-get -y upgrade"
chroot $VE sh -c "DEBIAN_FRONTEND=noninteractive apt-get -y install $BASE_PKG"
chroot $VE sh -c "DEBIAN_FRONTEND=noninteractive apt-get -y autoremove"
chroot $VE sh -c "DEBIAN_FRONTEND=noninteractive apt-get -y clean"



#####################################################################################################################
#
# final tune VE
#
sed -i -e "s:SHELL=/bin/sh:SHELL=/bin/bash:g" $VE/etc/default/useradd
cat << EOF >> $VE/etc/default/ssh
# OOM-killer adjustment for sshd (see
# linux/Documentation/filesystems/proc.txt; lower values reduce likelihood
# of being killed, while -17 means the OOM-killer will ignore sshd; set to
# the empty string to skip adjustment)
SSHD_OOM_ADJUST=-17
EOF

if [ -z "${!MY_SSH_KEYS[*]}" ];then
    echo "SSH KEYS are empty, skipping..."
else
    mkdir $VE/root/.ssh
    chmod 0640 $VE/root/.ssh
    echo -n > $VE/root/.ssh/authorized_keys
    for I in ${!MY_SSH_KEYS[*]}; do
        echo "${MY_SSH_KEYS[$I]}" >> $VE/root/.ssh/authorized_keys
    done
    chmod 0640 $VE/root/.ssh/authorized_keys
fi



#####################################################################################################################
#
# Prepare ssh keys
#
cat << EOF > $VE/etc/init.d/ssh_gen_host_keys
#!/bin/sh
### BEGIN INIT INFO
# Provides:          Generates new ssh host keys on first boot
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:
# Short-Description: Generates new ssh host keys on first boot
# Description:       Generates new ssh host keys on first boot
### END INIT INFO
[ -f /usr/bin/ssh-keygen ] || exit 0
ssh-keygen -f /etc/ssh/ssh_host_rsa_key -t rsa -N ""
ssh-keygen -f /etc/ssh/ssh_host_dsa_key -t dsa -N ""
insserv -r /etc/init.d/ssh_gen_host_keys
rm -f \$0
EOF

chmod 755 $VE/etc/init.d/ssh_gen_host_keys
chroot $VE sh -c "insserv /etc/init.d/ssh_gen_host_keys"


#####################################################################################################################
#
# umount VE and prepare to bundle
#
rm -f $VE/usr/sbin/policy-rc.d
umount -f $VE/proc
umount -f $VE/dev/pts


#####################################################################################################################
#
# cleanup VE
#
echo -n > $VE/etc/motd.tail
echo -n > $VE/etc/resolv.conf
echo -n > $VE/etc/network/interfaces

rm -f $VE/etc/ssh/*key*
rm -f $VE/root/.bash_history
rm -rf $VE/var/log/news
rm -rf $VE/selinux

find $VE/tmp/ -type f -delete

find $VE/var/log/ -type f -delete
find $VE/var/run/ -type f -delete
find $VE/var/lock/ -type f -delete
find $VE/var/tmp/ -type f -delete

find $VE/var/lib/apt/lists/ -type f -delete
find $VE/var/cache/apt/ -type f -delete
find $VE/var/cache/debconf/ -type f -name \*-old -delete


# crap idea
#rm -rf $VE/etc/init.d/mountoverflowtmp

### compress image
( cd $VE && tar --numeric-owner --one-file-system -czf "$VZ/template/cache/debian-6.0.1-$ARCH-minimal.tar.gz" . )


