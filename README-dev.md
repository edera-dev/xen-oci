# Dev build of Xen

Currently a DRAFT.

You can build Xen, oxenstored, and qemu from the provided Makefiles, rather
than relying on OCI images.

## Dependencies

Debian-based, they are:

```
	sudo apt install -y patchelf git flex bison perl coreutils \
		meson acpica-tools libncurses-dev ocamlbuild ocaml-doc \
		libyajl-dev openssl libspice-protocol-dev libspice-server-dev \
		xz-utils libzstd-dev zlib1g-dev liblz-dev e2fsprogs \
		ninja-build libcurl4-openssl-dev liblzo2-dev libbz2-dev libzstd-dev
```


## How to run

During release, we build each component in a different way, thus a clean
is needed between each (e.g., `CFLAGS` and `configure` flags vary).

```
for mf in oxenstored qemu-xen xen; do
    make -f Makefile.$mf
    make -f Makefile.$mf install
    make -f Makefile.$mf distclean
done
```

If you already have a repository checked out, then the Makfiles will continue
building.
