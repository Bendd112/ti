#!/bin/sh
mypatch=`dirname "$(readlink -f "$0")"`
args=$@
nargs=$#
REPACK=false
MKSQI=$([ -f /usr/local/bin/mksquashfs ] && echo 1 || echo 0)
EXECINST=""
. $mypatch/ti.conf
abort(){
 if $REPACK; then
 	return 0
 else
 echo "Bad try(("
 echo "1" > /tmp/appserr
 rm -f $VHDD
 sudo umount /mnt/temp 2> /dev/null
 exit 1
fi
}


mksqinst(){
	echo "---------First start setup, pleace wait------"
	echo all.tcz > $optdir/../onboot.lst                
	mkdir $optdir/../../inst                               
	load "squashfs-tools"                                 
	mtab=""
	REPACK=true
	for tcz in *tcz                                    
	do
		[ -d /tmp/tcloop/${tcz%.tcz} ] || sudo mkdir /tmp/tcloop/${tcz%.tcz}
		sudo mount $tcz /tmp/tcloop/${tcz%.tcz} -t squashfs -o loop,ro
		mtab="${mtab} /tmp/tcloop/${tcz%.tcz}"
		yes n | sudo cp -ais /tmp/tcloop/"${tcz%.tcz}"/* / 2>/dev/null
		sudo ldconfig 2>/dev/null          
	done                                                 
	echo "---------First start setup complete!---------"
}

umtemp(){
for um in $mtab;
do
	sudo umount $um
done
}


getrecDep() {
dep="$1"
dep="${dep}.dep"
#echo "$dep"
dep="${dep//-KERNEL.tcz/-${KERNELVER}.tcz}"
echo -ne "Get dependences:${dep%.}\033[0K\r"

#echo "$MIRROR/$dep"
wget "$MIRROR/$dep" 2> /dev/null
if [ -f "$dep" ] 
then
while IFS= read -r line; do
	getrecDep "$line"
done < "$dep"
fi
}


loaddeps (){
getrecDep "$1"
[ -n "$(ls -A | grep .dep)" ] || return 0
for file in *.dep 
do
 while IFS= read -r line; do
	down="${line//-KERNEL.tcz/-${KERNELVER}.tcz}"
	#echo "$optdir/../../inst/${down%.tcz}"
	if [ -f "$optdir/../../inst/${down%.tcz}" ] ;
	then 
		echo "Already installed: $down"
	else
		echo -ne "Download dependence: $down\033[0K\r"
		wget "$MIRROR/$down" 2> /dev/null
	fi
 done < "$file"
done
}
load()
{
 appname="${1%.tcz}.tcz"
 #echo "$optdir/../../inst/${appname%.tcz}"
#echo "$appname"
loaddeps "$appname"
echo -ne "Download: $appname\033[0K\r"
wget "$MIRROR/$appname" 
[ "$?" != 0 ] && abort
REPACK=true
rm -f *.dep

}
echo "0" > /tmp/appserr
mkdir $TMPDIR/extension
cd $TMPDIR/extension
getMirror
[ "$MKSQI" == 0 ] && mksqinst

for var in $args
do
	load $var
done

"$REPACK" || abort
echo "Load complete with depenses"
fuckRepack
[ "$MKSQI" == 0 ] && umtemp
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
