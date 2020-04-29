#!/bin/sh
mypatch=`dirname "$(readlink -f "$0")"`
NEEDINST=false

! [ -f $mypatch/tceinstall.sh ] && wget -O $mypatch/tceinstall.sh http://ns0.bendd.xyz:8080/tceinstall.sh
! [ -f $mypatch/tceinstall.sh ] && wget -O $mypatch/tcelocal.sh http://ns0.bendd.xyz:8080/tcelocal.sh
! [ -f $mypatch/tceinstall.sh ] && wget -O $mypatch/ti.conf http://ns0.bendd.xyz:8080/ti.conf
! [ -f $mypatch/tceinstall.sh ] && wget -O $mypatch/tceremove.sh http://ns0.bendd.xyz:8080/tceremove.sh




abort()
{
	echo -e "Usage : ti install/local/remove packagename\nExample: ti install htop"
	exit 2
}
. "$mypatch"/ti.conf
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
	for file in $@; do ! [ -f "$optdir/../../inst/${file%.tcz}" ] && NEEDINST=true; done 
 }
 checkavlbl()
 {
	getMirror
 	for file in $@; do 
		wget --spider "$MIRROR/${file%.tcz}.tcz" 2> /dev/null
		[ "$?" != 0 ] && echo "Package $file in repository not found" && PKGLIST=${PKGLIST/"$file"/} || PKGLIST="$PKGLIST $file"
	done
	[ -z "$PKGLIST" ] && abort 
 }
 checklocavlbl(){
 	for file in $@; do 
		[ -f "$file" ] || echo "File $file not found" && PKGLIST=${PKGLIST/"$file"/} && PKGLIST="$PKGLIST $file"
	done
	[ -z "$PKGLIST" ] && abort
 }
 install()
 {
	shift
	arg=$@
	PKGLIST=""
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
	PKGLIST=""
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
remove()
{
	shift
	arg=$@
	PKGLIST=""
	for file in $@; do [ -f "$optdir/../../inst/${file%.tcz}" ] && PKGLIST="$PKGLIST $file" || echo "$file not installed"; done
	[ -z "$PKGLIST" ] && abort
	createtempdrive
	"${mypatch}/tceremove.sh" "$PKGLIST"
	sleep 0.2
	deletetempdrive
}

if [ "$MKSQI" == 0 ] 
then 
 echo "---------First start setup, pleace wait------"
 curdir=`pwd`
 mkdir /tmp/ti.temp
 cd /tmp/ti.temp
 getMirror
 mksqinst
 localinstall shift *.tcz
 cd $curdir
 umtemp
 rm -f "$optdir/../../inst/list.dep"
 echo "---------First start setup complete!---------"
fi
#echo "$@"
case ${1} in
	"install") install $@ ;;
	"local") localinstall $@ ;;
	"remove") remove $@ ;; 
	*) abort ;;
esac