#!/bin/sh
mypatch=`dirname "$(readlink -f "$0")"`
NEEDINST=false
. "$mypatch"/ti.conf
abort()
{
	echo -e "Usage : ti install/local packagename\nExample: ti install htop"
	exit 2
}
createtempdrive()
{
	echo "Create cache directory"
	sudo dd if=/dev/zero of=/mnt/sda1/VHD.img bs=1M count=$maxcache > /dev/null 2> /dev/null
	sudo mkfs.ext2 /mnt/sda1/VHD.img > /dev/null 2> /dev/null
	mkdir /mnt/temp
	sudo mount -t auto -o loop /mnt/sda1/VHD.img /mnt/temp/
	sudo chmod 0777 -R /mnt/temp
}
deletetempdrive()
{
	sudo umount /mnt/temp
	sudo rm -rf /mnt/temp
	sudo rm -f /mnt/sda1/VHD.img
}
 checkinstalled()
 {
	for file in $@; do [ -f "$optdir/../../inst/${file%.tcz}" ] || NEEDINST=true; done 
 }
 checkavlbl()
 {
	getMirror
 	for file in $@; do 
		wget --spider "$MIRROR/${file%.tcz}.tcz" 2> /dev/null
		[ "$?" != 0 ] && echo "Package $appname not found" && PKGLIST=${PKGLIST/"$file"/} || PKGLIST="$PKGLIST $file"
	done
	[ -z "$PKGLIST" ] && exit 3
 }
 checklocavlbl(){
 	for file in $@; do 
		[ -f "$file" ] || echo "Package $appname not found" && PKGLIST=${PKGLIST/"$file"/} && PKGLIST="$PKGLIST $file"
	done
	[ -z "$PKGLIST" ] && exit 3
 }
 install()
 {
	shift
	arg=$@
	checkavlbl $arg
	checkinstalled $arg
	"$NEEDINST" || echo "Already installed..."
	"$NEEDINST" || exit 1
	createtempdrive
	#echo ${mypatch}/tceinstall.sh
	"${mypatch}/tceinstall.sh" "$PKGLIST" 
	sleep 0.2
	deletetempdrive
}
localinstall()
{
	shift
	arg=$@
	checklocavlbl $arg
	checkinstalled $arg
	echo "$PKGLIST"
	"$NEEDINST" || echo "Already installed..."
	"$NEEDINST" || exit 1
	createtempdrive
	"${mypatch}/tcelocal.sh" "$PKGLIST" 
	sleep 0.2
	deletetempdrive
}
case ${1} in
	"install") install $@;;
	"local") localinstall $@ ;;
	*) abort ;;
esac