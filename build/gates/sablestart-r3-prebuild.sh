#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$ROOT/src/android/packages/apps/SableStart"
A="$SRC/src/com/sable/start/ui/SableMetroPreviewActivity.kt"
R="$SRC/src/com/sable/start/platform/LiveSurfaceRepository.kt"
M="$SRC/src/com/sable/start/live/LiveSurfaceModels.kt"
MAN="$SRC/AndroidManifest.xml"

echo "===== SABLE METRO R3 REPOSITORY PREBUILD GATE ====="
echo "SOURCE_MUTATION_AUTHORIZED=NO"
echo "APP_BUILD_AUTHORIZED=NO"

python3 - "$MAN" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
print("SABLE_METRO_R3_MANIFEST_XML=PASS")
PY

for f in "$A" "$R" "$M"; do
    if grep -Eq '^(<<<<<<<|=======|>>>>>>>)' "$f"; then
        echo "SABLE_METRO_R3_CONFLICT_MARKERS=FAIL"
        exit 1
    fi
done
echo "SABLE_METRO_R3_CONFLICT_MARKERS=PASS"

for needle in \
  'onSettings = { screen = PreviewScreen.Settings }' \
  'SearchResult("⚙", "Settings", onClick = onSettings)' \
  'onClick = onOpen' \
  'ContextAction("ⓘ", "App info", onClick = onAppInfo)' \
  'launcherAppsRepository.launch(entry)' \
  'Settings.ACTION_APPLICATION_DETAILS_SETTINGS'
do
    grep -Fq "$needle" "$A"
done
echo "SABLE_METRO_R3_REQUIRED_ACTION_BINDINGS=PASS"

for needle in \
  'CalendarContract.Events.CONTENT_URI' \
  'MediaStore.Images.Media.EXTERNAL_CONTENT_URI' \
  'MediaStore.Audio.Media.EXTERNAL_CONTENT_URI' \
  'provider not configured' \
  'suspend fun snapshot' \
  'withContext(Dispatchers.IO)'
do
    grep -Fq "$needle" "$R"
done

for needle in \
  'initialSnapshot()' \
  'LaunchedEffect(refreshGeneration)' \
  'delay(60_000L)' \
  'snapshot.timeText' \
  'snapshot.dateText'
do
    grep -Fq "$needle" "$A"
done
echo "SABLE_METRO_R3_LIVE_DATA_BINDINGS=PASS"
echo "SABLE_METRO_R3_PROVIDER_QUERIES_OFF_MAIN=PASS"

if grep -ERq 'HttpURLConnection|URLConnection|OkHttp|Retrofit|java\.net\.URL' "$SRC/src"; then
    echo "SABLE_METRO_R3_NO_NETWORK_CLIENT=FAIL"
    exit 1
fi
echo "SABLE_METRO_R3_NO_NETWORK_CLIENT=PASS"

if grep -Eq 'contentResolver\.query|resolver\.query' "$A"; then
    echo "SABLE_METRO_R3_UI_PROVIDER_SEPARATION=FAIL"
    exit 1
fi
echo "SABLE_METRO_R3_UI_PROVIDER_SEPARATION=PASS"

echo "SABLE_METRO_R3_REPOSITORY_PREBUILD_GATE=PASS"
