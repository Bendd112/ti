#!/bin/sh
mypatch=`dirname "$(readlink -f "$0")"`
args=$@
nargs=$#
REPACK=false
EXECINST=""
. $mypatch/ti.conf
getMirror
echo "0" > /tmp/appserr
mkdir $TMPDIR/extension
cd $TMPDIR/extension
for var in $args
do
	load $var
done
echo "Load complete with depenses"
fuckRepack
rm -rf $optdir/* 2> /dev/null
sudo cp "$TMPDIR/extension/all.tcz" "$optdir/"
cd $TMPDIR
echo "Mount..."
[ -d /tmp/tcloop/all ] && sudo umount /tmp/tcloop/all 2> /dev/null
[ -d /tmp/tcloop/all ] || sudo mkdir /tmp/tcloop/all
sudo mount $optdir/all.tcz /tmp/tcloop/all -t squashfs -o loop,ro
echo "Create symlinks..."
yes y | sudo cp -ais /tmp/tcloop/all/* / 2>/dev/null
#echo "ldconfig..."
sudo ldconfig 
if [ "$EXECINST" ] 
then
	for line in $EXECINST
	do	
		appname="${line%.tcz}"
		#echo "DEBUG:read exec files $appname"
		if [ -f "/usr/local/tce.installed/$appname" ] ;
		then 
			#echo "Execution script $appname"
			sudo /usr/local/tce.installed/$appname
		fi
	done 
fi
echo "1" > /tmp/appserr
echo "Complete!"  