#!/bin/bash
# Stock Samsung kernel for Samsung Exynos 5420 devices build script by jcadduono

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this
# file to point to the toolchain's root directory.
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh [VARIANT]
#
###################### DEVICES #####################
#
# chagalllte  = Galaxy Tab S 10.5 LTE      (SM-T805)
# chagall3g   = Galaxy Tab S 10.5 3G       (SM-T801)
# chagallwifi = Galaxy Tab S 10.5 WiFi     (SM-T800)
# klimtlte    = Galaxy Tab S 8.4 LTE       (SM-T705)
# klimt3g     = Galaxy Tab S 8.4 3G        (SM-T701)
# klimtwifi   = Galaxy Tab S 8.4 WiFi      (SM-T700)
# ha3g        = Galaxy Note 3 3G           (SM-N9000)
# n1a3g       = Galaxy Note 10.1 2014 3G   (SM-P601)
# n1awifi     = Galaxy Note 10.1 2014 WiFi (SM-P600)
# n2a3g       = Galaxy Tab Pro 10.1 3G     (SM-T521)
# n2awifi     = Galaxy Tab Pro 10.1 WiFi   (SM-T520)
# v1a3g       = Galaxy Note Pro 12.2 3G    (SM-P901)
# v1awifi     = Galaxy Note Pro 12.2 WiFi  (SM-P900)
# v2a3g       = Galaxy Tab Pro 12.2 3G     (SM-T901)
# v2awifi     = Galaxy Tab Pro 12.2 WiFi   (SM-T900)
#
###################### CONFIG ######################

# root directory of universal5420 kernel git repo (default is this script's location)
RDIR=$(pwd)

[ "$VER" ] ||
# version number
VER=$(cat "$RDIR/VERSION")

# directory containing cross-compile armhf toolchain
TOOLCHAIN=~/gcc-linaro-4.10

CPU_THREADS=$(grep -c "processor" /proc/cpuinfo)
# amount of cpu threads to use in kernel make process
THREADS=$((CPU_THREADS + 1))

############## SCARY NO-TOUCHY STUFF ###############

ABORT()
{
	[ "$1" ] && echo "Error: $*"
	exit 1
}

export ARCH=arm
export CROSS_COMPILE=$TOOLCHAIN/bin/arm-eabi-

[ -x "${CROSS_COMPILE}gcc" ] ||
ABORT "Unable to find gcc cross-compiler at location: ${CROSS_COMPILE}gcc"

[ "$TARGET" ] || TARGET=Angelo
[ "$1" ] && DEVICE=$1
[ "$2" ] && VARIANT=$2
[ "$DEVICE" ] || DEVICE=Note3
[ "$VARIANT" ] || VARIANT=V2
[[ $MODEL = ha3g ]]

DEFCONFIG=${TARGET}_defconfig
DEVICE_DEFCONFIG=device_${DEVICE}_${VARIANT}

[ -f "$RDIR/arch/$ARCH/configs/${DEFCONFIG}" ] ||
ABORT "Config $DEFCONFIG not found in $ARCH configs!"

[ -f "$RDIR/arch/$ARCH/configs/${DEVICE_DEFCONFIG}" ] ||
ABORT "Device config $DEVICE_DEFCONFIG not found in $ARCH configs!"

export LOCALVERSION=$TARGET-$DEVICE-$VARIANT-$VER

CLEAN_BUILD()
{
	echo "Cleaning build..."
	rm -rf build
}

SETUP_BUILD()
{
	echo "Creating kernel config for $LOCALVERSION..."
	mkdir -p build
	make -C "$RDIR" O=build "$DEFCONFIG" \
		DEVICE_DEFCONFIG="$DEVICE_DEFCONFIG" \
		|| ABORT "Failed to set up build"
}

BUILD_KERNEL() {
	echo "Starting build for $LOCALVERSION..."
	while ! make -C "$RDIR" O=build -j"$THREADS"; do
		read -rp "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) return 1 ;;
		esac
	done
}

INSTALL_MODULES() {
	grep -q 'CONFIG_MODULES=y' build/.config || return 0
	echo "Installing kernel modules to build/lib/modules..."
	while ! make -C "$RDIR" O=build \
			INSTALL_MOD_PATH="." \
			INSTALL_MOD_STRIP=1 \
			modules_install
	do
		read -rp "Build failed. Retry? " do_retry
		case $do_retry in
			Y|y) continue ;;
			*) return 1 ;;
		esac
	done
	rm build/lib/modules/*/build build/lib/modules/*/source
}

FUNC_BUILD_RAMDISK()
{
	mv $RDIR/arch/$ARCH/boot/zImage $RDIR/arch/$ARCH/boot/boot.img-zImage

	case $MODEL in
	chagalllte)
		rm -f $RDIR/ramdisk/SM-T805/split_img/boot.img-zImage
		mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-T805/split_img/boot.img-zImage
		cd $RDIR/ramdisk/SM-T805
		./repackimg.sh
		echo SEANDROIDENFORCE >> image-new.img
		;;
	chagallwifi)
		rm -f $RDIR/ramdisk/SM-T800/split_img/boot.img-zImage
		mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-T800/split_img/boot.img-zImage
		cd $RDIR/ramdisk/SM-T800
		./repackimg.sh
		echo SEANDROIDENFORCE >> image-new.img
		;;
	klimtlte)
		rm -f $RDIR/ramdisk/SM-T705/split_img/boot.img-zImage
		mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-T705/split_img/boot.img-zImage
		cd $RDIR/ramdisk/SM-T705
		./repackimg.sh
		echo SEANDROIDENFORCE >> image-new.img
		;;
	ha3g)
		rm -f $RDIR/ramdisk/SM-N900/split_img/boot.img-zImage
		mv -f $RDIR/build/arch/$ARCH/boot/zImage $RDIR/ramdisk/SM-N900/split_img/boot.img-zImage
		cd $RDIR/ramdisk/SM-N900
		./repackimg.sh
		echo SEANDROIDENFORCE >> image-new.img
		;;
	klimtwifi)
		rm -f $RDIR/ramdisk/SM-T700/split_img/boot.img-zImage
		mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-T700/split_img/boot.img-zImage
		cd $RDIR/ramdisk/SM-T700
		./repackimg.sh
		echo SEANDROIDENFORCE >> image-new.img
		;;
	*)
		echo "Unknown device: $MODEL"
		exit 1
		;;
	esac
}


cd "$RDIR" || ABORT "Failed to enter $RDIR!"

CLEAN_BUILD &&
SETUP_BUILD &&
BUILD_KERNEL &&
INSTALL_MODULES &&
FUNC_BUILD_RAMDISK &&
echo "Finished building $LOCALVERSION!"
