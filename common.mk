export NPROC ?= $(shell nproc)
export ARCH := $(subst x86_64,i386,$(shell arch))

export XEN_VERSION ?= 4.21
XEN_URL ?= https://github.com/edera-dev/xen.git
XEN_BRANCH ?= edera/$(XEN_VERSION)

export XEN_SRC := $(abspath xen)

$(XEN_SRC):
	git clone -b $(XEN_BRANCH) $(XEN_URL) $@

.PHONY: install-deps
install-deps:
	sudo apt install -y patchelf git flex bison perl coreutils \
		meson acpica-tools libncurses-dev ocamlbuild ocaml-doc \
		libyajl-dev openssl libspice-protocol-dev libspice-server-dev \
		xz-utils libzstd-dev zlib1g-dev liblz-dev e2fsprogs \
		ninja-build libcurl4-openssl-dev liblzo2-dev libbz2-dev libzstd-dev \
