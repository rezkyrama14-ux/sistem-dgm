#!/usr/bin/env bash
# Membangun APK Android dari index.html + folder android/.
# Butuh paket Ubuntu: aapt apksigner zipalign android-sdk-platform-23 dalvik-exchange (+ JDK).
# Variabel opsional:
#   KEYSTORE_FILE (default: release.keystore), KEYSTORE_PASSWORD, KEY_ALIAS (default: pusatkendali)
#   VERSION_CODE (angka, default 1), VERSION_NAME (default 1.0)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SDK_JAR="${ANDROID_JAR:-/usr/lib/android-sdk/platforms/android-23/android.jar}"
OUT="$ROOT/build"
VERSION_CODE="${VERSION_CODE:-1}"
VERSION_NAME="${VERSION_NAME:-1.0}"
VERSION_NAME="${VERSION_NAME#v}"
KEYSTORE_FILE="${KEYSTORE_FILE:-$ROOT/release.keystore}"
KEY_ALIAS="${KEY_ALIAS:-pusatkendali}"

rm -rf "$OUT" && mkdir -p "$OUT/gen" "$OUT/obj" "$OUT/assets"
cp index.html "$OUT/assets/index.html"
sed -e "s/android:versionCode=\"[0-9]*\"/android:versionCode=\"$VERSION_CODE\"/" \
    -e "s/android:versionName=\"[^\"]*\"/android:versionName=\"$VERSION_NAME\"/" \
    android/AndroidManifest.xml > "$OUT/AndroidManifest.xml"

echo "== Kompilasi resource"
aapt package -f -m -J "$OUT/gen" -M "$OUT/AndroidManifest.xml" -S android/res -I "$SDK_JAR"
echo "== Kompilasi Java"
javac -source 8 -target 8 -nowarn -encoding UTF-8 -Xlint:-options -bootclasspath "$SDK_JAR" -classpath "$SDK_JAR" -d "$OUT/obj" \
  $(find android/src -name '*.java') $(find "$OUT/gen" -name '*.java')
echo "== Konversi ke DEX"
dalvik-exchange --dex --output="$OUT/classes.dex" "$OUT/obj"
echo "== Paket APK"
aapt package -f -M "$OUT/AndroidManifest.xml" -S android/res -A "$OUT/assets" -I "$SDK_JAR" -F "$OUT/app.unsigned.apk"
(cd "$OUT" && aapt add app.unsigned.apk classes.dex >/dev/null)
zipalign -f -p 4 "$OUT/app.unsigned.apk" "$OUT/app.aligned.apk"

if [ ! -f "$KEYSTORE_FILE" ] || [ -z "${KEYSTORE_PASSWORD:-}" ]; then
  echo "!! Keystore rilis tidak ada: memakai keystore sementara."
  echo "!! APK ini TIDAK bisa meng-update aplikasi yang sudah terpasang. Lihat README bagian 'Keystore'."
  KEYSTORE_FILE="$OUT/temp.keystore"; KEYSTORE_PASSWORD="temporary-$RANDOM$RANDOM"; KEY_ALIAS="temp"
  keytool -genkeypair -keystore "$KEYSTORE_FILE" -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 3650 \
    -storepass "$KEYSTORE_PASSWORD" -keypass "$KEYSTORE_PASSWORD" -dname "CN=Pusat Kendali (sementara)" >/dev/null 2>&1
fi
echo "== Tanda tangan APK"
apksigner sign --ks "$KEYSTORE_FILE" --ks-key-alias "$KEY_ALIAS" --ks-pass "pass:$KEYSTORE_PASSWORD" --key-pass "pass:$KEYSTORE_PASSWORD" \
  --out "$OUT/PusatKendaliMarketing.apk" "$OUT/app.aligned.apk"
apksigner verify "$OUT/PusatKendaliMarketing.apk"
echo "== Selesai: build/PusatKendaliMarketing.apk (versi $VERSION_NAME, kode $VERSION_CODE)"
