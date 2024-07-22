TERMUX_PKG_HOMEPAGE=https://www.qemu.org
TERMUX_PKG_DESCRIPTION="A generic and open source machine emulator and virtualizer (headless)"
TERMUX_PKG_LICENSE="GPL-2.0"
TERMUX_PKG_MAINTAINER="@termux"
TERMUX_PKG_VERSION=1:2.9.1
TERMUX_PKG_REVISION=2
TERMUX_PKG_SRCURL=https://download.qemu.org/qemu-${TERMUX_PKG_VERSION:2}.tar.xz
TERMUX_PKG_SHA256=4350b3d1d75f1e6a562d975687e181f61ceaf3ac94e6b629f87e24cbe680d03d
TERMUX_PKG_DEPENDS="dtc, glib, libbz2, libcurl, libgmp, libgnutls, libiconv, libjpeg-turbo, liblzo, libnettle, libnfs, libpixman, libpng, libspice-server, libssh, libusb, libusbredir, ncurses, pulseaudio, qemu-common, resolv-conf, zlib, zstd, libcap"

# Required by configuration script, but I can't find any binary that uses it.
TERMUX_PKG_BUILD_DEPENDS="libtasn1, zlib, liblzo"

TERMUX_PKG_CONFLICTS="qemu-system-x86_64-headless"
TERMUX_PKG_REPLACES="qemu-system-x86_64-headless"
TERMUX_PKG_PROVIDES="qemu-system-x86_64-headless"
TERMUX_PKG_BUILD_IN_SRC=true
# TERMUX_PKG_EXTRA_MAKE_ARGS="CFLAGS=\"-Wimplicit-function-declaration -Wimplicit-const-int-float-conversion -Wdeprecated-declarations -std=gnu99\" CXXFLAGS=\"-std=gnu++0x\""

set -x

termux_step_pre_configure() {
	# Workaround for https://github.com/termux/termux-packages/issues/12261.
	if [ $TERMUX_ARCH = "aarch64" ]; then
		rm -f $TERMUX_PKG_BUILDDIR/_lib
		mkdir -p $TERMUX_PKG_BUILDDIR/_lib

		cd $TERMUX_PKG_BUILDDIR
		mkdir -p _setjmp-aarch64
		pushd _setjmp-aarch64
		mkdir -p private
		local s
		for s in $TERMUX_PKG_BUILDER_DIR/setjmp-aarch64/{setjmp.S,private-*.h}; do
			local f=$(basename ${s})
			cp ${s} ./${f/-//}
		done
		$CC $CFLAGS $CPPFLAGS -I. setjmp.S -c
		$AR cru $TERMUX_PKG_BUILDDIR/_lib/libandroid-setjmp.a setjmp.o
		popd

		LDFLAGS+=" -L$TERMUX_PKG_BUILDDIR/_lib -l:libandroid-setjmp.a"
	fi
}

termux_step_configure() {
	termux_setup_ninja

	if [ "$TERMUX_ARCH" = "i686" ]; then
		LDFLAGS+=" -latomic"
	fi

	local QEMU_TARGETS=""

	# System emulation.
	QEMU_TARGETS+="aarch64-softmmu,"
	QEMU_TARGETS+="x86_64-softmmu,"

	CFLAGS+=" $CPPFLAGS -I/data/data/com.termux/files/usr/include -std=gnu99"
	CXXFLAGS+=" $CPPFLAGS -I/data/data/com.termux/files/usr/include -std=gnu++0x"
	LDFLAGS+=" -landroid-shmem -llog -I/data/data/com.termux/files/usr/include"

	# Note: using --disable-stack-protector since stack protector
	# flags already passed by build scripts but we do not want to
	# override them with what QEMU configure provides.
	./configure \
		--prefix="$TERMUX_PREFIX" \
		--cross-prefix="${TERMUX_HOST_PLATFORM}-" \
		--host-cc="gcc" \
		--cc="$CC" \
		--cxx="$CXX" \
		--objcc="$CC" \
		--disable-stack-protector \
		--smbd="$TERMUX_PREFIX/bin/smbd" \
		--enable-coroutine-pool \
		--audio-drv-list=pa \
		--enable-trace-backends=nop \
		--disable-guest-agent \
		--enable-gnutls \
		--enable-nettle \
		--disable-sdl \
		--disable-gtk \
		--disable-vte \
		--enable-curses \
		--enable-vnc \
		--disable-vnc-sasl \
		--enable-vnc-jpeg \
		--disable-xen \
		--disable-xen-pci-passthrough \
		--enable-virtfs \
		--enable-curl \
		--enable-kvm \
		--enable-libnfs \
		--enable-lzo \
		--disable-snappy \
		--enable-bzip2 \
		--disable-seccomp \
		--enable-spice \
		--enable-libusb \
		--enable-usb-redir \
		--target-list="$QEMU_TARGETS" \
		--python=/usr/bin/python2
}

termux_step_post_make_install() {
	local i
	for i in aarch64 x86_64; do
		ln -sfr \
			"${TERMUX_PREFIX}"/share/man/man1/qemu.1 \
			"${TERMUX_PREFIX}"/share/man/man1/qemu-system-${i}.1
	done
}
