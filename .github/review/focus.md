# Review focus

What the advisory review checks look for in this repository. The shared
workflow in `edera-dev/actions` supplies the review method; this file supplies
everything specific to this repository, and `test-layers.md` beside it says
where checks live and what runs on a pull request.

Each section starts at its `<!-- focus: NAME -->` line and runs to the next
one. The templates under `advisory-review/templates/` in `edera-dev/actions`
fix the names and show where each section lands. `FORK_SCOPE` is optional;
every other section is required, and a name no template uses fails the run.

<!-- focus: INTRO -->
This repository compiles Xen from a source branch and publishes the result as an OCI image that other projects pin. There is no application code here: the inputs are a Dockerfile, two hypervisor config files, and the workflows that decide what gets built and tagged. A defect usually does not fail a build. It produces a hypervisor image that is missing an option, was built from something other than what the tag claims, or differs between the two architectures.

<!-- focus: SERIOUS -->
## 1. Serious defects

Read the whole file, not just the hunk. Almost everything that goes wrong here goes wrong quietly: the build succeeds and the image is not what it should be.

**A hypervisor config change.** `configs/xen-amd64.config` and `configs/xen-arm64.config` decide what the built hypervisor can do. Check whether a change belongs in both, and say what the option does rather than restating its name. Debug and verbose options in a release build, and security-relevant options turned off, are the two cases worth being most careful about. An option that no longer exists on the Xen branch being built, or one whose dependencies are not met, is dropped silently by `olddefconfig`. The Dockerfile already asserts two symbols survived that step on amd64; a new option that matters the same way should join them.

**The two architectures drifting apart.** The build produces an `amd64` and an `arm64` image from separate configs, and the arm64 leg runs under emulation. A change made to one config and not the other ships two images that behave differently under the same tag scheme. Say which architecture gets what.

**A build that stops matching its tag.** The Dockerfile takes `XEN_REPO`, `XEN_BRANCH` and `XEN_VERSION` as build arguments and tracks a branch tip by default. Any change to which ref is built, or to how a tag is chosen, changes what an existing tag means for everything already pulling it. Say which tag changes and what it pointed at before.

**Compile-cache correctness.** The build uses a shared sccache backend, and the Dockerfile documents in detail why it uses a specific fork and a per-architecture server port: on the default port the two platform legs share one daemon and can be served each other's objects, and the upstream `.incbin`/`.include` handling can serve a stale object for a translation unit whose preprocessor output did not change. A change to the wrapper scripts, the port assignment, the key prefix, or the sccache version can reintroduce either problem, and the symptom is a hypervisor built partly from cached objects that do not correspond to the source. Treat any edit in that area as high scrutiny and say what would be served wrongly.

**A download without integrity checking.** The sccache binary is the one thing this build downloads, and it is fetched with a per-architecture SHA-256 that `sha256sum -c` actually compares. A download added without a checksum, or with a checksum that is fetched from the same place as the artifact, puts an unverified binary into the build.

**A build stage that fails without failing the build.** A `RUN` whose real command is not last in a pipeline, a `|| true`, a missing `set -e` in a multi-command shell step, or a `case` with no failing default. The Dockerfile's arch dispatch already fails closed on an unsupported `TARGETARCH`; a new branch that does not is the shape to look for. Say what ends up missing from the image.

**Workflow permissions and untrusted input.** A job that holds `packages: write` or `id-token: write` and does not need it. `${{ }}` interpolated into a `run:` block where the value came from a dispatch input — `branch.yml` takes a free-text ref. Any use of `pull_request_target`. Note that secrets are unavailable to fork pull requests by design here, and the sccache action is expected to fall back to a local cache; a change that makes the build fail instead of degrade breaks outside contributions.

**Provenance.** `generate-sbom.py` is what ties a published image to what went into it. A change that lets an image publish with an SBOM describing a different build, or with no SBOM, removes that link.

<!-- focus: SUPPLY -->
## 2. Supply chain

Real, but rarely "the published hypervisor is wrong" serious — label these **Supply chain** so severity reads honestly.

A base image taken by tag rather than digest, an action moved off a pinned SHA, a downloaded tool without a checksum, a build argument default changed to a floating ref.

The buildkit driver image in `test.yml` is pinned by digest with a note that dependabot does not track `driver-opts` images, so it is bumped by hand. A change there is worth reading carefully because the rootless configuration it enables is deliberate, and the comment explains what went wrong when the build was not sandboxed that way.

**On a version bump, check the call sites still match the new interface.** The pin moves, the caller keeps passing an input the new version dropped, Actions warns instead of failing, and CI stays green while the step is dead.

<!-- focus: SKIPPED_TEST_FORMS -->
A platform removed from the PR build, a step made `continue-on-error`, a `|| true` appended, or a path added to a workflow's filters so it stops running.

<!-- focus: SUPPRESSION_FORMS -->
A `check=skip=` directive in the Dockerfile, an error swallowed (`|| true`, `2>/dev/null`), or a checksum comparison removed.

<!-- focus: RIGHT_LEVEL -->
A change to how a build argument is handled can be checked by the PR build. A change to what the hypervisor does at runtime cannot be checked here at all.

<!-- focus: NO_TEST_LAYER -->
That is often the honest answer: this repository builds a hypervisor and never boots it. Nothing here can tell you a config option produces the behaviour it is supposed to. Say so rather than asking for a test that would need a machine.

<!-- focus: OUT_OF_SCOPE -->
Style, naming, formatting, and comment wording. Do not restate what a build step does.

<!-- focus: CALIBRATION_COST -->
a hypervisor image built with the wrong options, or a tag that starts pointing at a different build, costs a lot more.

<!-- focus: CANNOT_CHECK_EXAMPLE -->
I could not run the aarch64 leg locally, so I am reading the arch branch in the Dockerfile rather than its output

<!-- focus: IMPLICATION_EXAMPLE -->
"the option is set in `configs/xen-amd64.config` and not in `configs/xen-arm64.config`, so the two published images differ in what the hypervisor supports and nothing reports the difference" does.

<!-- focus: SERIOUS_DEFINITION -->
a published image that is wrong or incomplete, an architecture that silently diverges from the other, a tag that changes meaning for anything already pinned to it, a compile cache that can serve the wrong object, an unverified download entering the build, or a lost link between a tag and its contents

<!-- focus: SAY_WHAT_HAPPENS -->
the option is not set in the built hypervisor; the arm64 image is missing what the amd64 image has; the tag now points at a different branch; the cache can serve the wrong architecture's object; the image publishes with no SBOM

<!-- focus: WRITE_BAD -->
The `SCCACHE_PORT` assignment in the arch `case` sets 4226 for amd64 and 4326 for arm64, and this change collapses the two branches into a single default, which means both legs of the multi-platform build...

<!-- focus: WRITE_GOOD -->
Both platform legs share one sccache daemon again, so a compile in the arm64 leg can be served an object cached by the amd64 leg and the published arm64 hypervisor contains amd64 code. The arch `case` in `Dockerfile.xen` no longer assigns a distinct `SCCACHE_SERVER_PORT` per architecture. Keeping the per-arch port is the fix; the comment above that block explains why it is there.

<!-- focus: CLEAN_EXAMPLE -->
A digest bump for the base image with no build arguments changed. Nothing concerning.

<!-- focus: OUTPUT_EXAMPLE -->
One problem I think should be fixed before merge: the two platform legs share a cache daemon again.

**Serious: the per-architecture sccache port is gone, so a leg can be served the other architecture's objects.**

The published arm64 image can end up containing objects compiled for amd64, which builds and pushes cleanly. The arch `case` in `Dockerfile.xen` now assigns one port for both legs, and sccache is client/server over loopback, so on a shared port the two legs address the same daemon.

Restoring the distinct port per architecture is the fix. The comment directly above that block records why it was split.

**The arm64 config does not get the new option.**

`configs/xen-amd64.config` gains the option and `configs/xen-arm64.config` does not, so the two images under the same tag scheme support different things and nothing compares them. If the divergence is deliberate, a comment in both files saying so would keep the next change from re-syncing them by accident.

<!-- focus: UNKNOWN_EXAMPLE -->
The new build argument is referenced in one stage and declared in another, so it resolves to empty in the stage that uses it. I could not work out from the Dockerfile alone whether an empty value changes the result of that step. No change requested.

<!-- focus: IMPACT_WORKED_EXAMPLE -->
Both platform legs share one compile-cache daemon, so a translation unit in the arm64 leg can be served an object cached by the amd64 leg. The build succeeds and the published arm64 image contains code compiled for the other architecture, with nothing in the build reporting a mismatch.

<!-- focus: HOW_WRONG -->
- What input would make the new code do the wrong thing? Where does it come from: a build argument, a hypervisor config file, a dispatch input, an environment variable set by the sccache action?
- Does the change behave differently on `amd64` and `arm64`? The two legs use different configs and the arm64 one runs emulated, so a change that looks uniform often is not.
- What happens on the failure path: the sccache download that 404s, the checksum that does not match, the unsupported `TARGETARCH`, the cache that is unavailable because a fork PR has no secrets?
- If this is a bug fix, what exactly was the bug, and what would have failed before the fix?
- If the change affects what gets published — a tag, an SBOM, a build argument default — what is already pinned to the thing it changes?
- Would the PR build actually execute the changed path, or only the path it replaced?

<!-- focus: WHERE_TO_LOOK -->
- `.github/workflows/test.yml`, which is the only behavioural check on a pull request: it builds both platforms, including the emulated aarch64 leg, and publishes nothing. If the change is inside what that build compiles, it is exercised;
- the Dockerfile's own guards — the arch `case` fails closed on an unknown `TARGETARCH`, the sccache download compares a checksum, and a step after `make olddefconfig` asserts two required config symbols survived. These are frequently the only check a change has, and the config assertion is the one a kconfig change should be measured against;
- the sccache stats printed in the build log, which are the evidence for cache-related changes.

There are no unit tests in this repository. Do not look for a test file.

<!-- focus: PROPORTIONATE -->
Asking for a unit test framework this repository does not have is not a finding. Asking for a guard inside the build step that already owns the input is.

<!-- focus: CONDITIONAL_EXAMPLE -->
"A build whose arm64 leg hits the shared daemon first can be served an amd64 object, and the resulting image publishes without anything comparing the two" names the condition and the result. "This could cause cache issues" names neither.

<!-- focus: TWO_SHAPES -->
- **The build cannot observe it.** This repository compiles a hypervisor and never runs one. A config option that is accepted but does nothing, or an option that changes runtime behaviour, passes the build either way. When that is the situation, say so and name what would have to boot to catch it, rather than proposing a check here.
- **Only one architecture is exercised by the change.** Both legs build on a pull request, but a change confined to one config file or one arch branch is only meaningfully exercised on that side. Check which config the change touches before treating the two-platform build as coverage.

<!-- focus: SMALLEST_LAYER -->
Pick the smallest thing that would catch the failure. A guard inside the build step that already owns the input — the arch `case`, the sccache checksum, and the post-`olddefconfig` assertion on required config symbols are the existing examples. For a kconfig change the last one is almost always the answer: one more `grep -qx` beside the two that are there. A parallel change to the other architecture's config, where the divergence was not intended. The PR build, where the change is inside what it compiles. Do not propose a harness that boots a hypervisor.

<!-- focus: COVER_BAD -->
The PR build covers this. It builds both the amd64 and the emulated arm64 leg with the changed configuration, runs the full compile through sccache, and the build-push action reports success for both platforms without publishing...

<!-- focus: COVER_GOOD -->
Both platform legs build the changed configuration on the pull request, so a config the hypervisor cannot compile with would fail here.

<!-- focus: CLEAN_NOTHING -->
Nothing here needs a check. It's a comment fix in the Dockerfile.

<!-- focus: GAP_EXAMPLE -->
One gap. I'd close it with this PR, since it is a guard in the step that already owns the value.

**An unsupported value for the new build argument produces an image rather than an error.**

The stage falls through to its default path and publishes a hypervisor built without the feature the argument was supposed to select, under the tag that claims it. The `case` this change adds has no failing default, unlike the `TARGETARCH` dispatch above it.

Adding `*) echo "unsupported ..." >&2; exit 1 ;;` to that `case` is the assertion — it makes the build fail where the value is read rather than publishing something wrong.
