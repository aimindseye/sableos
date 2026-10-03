# Titan 2 N1B provider-specific source-object existence

Status: **bounded provider verification / no sync / no build / no device**

The generic exact-SHA fetch probe completed with both projects in
`EXACT_FETCH_FAILED_REVIEW_REQUIRED`. That result does not prove absence:
providers may reject arbitrary SHA-in-want even when the object exists.

This phase therefore asks each provider through its native read-only API.

## Bound input evidence

The probe requires the sealed bounded-probe evidence directory and verifies its
`SHA256SUMS.txt`, `results.tsv` and `decision.env`.

Expected prior state:

```text
N1B_PINNED_REMOTE_AVAILABILITY=REVIEW_REQUIRED_ONE_OR_MORE_EXACT_FETCHES_FAILED
N1B_NEXT_STEP=PROVIDER_SPECIFIC_OBJECT_EXISTENCE_CHECK
```

Both project rows must still be exactly:

```text
device/phh/treble
  70ecdf29d78928c84f556f7a4dc80a6d8f8c1e93
  EXACT_FETCH_FAILED_REVIEW_REQUIRED

prebuilts/vndk/v29
  16d658458c18835392bd4f2101eb28ba2e7b9e6f
  EXACT_FETCH_FAILED_REVIEW_REQUIRED
```

## Provider checks

TrebleDroid is checked through GitHub's commit API against both:

```text
TrebleDroid/device_phh_treble
phhusson/device_phh_treble
```

A GitHub HTTP 200 is accepted only when the returned commit SHA equals the
pinned revision. HTTP 404/422 is recorded as provider-confirmed absence for that
repository. Other HTTP/curl failures remain review-required.

AOSP VNDK v29 is checked through Gitiles using the exact commit URL:

```text
https://android.googlesource.com/platform/prebuilts/vndk/v29/+/<sha>?format=JSON
```

HTTP 200 confirms the exact commit object is addressable. HTTP 404 confirms
absence. Other results remain review-required.

## Safety boundary

```text
REPO_SYNC_AUTHORIZED=NO
GIT_CLONE_AUTHORIZED=NO
GIT_CHECKOUT_AUTHORIZED=NO
ANDROID_SOURCE_MUTATION_AUTHORIZED=NO
ANDROID_BUILD_AUTHORIZED=NO
DEVICE_CONTACT_AUTHORIZED=NO
FLASH_AUTHORIZED=NO
N1B_EXACT_REBUILD_AUTHORIZED=NO
N1B_V010014_PHYSICAL_CONTROL_AUTHORIZED=NO
N1E_BUILD_AUTHORIZED=NO
```

The network-enabled mode writes only evidence files under the canonical evidence
root.

## Decision model

If both exact objects are provider-verified:

```text
N1B_PROVIDER_OBJECT_EXISTENCE=PASS_ALL_EXACT_OBJECTS_PROVIDER_VERIFIED
N1B_NEXT_STEP=ISOLATED_PINNED_N1B_SOURCE_REMATERIALIZATION_DESIGN
```

If TrebleDroid/PHH no longer addresses the exact Treble revision while AOSP
still addresses the exact VNDK revision:

```text
N1B_PROVIDER_OBJECT_EXISTENCE=BLOCKED_TREBLE_EXACT_OBJECT_NOT_ADDRESSABLE
N1B_NEXT_STEP=AUTHENTIC_TREBLE_SOURCE_ARCHIVE_OR_REFERENCE_RECOVERY
```

That does not authorize substituting the current `android-16.0` branch tip.
Exact N1B reconstruction remains blocked unless an authentic archive or another
verifiable source of the same Git object is found.

If either provider response is inconclusive:

```text
N1B_PROVIDER_OBJECT_EXISTENCE=REVIEW_REQUIRED_PROVIDER_CHECK_INCONCLUSIVE
N1B_NEXT_STEP=REVIEW_PROVIDER_HTTP_EVIDENCE
```

## Operator command

```bash
BOUND=/srv/sable-build/evidence/titan2/n1b-pinned-source-remote-probe/20261003T191156Z

bash build/gates/n1b-provider-object-existence-contract.sh

bash build/titan2/probe-n1b-provider-specific-object-existence.sh \
  preflight \
  --bounded-probe-evidence-dir "$BOUND"

bash build/titan2/probe-n1b-provider-specific-object-existence.sh \
  probe \
  --bounded-probe-evidence-dir "$BOUND" \
  --authorize-network
```
