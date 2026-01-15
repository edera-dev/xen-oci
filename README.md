# xen-oci

This repo consists mostly of OCI image spec files that are used to build Edera's fork of Xen: https://github.com/edera-dev/xen

All the Xen components come from that fork tree, and we build, package and publish them using Github Actions as 3 distinct OCI artifacts:

- `xen` -> contains the core `xen` boot binaries
- `oxenstored` -> contains the OCAML xenstore impl we ship
- `qemu-xen` -> contains extra qemu/xen related bits and bobs

Inspect the corresponding Dockerfile spec files for build options, build dependencies, and other details.
