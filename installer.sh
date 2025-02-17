#!/bin/sh

##############################################
#  Handle options
##############################################

usage() {
	echo "Usage: $0 [-dh] [-r ref]"
	echo '       Options:'
	echo '           -d:      Debug mode: verbose output, and disable self-removing'
	echo '                    for ``bsd-cloudinit`` script dir.'
	echo '           -h:      Show this help message.'
	echo '           -r ref:  A valid git reference. Default is ``master``.'
}

args=`getopt hdr: $*`

if [ $? -ne 0 ]
then
	usage
	exit 1
fi
while [ $1 ]
do
	case $1 in
		-d )
			BSDINIT_DEBUG=yes
			shift
			;;
		-h )
			usage
			exit 0
			;;
		-r )
			shift
			GIT_REF=$1
			shift
			;;
		* )
			shift
			;;
	esac
done


##############################################
#  variables
##############################################

# args
GIT_REF=${GIT_REF:-'master'}

# env
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# files and dirs
SSH_DIR='/etc/ssh'
RC_SCRIPT_FILE='/etc/rc.local'
RC_CONF='/etc/rc.conf'
LOADER_CONF='/boot/loader.conf'
WORKING_DIR='/tmp'
BSDINIT_DIR="$WORKING_DIR/cloud-init"
RC_D='/etc/rc.d'

# bsd cloudinit
BSDINIT_URL="https://api.github.com/repos/alexyz79/cloud-init/tarball/$GIT_REF"

# commands
VERIFY_PEER='--ca-cert=/usr/local/share/certs/ca-root-nss.crt'
FETCH="fetch ${VERIFY_PEER}"

INSTALL_PKGS='
	security/sudo
	security/ca_root_nss
	py36-pip
	nano
'

##############################################
#  utils
##############################################
	
echo_debug() {
	echo '[debug] '$1
}

echo_bsdinit_stamp() {
	echo '# Generated by bsd-cloudinit-installer '`date +'%Y/%m/%d %T'`
}

##############################################
#  main block
##############################################

# Get freebsd version
if uname -K > /dev/null 2>&1
then
	BSD_VERSION=`uname -K`
else
	_BSD_VERSION=`uname -r | cut -d'-' -f 1`
	BSD_VERSION=$(printf "%d%02d%03d" `echo ${_BSD_VERSION} | cut -d'.' -f 1` `echo ${_BSD_VERSION} | cut -d'.' -f 2` 0)
fi

if [ $BSDINIT_DEBUG ]
then
	echo_debug "BSD_VERSION = $BSD_VERSION"
	BSDINIT_SCRIPT_DEBUG_FLAG='--debug'
fi

# Raise unsupport error
[ "$BSD_VERSION" -lt 903000 ] && {
	echo 'Oops! Your freebsd version is too old and not supported!'
	exit 1
}

# Install our prerequisites
export ASSUME_ALWAYS_YES=yes
pkg install $INSTALL_PKGS

if [ $BSDINIT_DEBUG ]
then
	TAR_VERBOSE='-v'
fi

echo "Fetching ref=$GIT_REF and extract tarball to $BSDINIT_DIR ..."
mkdir -p $BSDINIT_DIR
$FETCH -o - $BSDINIT_URL | tar -xzf - -C $BSDINIT_DIR --strip-components 1 $TAR_VERBOSE
echo 'Done'

cd $BSDINIT_DIR
pip install --upgrade --force-reinstall pip
pip install -r "$BSDINIT_DIR/requirements.txt"
python3.6 setup.py build
python3.6 setup.py install --init-system sysvinit
cp $BSDINIT_DIR/sysvinit/freebsd/* $RC_D
chmod 555 $BSDINIT_DIR/sysvinit/freebsd/cloud*
rm -vf $SSH_DIR/ssh_host*
if ! /usr/bin/egrep '^cloudinit_enable="YES"' $RC_CONF > /dev/null
then
echo 'cloudinit_enable="YES"' >> $RC_CONF
fi
if ! /usr/bin/egrep '^console="comconsole"' $LOADER_CONF > /dev/null
then
	echo_bsdinit_stamp >> $LOADER_CONF
	echo 'console="comconsole"' >> $LOADER_CONF
	echo 'autoboot_delay="1"' >> $LOADER_CONF
	sed -i '' 's/dcons   "\/usr\/libexec\/getty std.9600"   vt100   off secure/dcons   "\/usr\/libexec\/getty std.9600"   vt100   on secure/' /etc/ttys
fi
# Enabel sshd in rc.conf
if ! /usr/bin/egrep '^sshd_enable' $RC_CONF > /dev/null
then
	echo 'sshd_enable="YES"' >> $RC_CONF
fi
# Allow %wheel to become root with no password
sed -i '' 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /usr/local/etc/sudoers
dd if=/dev/zero of=/dummy
rm /dummy