#!/bin/bash
# Релизная сборка RedQuit для раздачи людям:
#   • универсальная (Apple Silicon + Intel);
#   • подпись ad-hoc — в подписи нет ничего личного (сертификат разработчика не используется);
#   • DMG с ярлыком «Программы»: dist/RedQuit-<версия>.dmg
#
#   ./Scripts/release.sh
#
# Важно для пользователей: при ad-hoc подписи macOS считает каждую новую версию новой
# программой, поэтому после обновления разрешение «Универсальный доступ» нужно включить
# заново (это описано в README и в окне разрешения).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="RedQuit"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
STAGE="build/release"
APP="$STAGE/$APP_NAME.app"
DMG_ROOT="$STAGE/dmg"
DIST="dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"

echo "==> RedQuit $VERSION: тесты"
swift test 2>&1 | tail -n 1

echo "==> Компиляция (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"
lipo -info "$BIN"

echo "==> Сборка $APP"
rm -rf "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DMG_ROOT" "$DIST"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/Localization/*.lproj "$APP/Contents/Resources/"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"

echo "==> Подпись (ad-hoc)"
codesign --force --options runtime --timestamp=none --sign - "$APP"
codesign --verify --strict --verbose=1 "$APP"

echo "==> DMG"
cp -R "$APP" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
cp LICENSE "$DMG_ROOT/LICENSE.txt"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$DMG_ROOT" -ov -format UDZO -quiet "$DMG"

echo
echo "Готово: $DMG"
shasum -a 256 "$DMG"
