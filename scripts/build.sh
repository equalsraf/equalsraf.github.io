#!/bin/sh
set -eu
set -o pipefail
set -x

# Environment
ROOT=$(pwd)
export LFS=$ROOT/lfsroot
export LFS_TGT=x86_64-lfs-linux-musl 

export LFS_DOWNLOADS=$ROOT/tmp/downloads
export LFS_SRC=$ROOT/tmp/src
export LFS_BUILD=$ROOT/tmp/build
export LFS_TOOLS=$LFS/tools

P_BINUTILS=binutils-2.38
MPFR=mpfr-4.1.0
GMP=gmp-6.2.1
MPC=mpc-1.2.1
GCC=gcc-11.2.0
LINUX_KERNEL=linux-5.16.9
MUSL=musl-1.2.3
P_M4=m4-1.4.19
P_BASH=bash-5.1.16
P_COREUTILS=coreutils-9.0
P_DIFFUTILS=diffutils-3.8
P_FILE=file-5.41
P_FINDUTILS=findutils-4.9.0
P_GAWK=gawk-5.1.1
P_GREP=grep-3.7
P_GZIP=gzip-1.11
P_MAKE=make-4.3
P_PATCH=patch-2.7.6
P_SED=sed-4.8
P_TAR=tar-1.34
P_XZ=xz-5.2.5

# In some system CONFIG_SITE is set and gcc uses it to customized builds
unset CONFIG_SITE
mkdir -p $LFS_DOWNLOADS $LFS_SRC $LFS_BUILD


echo "Loading LFS env $LFS"

download_sources() {
	cd $LFS_DOWNLOADS
	aria2c -c --input-file=${ROOT}/sources.manifest
}

unpack_tarball() {
	local TARBALL=$1
	cd $LFS_SRC
	tar -axf ${LFS_DOWNLOADS}/${TARBALL}
}

prepare_sources() {
	cd $LFS_DOWNLOADS

	unpack_tarball ${P_BINUTILS}.tar.xz
	unpack_tarball ${MPFR}.tar.xz
	unpack_tarball ${GMP}.tar.xz
	unpack_tarball ${MPC}.tar.gz
	unpack_tarball ${GCC}.tar.xz
	unpack_tarball ${LINUX_KERNEL}.tar.xz
	unpack_tarball ${MUSL}.tar.gz
	unpack_tarball ${P_M4}.tar.xz
	unpack_tarball ${P_BASH}.tar.gz
	unpack_tarball ${P_COREUTILS}.tar.xz
	unpack_tarball ${P_DIFFUTILS}.tar.xz
	unpack_tarball ${P_FILE}.tar.gz
	unpack_tarball ${P_FINDUTILS}.tar.xz
	unpack_tarball ${P_GAWK}.tar.xz
	unpack_tarball ${P_GREP}.tar.xz
	unpack_tarball ${P_GZIP}.tar.xz
	unpack_tarball ${P_MAKE}.tar.gz
	unpack_tarball ${P_PATCH}.tar.xz
	unpack_tarball ${P_SED}.tar.xz
	unpack_tarball ${P_TAR}.tar.xz
	unpack_tarball ${P_XZ}.tar.xz

	# binutils patch (from LFS)
	sed '6009s/$add_dir//' -i ${LFS_SRC}/${P_BINUTILS}/ltmain.sh

	# GCC symlinks
	ln -snf $LFS_SRC/${MPFR} $LFS_SRC/${GCC}/mpfr
	ln -snf $LFS_SRC/${MPC} $LFS_SRC/${GCC}/mpc
	ln -snf $LFS_SRC/${GMP} $LFS_SRC/${GCC}/gmp
	# GCC lib64 -> lib
	sed -e '/m64=/s/lib64/lib/' -i.orig $LFS_SRC/${GCC}/gcc/config/i386/t-linux64

	# gawk remove extras
	sed -i 's/extrax//' ${LFS_SRC}/${P_GAWK}/Makefile.in
}


build_binutils_pass1() {
	BUILD=$LFS_BUILD/${P_BINUTILS}-pass1
	SRC=$LFS_SRC/${P_BINUTILS}
	mkdir -p $BUILD
	cd $BUILD

	$SRC/configure --prefix=$LFS_TOOLS \
		       --libdir=$LFS_TOOLS/lib \
		       --with-sysroot=$LFS \
		       --target=$LFS_TGT   \
		       --disable-nls       \
		       --enable-shared=no  \
		       --disable-werror
	make -j $(nproc)
	make install
}

build_gcc_pass1() {
	BUILD=$LFS_BUILD/${GCC}-pass1
	SRC=$LFS_SRC/${GCC}
	mkdir -p $BUILD
	cd $BUILD

	$SRC/configure \
	    --target=$LFS_TGT         \
	    --prefix=$LFS_TOOLS       \
	    --libdir=$LFS_TOOLS/lib   \
	    --with-sysroot=$LFS       \
	    --with-newlib             \
	    --without-headers         \
	    --enable-initfini-array   \
	    --disable-nls             \
	    --disable-shared          \
	    --disable-multilib        \
	    --disable-decimal-float   \
	    --disable-threads         \
	    --disable-libatomic       \
	    --disable-libgomp         \
	    --disable-libquadmath     \
	    --disable-libssp          \
	    --disable-libvtv          \
	    --disable-libstdcxx       \
	    --enable-default-pie      \
	    --enable-languages=c,c++

	make -j $(nproc)
	make install
}

build_kernel_headers() {
	SRC=$LFS_SRC/${LINUX_KERNEL}
	BUILD=$LFS_BUILD/${LINUX_KERNEL}
	cd $SRC
	make mrproper
	make headers
	mkdir -p $BUILD/include
	cp -rv usr/include $BUILD/
	find $BUILD/include -name '.*' -delete
	rm $BUILD/include/Makefile
	mkdir -p $LFS/usr/include
	cp -rv $BUILD/include/* $LFS/usr/include
}

build_musl() {
	BUILD=$LFS_BUILD/${MUSL}
	SRC=$LFS_SRC/${MUSL}
	mkdir -p $BUILD
	cd $BUILD

	CROSS_COMPILE=$LFS_TOOLS/bin/$LFS_TGT- $SRC/configure    \
			      --prefix=/usr                      \
			      --libdir=/usr/lib			 \
			      --host=$LFS_TGT                    \
			      --disable-shared			 \
			      --with-headers=$LFS/usr/include 
	make -j $(nproc)
	make DESTDIR=$LFS install
}

# FIXME libstdc++ os_defines.h needs a patch to define __GLIBC_PREREQ(x, y) 0
# or it need to detect this as non-gnu system ending in -linux-musl
build_libstdcpp_pass1() {
	BUILD=$LFS_BUILD/${GCC}-libstd++
	SRC=$LFS_SRC/${GCC}/libstdc++-v3
	mkdir -p $BUILD
	cd $BUILD
	export PATH=$LFS_TOOLS/bin:$PATH
	$SRC/configure           \
		--host=$LFS_TGT                 \
		--build=$(${LFS_SRC}/${GCC}/config.guess) \
		--prefix=/usr                   \
		--libdir=/usr/lib		\
		--disable-multilib              \
		--disable-nls                   \
		--disable-libstdcxx-pch         \
		--enable-shared=no		\
		--with-gxx-include-dir=/tools/$LFS_TGT/include/c++/11.2.0
	make -j $(nproc)
	make DESTDIR=$LFS install
}

cross_build() {
	local NAME=$1
	local CONFIGURE_ARGS=$2
	local MAKE_ARGS=$3
	BUILD=${LFS_BUILD}/${NAME}
	SRC=${LFS_SRC}/${NAME}
	mkdir -p $BUILD
	cd $BUILD
	export PATH=$LFS_TOOLS/bin:$PATH
	# --static vs -static is different with regards to some users of
	# libtool where the -static may e ignored
	CFLAGS='--static' LDFLAGS='--static' $SRC/configure --prefix=/usr \
						--host=${LFS_TGT} \
						${CONFIGURE_ARGS}
	make -j1 ${MAKE_ARGS}
	make DESTDIR=${LFS} install
}


build_gcc_pass2() {
	local NAME=$1
	local CONFIGURE_ARGS=$2
	local MAKE_ARGS=$3
	BUILD=${LFS_BUILD}/${NAME}
	SRC=${LFS_SRC}/${NAME}
	mkdir -p $BUILD
	cd $BUILD
	export PATH=$LFS_TOOLS/bin:$PATH
	# --static vs -static is different with regards to some users of
	# libtool where the -static may e ignored
	$SRC/configure --prefix=/usr \
						--host=${LFS_TGT} \
						${CONFIGURE_ARGS}
	make -j1 ${MAKE_ARGS}
	make DESTDIR=${LFS} install
}

#download_sources
#prepare_sources
#build_binutils_pass1
#build_gcc_pass1
#build_kernel_headers
#build_musl
#build_libstdcpp_pass1
#cross_build ${P_M4} "" ""
#cross_build ${P_BASH} "--enable-static-link --without-bash-malloc" ""
#cross_build ${P_COREUTILS} "--enable-sing-binary --enable-install-program=hostname --enable-no-install-program=kill,uptime" ""
#cross_build ${P_DIFFUTILS} "" ""
#cross_build ${P_FILE} "--disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib" "FILE_COMPILE=${LFS_BUILD}/${P_FILE}/src/file"
#cross_build ${P_FINDUTILS} "" ""
#cross_build ${P_GAWK} "" ""
#cross_build ${P_GREP} "" ""
#cross_build ${P_GZIP} "" ""
#cross_build ${P_MAKE} "--without-guile" ""
#cross_build ${P_PATCH} "" ""
#cross_build ${P_SED} "" ""
#cross_build ${P_TAR} "" ""
#cross_build ${P_XZ} "" ""
#cross_build ${P_BINUTILS} "--disable-nls --disable-werror --enable-64-bit-bfd --enable-cet=no" ""

# Mostly the same as pass1 but try to link against static libraries
build_gcc_pass2 ${GCC} "CC_FOR_TARGET=$LFS_TGT-gcc --with-build-sysroot=$LFS --enable-initfini-array --disable-nls --disable-multilib --disable-decimal-float --disable-libatomic --disable-libgomp --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --enable-default-pie --enable-languages=c,c++ --with-static-standard-libraries" ""
