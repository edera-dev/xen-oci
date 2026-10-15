# What checks this repo has, and what runs on a PR

There are no unit tests. Nothing here imports a script and asserts on it, and
nothing boots what it builds. The check on a pull request is a build, plus the
guards the build steps apply to their own inputs.

## The PR build

`.github/workflows/test.yml` runs on every pull request and on pushes to
`main`. It builds exactly what the nightly builds — both platforms, including
the QEMU-emulated `aarch64` half — and publishes nothing; the result stays in
the ephemeral buildkit cache. The check is that it builds.

Two details matter when deciding whether a change is covered:

- The sccache credentials differ by trust level: read-write on `main`,
  read-only for pull requests, and local-only for fork pull requests, which
  receive no secrets. A change that makes the build require the cache rather
  than benefit from it breaks fork contributions, and the PR build from a
  branch in this repository will not show that.
- The buildkit driver is pinned by digest and runs rootless with
  `--oci-worker-no-process-sandbox`. The comment in the workflow explains what
  that isolation is for; a change to it is a change to the build's own
  integrity, not a tuning knob.

## In-Dockerfile guards

Several steps validate their own inputs and are frequently the only check a
change has:

- the `TARGETARCH` `case` fails closed on an unsupported value;
- the sccache download compares a per-architecture SHA-256 with `sha256sum -c`;
- after `make olddefconfig`, a step greps the generated `xen/.config` for
  `CONFIG_MEM_SHARING=y` and `CONFIG_KVM_GUEST=y` and exits 1 with an
  explanation if either was dropped. It runs on amd64 only and covers those two
  symbols and no others.

That third guard is the pattern to point at for a config change: it is how this
repository already catches a symbol `olddefconfig` silently drops, and
extending it costs one `grep -qx` line. Everything else the build consumes
comes from a git fetch of the Xen sources, with no checksum of its own.

When proposing where a check should go, this is usually the right answer: the
step that already owns the input is the cheapest place to assert something
about it.

## What nothing here checks

- Whether a hypervisor config option does what it is supposed to do at
  runtime. Nothing in this repository boots anything.
- Whether the two architectures ended up equivalent. Both are built; neither is
  compared against the other.
- Whether the published tag means what a consumer expects. Tag selection is in
  the publishing workflows, which do not run on a pull request.

## The review checks themselves

`.github/workflows/pr-review.yml` runs the two advisory review checks,
including this one, through the shared workflow in `edera-dev/actions`. They
build, lint and test nothing this repository ships. Never count them as
coverage for a change.

## Everything else

`nightly.yml`, `release.yaml` and `branch.yml` are `schedule` or
`workflow_dispatch` and will not run on the pull request under review. A change
to their tagging or publishing logic is not exercised by anything on the PR;
say that plainly rather than treating the PR build as coverage for it.
