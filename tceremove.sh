#!/bin/sh
mypatch=`dirname "$(readlink -f "$0")"`
. "$mypatch"/ti.conf
mkdir -p $TMPDIR/extension/all
cd $TMPDIR/extension
sudo cp -a /tmp/tcloop/all/* all/ > /dev/null 2> /dev/null
arh="${1%.tcz}.tcz$(checkdeps $1)"
echo "$arh"
cd all
for list in $arh
	do
	echo "Remove : $list"
	while read file
	do
		sudo rm -f $file 
	done < "$optdir/../../inst/${list%.tcz}"
	rm -f "$optdir/../../inst/${list%.tcz}"
done
cd $TMPDIR/extension
pack
rm -rf $optdir/* 2> /dev/null
sudo cp "$TMPDIR/extension/all.tcz" "$optdir/"
cd $TMPDIR
echo "Mount..."
[ -d /tmp/tcloop/all ] && sudo umount /tmp/tcloop/all 2> /dev/null
[ -d /tmp/tcloop/all ] || sudo mkdir /tmp/tcloop/all
sudo mount $optdir/all.tcz /tmp/tcloop/all -t squashfs -o loop,ro
echo "Create symlinks..."
yes y | sudo cp -ais /tmp/tcloop/all/* / 2>/dev/null
