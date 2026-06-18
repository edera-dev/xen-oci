#!/usr/bin/env python3
"""Generate a curated CycloneDX SBOM for a published xen-oci image.

Reads from the environment (set by the SBOM workflow step):
  COMPONENT            xen | oxenstored | qemu-xen
  XEN_VERSION          e.g. "4.21"
  XEN_COMMIT           resolved commit of edera-dev/xen.git
  QEMU_COMMIT          resolved commit of edera-dev/qemu.git    (qemu-xen only)
  LIBUCONTEXT_COMMIT   resolved commit of libucontext           (qemu-xen only)
  LIBUCONTEXT_VERSION  e.g. "1.5"                               (qemu-xen only)
  PKG_SBOM             path to a syft CycloneDX scan of the final image; its
                       .components are merged in (may be empty or absent)

Writes <COMPONENT>.cdx.json (CycloneDX 1.6) in the current directory.
"""
import json
import os
import sys


def applied_patches(version, patch_component):
    """Patch files applied for (version, patch_component), in series order.

    Mirrors apply-patches.sh: patches/<version>/<component>/series lists one
    patch filename per line; an absent series file means no patches.
    """
    series = os.path.join("patches", version, patch_component, "series")
    if not os.path.isfile(series):
        return []
    patches = []
    with open(series) as handle:
        for line in handle:
            name = line.strip()
            if name:
                patches.append("patches/%s/%s/%s" % (version, patch_component, name))
    return patches


def source_component(name, gh_path, commit, version, refs, patches, ctype="application"):
    """A git-sourced component, pinned to commit when known."""
    purl = "pkg:github/%s" % gh_path
    if commit:
        purl = "%s@%s" % (purl, commit)
    component = {
        "bom-ref": purl,
        "type": ctype,
        "name": name,
        "purl": purl,
    }
    if version:
        component["version"] = version
    if refs:
        component["externalReferences"] = refs
    if patches:
        component["pedigree"] = {
            "patches": [
                {"type": "unofficial", "diff": {"url": patch}} for patch in patches
            ]
        }
    return component


def xen_source(version, commit, patch_component):
    """The edera-dev/xen.git source. patch_component selects which series file
    (if any) patched the xen tree for this image; None means no xen patches.

    The branch varies by release (edera/<ver> from 4.21, RELEASE-<ver> before),
    so it is read from XEN_BRANCH; the commit pins the source precisely either
    way, the branch is just human context in the distribution URL.
    """
    branch = os.environ.get("XEN_BRANCH") or ("edera/%s" % version)
    patches = applied_patches(version, patch_component) if patch_component else []
    return source_component(
        name="xen",
        gh_path="edera-dev/xen",
        commit=commit,
        version=version,
        refs=[
            {"type": "vcs", "url": "https://github.com/edera-dev/xen.git"},
            {
                "type": "distribution",
                "url": "https://github.com/edera-dev/xen/tree/%s" % branch,
            },
        ],
        patches=patches,
    )


def build_sources(component, version):
    if component == "xen":
        # Hypervisor only; no patches applied in Dockerfile.xen.
        return [xen_source(version, os.environ.get("XEN_COMMIT", ""), None)]

    if component == "oxenstored":
        # Built from the xen tree; its patches (if any) patch xen.
        return [xen_source(version, os.environ.get("XEN_COMMIT", ""), "oxenstored")]

    if component == "qemu-xen":
        qemu = source_component(
            name="qemu-xen",
            gh_path="edera-dev/qemu",
            commit=os.environ.get("QEMU_COMMIT", ""),
            version=version,
            refs=[
                {"type": "vcs", "url": "https://github.com/edera-dev/qemu.git"},
                {"type": "distribution", "url": "https://github.com/edera-dev/qemu/tree/edera"},
            ],
            # apply-patches.sh runs in the qemu tree, so qemu patches live here.
            patches=applied_patches(version, "qemu"),
        )
        # xen libs are statically linked into qemu; no xen patches for this build.
        xen = xen_source(version, os.environ.get("XEN_COMMIT", ""), None)
        libucontext = source_component(
            name="libucontext",
            gh_path="kaniini/libucontext",
            commit=os.environ.get("LIBUCONTEXT_COMMIT", ""),
            version=os.environ.get("LIBUCONTEXT_VERSION", ""),
            refs=[{"type": "vcs", "url": "https://github.com/kaniini/libucontext.git"}],
            patches=[],
            ctype="library",
        )
        return [qemu, xen, libucontext]

    print("ERROR: unknown COMPONENT %r" % component, file=sys.stderr)
    sys.exit(1)


def scanned_packages():
    """The .components from a syft CycloneDX scan of the final image, if any.

    For xen/oxenstored (FROM scratch, no apk db) this is empty; for qemu-xen it
    is the runtime libraries shipped in /opt/edera/qemu-xen/sysroot.
    """
    path = os.environ.get("PKG_SBOM", "")
    if not path or not os.path.isfile(path):
        return []
    with open(path) as handle:
        try:
            doc = json.load(handle)
        except json.JSONDecodeError:
            return []
    return doc.get("components") or []


def main():
    component = os.environ["COMPONENT"]
    version = os.environ["XEN_VERSION"]

    sources = build_sources(component, version)
    packages = scanned_packages()
    components = sources + packages

    image_ref = "%s@%s" % (component, version)
    depends_on = [c["bom-ref"] for c in components if c.get("bom-ref")]
    document = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {
            "component": {
                "bom-ref": image_ref,
                "type": "container",
                "name": component,
                "version": version,
            },
        },
        "components": components,
        "dependencies": [{"ref": image_ref, "dependsOn": depends_on}],
    }

    with open("%s.cdx.json" % component, "w") as out:
        json.dump(document, out, indent=2)
        out.write("\n")

    print(
        json.dumps(
            {
                "component": component,
                "version": version,
                "sources": len(sources),
                "packages": len(packages),
                "components": len(components),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
