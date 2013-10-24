#!/bin/sh

SSH_DIR=/etc/ssh
RC_SCRIPT_FILE='/etc/rc.local'
RC_BACKUP_FILE='/etc/rc.local.bak'
RC_CONF='/etc/rc.conf'
BSDINIT_URL="https://github.com/pellaeon/bsd-cloudinit/archive/master.tar.gz"


[ ! `which python2.7` ] && {
	echo 'python2.7 Not Found !' 
	exit 1
	}
PYTHON=`which python2.7`

fetch -o - $BSDINIT_URL | tar -xzvf - -C '/root'

rm -vf $SSH_DIR/ssh_host*

cp -pvf $RC_SCRIPT_FILE $RC_BACKUP_FILE
echo "(cd /root/bsd-cloudinit-master/ && $PYTHON ./cloudinit && cp -pvf $RC_BACKUP_FILE $RC_SCRIPT_FILE ) &" >> $RC_SCRIPT_FILE

# Get the active NIC and set it to use dhcp.
for i in `ifconfig -u -l`
do
	case $i in
		'lo0')
			;;
		'plip0')
			;;
		'pflog0')
			;;
		*)
			echo '# Generated by bsd-cloudinit-install '`date +'%Y/%m/%d %T'` >> $RC_CONF
			echo 'ifconfig_'${i}'="DHCP"' >> $RC_CONF
			break;
			;;
	esac
done

echo "" > /root/.history
