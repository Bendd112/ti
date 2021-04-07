#!/bin/sh
NEEDINST=false
WORKDIR=$(readlink /etc/sysconfig/tcedir)
optdir=$WORKDIR/optional
TMPDIR=$WORKDIR/TMP
KERNELVER=$(uname -r)
MKSQI=$([ -f /usr/local/bin/mksquashfs ] && echo 1 || echo 0)
LISTDEP="$optdir/../inst/list.dp"
_DOWNLIST=""
#_DOWNLINKS=""
. /etc/init.d/busybox-aliases
abort(){
	echo -e "Usage : ti {install,local,remove,load [-d]} packagename\nti pae(WIP): Packing all packages\nExample: ti install htop"
	exit 2
}
eabort(){
	errnum=$1
	echo "Exit with error:$errnum"
	echo "$2"
	exit $errnum
}
getMajorVer() {
	awk '{printf "%d", $1}' /usr/share/doc/tc/release.txt 
}
checkroot() {
	if [ `/usr/bin/id -u` -ne 0 ]; then
		echo "Need root privileges." >&2
		exit 1
	fi
}
getBuild() {
	BUILD=`uname -m`
	case ${BUILD} in
		armv6l) echo "armv6" ;;
		armv7l) echo "armv7" ;;
		i686)   echo "x86" ;;
		x86_64) [ -f /lib/ld-linux-x86-64.so.2 ] && echo "x86_64" || echo "x86" ;;
		*)      echo "x86" ;;
	esac
}
getMirror() {
	BUILD=$(getBuild)
	read MIRROR < /opt/tcemirror
	[ "$MIRROR" ] || eabort 9 "Mirror not found"
	MIRROR="${MIRROR%/}/$(getMajorVer).x/$BUILD/tcz"
}
repack(){
	mkdir "all"
	_args=$@
	cp -a /tmp/tcloop/all/* all/ > /dev/null 2> /dev/null
	for file in $_args; do
		EXECINST="$EXECINST $file"
		dirname="${file%.tcz}"
		mkdir -p /tmp/tcztmp/$dirname
		mount $file /tmp/tcztmp/$dirname -t squashfs -o loop,ro
		cd /tmp/tcztmp/$dirname
		find -type f > "${optdir}/../inst/$dirname"
		cd $TMPDIR
		cp -a /tmp/tcztmp/$dirname/* all/ 
		umount /tmp/tcztmp/$dirname
	done
	rm -rf /tmp/tcztmp
	pack
}
pack (){
	echo "#!/bin/sh" > all/usr/local/tce.installed/all
	for file in all/usr/local/tce.installed/*
	do
		! [ "$file" == "all/usr/local/tce.installed/all" ] && echo "${file/all}" >> all/usr/local/tce.installed/all 
	done
	chmod +x all/usr/local/tce.installed/all
	echo "Packing..."
	mksquashfs all/ all.tcz -quiet -progress || eabort 10 "Error in mksquashfs process"
	chmod 0777 all.tcz
	echo "done"
}
exscr () {
	for list in $@
	do
		[ -f /usr/local/tce.installed/${list%.tcz} ] && /usr/local/tce.installed/${list%.tcz}
	done
}
loaddeps (){
	getrecDep "$1"
	[ -n "$(ls -A | grep .dep)" ] || return 0
	for file in *.dep
	do
		[ "squashfs-tools.tcz.dep" == "$file" ] && [ "$MKSQI" == 1 ] && continue
		echo -n "${file%.dep}:" >> "$LISTDEP"
		while IFS= read -r line; do
			down="${line//-KERNEL.tcz/-${KERNELVER}.tcz}"
			echo -n "$down " >> "$LISTDEP"
			if [ -f "$optdir/../inst/${down%.tcz}" ] ;
			then 
				echo "Already installed: $down"
			else
				_DOWNLIST="$_DOWNLIST $down"
				#_DOWNLINKS="$_DOWNLINKS\n$MIRROR/$down"
			fi
		 done < "$file"
		 echo -ne "\n" >> "$LISTDEP"
	done
	rm -f *.dep
}
loadwd(){
	for _list in $@
	do
		pkgname="${_list%.tcz}.tcz"
		loaddeps "$pkgname"
		#_DOWNLINKS="$_DOWNLINKS\n$MIRROR/$pkgname"
		_DOWNLIST="$_DOWNLIST $pkgname"
	
	done
	for _wget in $_DOWNLIST
	do
		[ -f $_wget ] || wget $MIRROR/$_wget
	done
	#echo -e "$_DOWNLINKS" | awk '!($0 in a) {a[$0];print}' | xargs wget
}
load(){
	appname="${1%.tcz}.tcz"
	wget "$MIRROR/$appname"
}
getrecDep() {
	dep="$1"
	dep="${dep}.dep"
	dep="${dep//-KERNEL.tcz/-${KERNELVER}.tcz}"
	echo -ne "Get dependences:${dep%.}\033[0K\r"
	[ -f $dep ] || wget "$MIRROR/$dep" 2> /dev/null
	if [ -f "$dep" ]
	then
		while IFS= read -r line; do
			getrecDep "$line"
		done < "$dep"
	fi
}
readdep(){
	deps=""
	while read line; do
		[ "${line%%:*}" == "${1%.tcz}.tcz" ] && deps="${line#${1%.tcz}.tcz:}"
	done < "$LISTDEP"
	echo "$deps"
	! [ -z "$deps" ] && for list in $deps; do echo $(readdep $list);done
}
checkdeps(){
	dep=$(readdep $1)
	for list in $dep
	do
		! [ $(expr $(grep "$list" "$LISTDEP" | wc -l) - $(grep "$list:" "$LISTDEP" | wc -l)) -ge "2" ] && echo -n " $list"
	done
}
chekintconn(){
	ping 8.8.8.8 -c 1 -W 1 > /dev/null || eabort 5 "Check internet connection"
}
tceremove(){
	mkdir -p $TMPDIR/all
	cd $TMPDIR
	echo -ne "Copy old..."
	cp -a /tmp/tcloop/all/* all/ > /dev/null 2> /dev/null
	echo "Done"
	arh="${1%.tcz}.tcz$(checkdeps $1)"
	cd all
	for list in $arh
	do
		echo "Remove : ${list%.tcz}"
		while read file
		do
			rm -f $file
		done < "$optdir/../inst/${list%.tcz}"
		sed -i "/$list/d" $LISTDEP
		rm -f "$optdir/../inst/${list%.tcz}"
	done
	cd $TMPDIR
	find -L -type l | xargs rm -f
	pack
	rm -rf $optdir/* 2> /dev/null
	cp "$TMPDIR/all.tcz" "$optdir/."
	echo "Mount..."
	[ -d /tmp/tcloop/all ] &&  umount /tmp/tcloop/all 2> /dev/null
	[ -d /tmp/tcloop/all ] ||  mkdir /tmp/tcloop/all
	mount $optdir/all.tcz /tmp/tcloop/all -t squashfs -o loop,ro
	echo "Create symlinks..."
	yes y |  cp -ais /tmp/tcloop/all/* / 2>/dev/null
}
tcelocal(){
	EXECINST=""
	echo "0" > /tmp/appserr
	pkglist=""
	_args=$@
	for pkg in $_args
	do
		pkglist="$pkglist ${pkg%.tcz}.tcz"
	done
	cd "$TMPDIR"
	repack $pkglist
	rm -rf $optdir/* 2> /dev/null
	cp "$TMPDIR/all.tcz" "$optdir/"
	echo "Mount..."
	[ -d /tmp/tcloop/all ] &&  umount /tmp/tcloop/all 2> /dev/null
	[ -d /tmp/tcloop/all ] ||  mkdir /tmp/tcloop/all
	mount $optdir/all.tcz /tmp/tcloop/all -t squashfs -o loop,ro
	echo "Create symlinks..."
	yes y |  cp -ais /tmp/tcloop/all/* / 2>/dev/null
	#echo "ldconfig..."
	ldconfig 2>/dev/null
	exscr $EXECINST
	echo "Depmod..."
	depmod
	echo "1" > /tmp/appserr
	echo "Complete!"
}
tceinstall() {
	args=$@
	getMirror
	cd $TMPDIR
	loadwd $args
	echo "Load complete with depencies"
	tcelocal $_DOWNLIST
	rm -f $_DOWNLIST
}
mktmp(){
	mkdir $TMPDIR
	chmod 0777 -R $TMPDIR
}
rmtmp(){
	rm -rf $TMPDIR
}
checkinstalled(){
	for file in $@; do ! [ -f "$optdir/../inst/${file%.tcz}" ] && NEEDINST=true; done 
 }
checkavlbl(){
	chekintconn
	getMirror
 	for file in $@; do 
		wget --spider "$MIRROR/${file%.tcz}.tcz" 2> /dev/null
		[ "$?" != 0 ] && echo "Package $file in repository not found" && PKGLIST=${PKGLIST/"$file"/} || PKGLIST="$PKGLIST $file"
	done
	[ -z "$PKGLIST" ] && eabort 2 "Package(s) not found!"
 }
checklocavlbl(){
 	for file in $@; do 
		[ -f "$file" ] || echo "File $file not found" && PKGLIST=${PKGLIST/"$file"/} && PKGLIST="$PKGLIST $file"
	done
	[ -z "$PKGLIST" ] && eabort 3 "Package(s) not found!"
 }
checksqfst(){
	if [ "$MKSQI" == 0 ] 
	then 
		chekintconn
		echo "---------First start setup, please wait------"
		mktmp
		cd $TMPDIR
		getMirror
		mkdir $optdir/../inst
		loadwd "squashfs-tools"
		mtab=""
		for tcz in *.tcz
		do
			[ -d /tmp/${tcz%.tcz} ] ||  mkdir /tmp/${tcz%.tcz}
			mount $tcz /tmp/${tcz%.tcz} -t squashfs -o loop,ro
			mtab="${mtab} /tmp/${tcz%.tcz}"
			yes n |  cp -ais /tmp/"${tcz%.tcz}"/* / 2>/dev/null
			ldconfig 2>/dev/null
		done
		tcelocal "*.tcz"
		for umt in $mtab
		do 
			umount $umt
		done
		cd - 2>/dev/null
		rm -f "$optdir/../inst/list.dp"
		rmtmp
		echo "all.tcz" > $WORKDIR/onboot.lst
		echo "---------First start setup complete!---------"
	fi
}
install(){
	shift
	checksqfst
	arg=$@
	PKGLIST=""
	checkavlbl $arg
	checkinstalled $arg
	"$NEEDINST" || echo "Already installed..."
	"$NEEDINST" || exit 1
	mktmp
	tceinstall "$PKGLIST" 
	rmtmp
}
localinstall(){
	shift
	checksqfst
	arg=$@
	PKGLIST=""
	checklocavlbl $arg
	checkinstalled $arg
	echo "$PKGLIST"
	"$NEEDINST" || echo "Already installed..."
	"$NEEDINST" || exit 1
	mktmp
	for _pkga in $PKGLIST 
	do
	       	cp $_pkga* $TMPDIR
	done
	tceinstall "$PKGLIST" 
	rmtmp
}
remove(){
	shift
	checksqfst
	arg=$@
	PKGLIST=""
	for file in $@; do [ -f "$optdir/../inst/${file%.tcz}" ] && PKGLIST="$PKGLIST $file" || echo "$file not installed"; done
	[ -z "$PKGLIST" ] && abort
	mktmp
	tceremove "$PKGLIST"
	rmtmp
}
loadfiles (){
	shift
	FLIST=""
	WDEPS="false"
	for args in $@
	do 
	[ "$args" == "-d" ] && WDEPS="true" || FLIST="$FLIST $args"	
	done
	checkavlbl "$FLIST"
	if $WDEPS; then 
		loadwd $FLIST
	else
		load $FLIST
	fi
}
packall(){
	echo "(WIP!)"
	
	
}
upgrade(){
	echo "(WIP!)"
}

checkroot
case ${1} in
	"install") install $@ ;;
	"local") localinstall $@ ;;
	"remove") remove $@ ;; 
	"load") loadfiles $@ ;;
	"pae") packall $@ ;;
	"upgrade") upgrade $@ ;;
	*) abort ;;
esac
