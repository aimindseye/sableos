# Titan 2 N1B pinned-source remote availability probe

Status: **bounded network probe / no sync / no build / no device**

The relocation-aware audit proved that the two exact Phase-08 N1B source
revisions are not present in surviving worktrees or Repo object stores. The
next step is therefore a network-authorized availability probe for exactly
those two objects.

## Scope

```text
device/phh/treble
  project name: device_phh_treble
  remote: https://github.com/TrebleDroid/device_phh_treble
  revision: 70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93
  upstream: android-16.0

prebuilts/vndk/v29
  project name: platform/prebuilts/vndk/v29
  remote: https://android.googlesource.com/platform/prebuilts/vndk/v29
  revision: 16d658458c18835392bd4f2101eb28ba2e7b9e6f
  upstream: bef5d37dda9360940964f097d612c8032e140961
```

The project names, remotes, revisions and upstream locators are parsed from the
surviving Phase-08 pinned manifest whose SHA-256 is:

```text
2ce10689772b122b1cd8810a302735a67826753e819e17ca35a576aaff6c21cc
```

## Safety boundary

```text
REPO_SYNC_AUTHORIZED=NO
ANDROID_SOURCE_MUTATION_AUTHORIZED=NO
ANDROID_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
N1B_EXACT_REBUILD_AUTHORIZED=NO
N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO
N1E_BUILD_AUTHORIZED=NO
```

The network probe creates temporary bare Git repositories only. Each remote is
asked for exactly its pinned commit with a depth-1 fetch. If that exact fetch
fails, the recorded upstream locator is queried only as diagnostic evidence;
an advertised upstream does not convert a missing pinned object into a pass.

## Operator sequence

Offline preflight:

```bash
bash build/gates/n1b-pinned-remote-probe-contract.sh
bash build/titan2/probe-n1b-pinned-source-remotes.sh preflight
```

Then, and only with explicit network authorization:

```bash
bash build/titan2/probe-n1b-pinned-source-remotes.sh \
  probe \
  --authorize-network
```

The probe writes sealed evidence under:

```text
/srv/sable-build/evidence/titan2/n1b-pinned-source-remote-probe/<timestamp>/
```

## Decision

If both exact objects are fetchable:

```text
N1B_PINNED_REMOTE_AVAILABILITY=PASS_ALL_EXACT_OBJECTS_REMOTE_AVAILABLE
N1B_NEXT_STEP=ISOLATED_PINNED_N1B_SOURCE_REMATERIALIZATION_DESIGN
```

This still does not authorize a rebuild. The following phase must construct an
isolated source tree from the exact 992-project Phase-08 manifest and preserve
the historical product/lunch/build identity.

If either object is not fetchable:

```text
N1B_PINNED_REMOTE_AVAILABILITY=REVIEW_REQUIRED_ONE_OR_MORE_EXACT_FETCHES_FAILED
N1B_NEXT_STEP=PROVIDER_SPECIFIC_OBJECT_EXISTENCE_CHECK
```

A failed direct SHA fetch is not, by itself, proof that the object is absent; some servers restrict SHA-in-want. Review the sealed fetch log and perform a provider-specific existence check before retiring exact reconstruction. Do not substitute a branch tip or nearby compatibility control.

Even after source re-materialization, the only acceptable exact reconstruction
is one that reproduces both historical artifact identities:

```text
system.img SHA256 =
bc550bfaf8463324c122abb490cf4aba956b89e7e4d42168a55f0f0f0f5b638e

target-files SHA256 =
29d21d08ceb9c286e85ec52996dcc53a17fd0290cc979b5853709ef7357f2481
```
