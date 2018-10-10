#!/tmp/engine/bash

# Enhanced VRTheme engine
# Copyright aureljared@XDA, 2014-2016.
#
# Original VRTheme engine is copyright
# VillainROM 2011. All rights reserved.
# Edify-like methods defined below are
# copyright Chainfire 2011.
#
# Portions are copyright Spannaa@XDA 2015.
#
# Modified by djb77 in 2017 to use with Magisk Module Template.

# Declare busybox, output file descriptor, timecapture, and logging mechanism
bb="/tmp/engine/busybox"
datetime=$($bb date +"%m%d%y-%H%M%S")
OUTFD=$(ps | grep -v "grep" | grep -o -E "update_binary(.*)" | cut -d " " -f 3);
[[ $OUTFD != "" ]] || OUTFD=$(ps | grep -v "grep" | grep -o -E "updater(.*)" | cut -d " " -f 3);

SYSTEM=/system

ABDeviceCheck=$(cat /proc/cmdline | grep slot_suffix | wc -l)
if [ $ABDeviceCheck -gt 0 ];
then
  isABDevice=true
  SLOT=$(for i in `cat /proc/cmdline`; do echo $i | grep slot_suffix | awk -F "=" '{print $2}';done)
  SYSTEM=/system/system
else
  isABDevice=false
fi

# ROM checks
getpropval() {
	acquiredValue=`cat /$SYSTEM/build.prop | grep "^$1=" | cut -d"=" -f2 | tr -d '\r '`
	echo "$acquiredValue"
}
platformString=`getpropval "ro.build.version.release"`
platform=`echo "$platformString" | cut -d. -f1`
if [ "$platform" -ge "5" ]; then
	lollipop="1"
	friendlyname() {
		# Example: Return "Settings" for "Settings.apk"
		tempvar="$(echo $1 | $bb sed 's/.apk//g')"
		echo "$tempvar"
	}
	checkdex() {
		tmpvar=$(friendlyname "$2")
		if [ -e ./classes.dex ]; then
			rm -f "/data/dalvik-cache/arm/system@$1@$tmpvar@$2.apk@classes.dex"
		fi
	}
else
	checkdex() {
		if [ -e ./classes.dex ]; then
			if [ -e "/data/dalvik-cache/system@$1@$2@classes.dex" ]; then
				rm -f "/data/dalvik-cache/system@$1@$2@classes.dex"
			else
				rm -f "/cache/dalvik-cache/system@$1@$2@classes.dex"
			fi
		fi
	}
fi

# Define some more methods
dir() {
	# Make folder $1 if it doesn't exist yet
	if [ ! -d "$1" ]; then
		$bb mkdir -p "$1"
	fi
}

theme(){
	pathsys="$SYSTEM/$2" # system/priv-app
	path="$1/$2"
	applypath="apply/$path"
	path_magisk="/tmp/magisk_tmp"

	cd "$vrroot/$path/"
	dir "$vrroot/$applypath"

	for f in *.apk; do
		cd "$f"

		# Copy APK
		if [ "$lollipop" -eq "1" ]; then
			appPath="$(friendlyname $f)/$f"
			dir "$vrroot/$applypath/$(friendlyname $f)"
      dir "$path_magisk/$path/$(friendlyname $f)"
			cp "/$pathsys/$appPath" "$vrroot/$applypath/$(friendlyname $f)/"
		else
			cp "/$pathsys/$f" "$vrroot/$applypath/"
			appPath="$f"
		fi

		# Delete files in APK, if any
		mv "$vrroot/$applypath/$appPath" "$vrroot/$applypath/$appPath.zip"
		if [ -e "./delete.list" ]; then
			readarray -t array < ./delete.list
			for j in ${array[@]}; do
				/tmp/engine/zip -d "$vrroot/$applypath/$appPath.zip" "$j"
			done
			rm -f ./delete.list
		fi

		# Theme APK
		/tmp/engine/zip -r "$vrroot/$applypath/$appPath.zip" ./*
		mv "$vrroot/$applypath/$appPath.zip" "$vrroot/$applypath/$appPath"

		# Refresh bytecode if necessary
		checkdex "$2" "$f"

		# Finish up
		$bb cp -f $vrroot/$applypath/$appPath $path_magisk/$path/$appPath
		chmod 644 $path_magisk/$path/$appPath
		cd "$vrroot/$path/"
	done
}

theme_framework(){
	pathsys="$SYSTEM/$2" # system/priv-app
	path="$1/$2"
	applypath="apply/$path"
	path_magisk="/tmp/magisk_tmp"

	cd "$vrroot/$path/"
	dir "$vrroot/$applypath"

	for f in *.apk; do
		cd "$f"

		# Copy APK
		if [ "$lollipop" -eq "1" ]; then
			appPath="$f"
			dir "$vrroot/apply/$path"
      dir "$path_magisk/$path"
			cp "/$pathsys/$appPath" "$vrroot/$applypath"
		else
			cp "/$pathsys/$appPath" "$vrroot/$applypath/"
			appPath="$f"
		fi

		# Delete files in APK, if any
		mv "$vrroot/$applypath/$appPath" "$vrroot/$applypath/$appPath.zip"
		if [ -e "./delete.list" ]; then
			readarray -t array < ./delete.list
			for j in ${array[@]}; do
				/tmp/engine/zip -d "$vrroot/$applypath/$appPath.zip" "$j"
			done
			rm -f ./delete.list
		fi

		# Theme APK
		/tmp/engine/zip -r "$vrroot/$applypath/$appPath.zip" ./*
		mv "$vrroot/$applypath/$appPath.zip" "$vrroot/$applypath/$appPath"

		# Refresh bytecode if necessary
		checkdex "$2" "$f"

		# Finish up
		$bb cp -f $vrroot/$applypath/$appPath $path_magisk/$path/$appPath
		chmod 644 $path_magisk/$path/$appPath
		cd "$vrroot/$path/"
	done
}

# Work directories
vrroot="/data/tmp/eviltheme"
dir "$vrroot/apply"

# Start theming
[ -d "$vrroot/system/app" ] && sysapps=1 || sysapps=0
[ -d "$vrroot/system/priv-app" ] && privapps=1 || privapps=0
[ -d "$vrroot/system/framework" ] && framework=1 || framework=0
[ -d "$vrroot/system/framework/samsung-framework-res" ] && samsung_framework=1 || samsung_framework=0
[ -d "$vrroot/preload/symlink/system/app" ] && preload=1 || preload=0

# /system/app
if [ "$sysapps" -eq "1" ]; then
	theme "system" "app"
fi

# /preload/symlink/system/app
if [ "$preload" -eq "1" ]; then
	theme "preload/symlink/system" "app"
fi

# /system/priv-app
if [ "$privapps" -eq "1" ]; then
	theme "system" "priv-app"
fi

# /system/framework
if [ "$framework" -eq "1" ]; then
	theme_framework "system" "framework"
fi

# /system/framework/samsung-framework-res
if [ "$samsung_framework" -eq "1" ]; then
	theme_framework "system/framework" "samsung-framework-res"
fi

# Cleanup
$bb rm -fR /data/tmp/eviltheme
$bb rm -fR /tmp/engine
$bb rm -fR /data/tmp/system

exit 0
