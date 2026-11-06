#!/bin/bash
# Сборка RedQuit.app из терминала: swift build → пакет .app → подпись → проверка подписи.
#
#   ./Scripts/build.sh                 — подписать первым действующим сертификатом «Apple Development»
#   SIGN_IDENTITY=<SHA-1> ./Scripts/build.sh — подписать указанным сертификатом
#   ADHOC=1 ./Scripts/build.sh         — ad-hoc подпись (НЕ рекомендуется, см. предупреждение ниже)
#
# Результат: build/RedQuit.app
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="RedQuit"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

# --- Выбор сертификата -------------------------------------------------------
# Важно: подпись должна быть одной и той же от сборки к сборке. При ad-hoc подписи
# (codesign -s -) macOS считает каждую сборку новой программой и сбрасывает
# разрешение «Универсальный доступ». С сертификатом Apple Development требование
# подписи стабильно, и разрешение сохраняется.
# Выбираем по отпечатку SHA-1, а не по имени: в связке ключей может лежать
# просроченный сертификат с таким же именем, и тогда codesign не может выбрать сам.
if [[ "${ADHOC:-0}" == "1" ]]; then
    SIGN_IDENTITY="-"
elif [[ -z "${SIGN_IDENTITY:-}" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning | grep '"Apple Development' | head -n 1 | awk '{print $2}')"
    if [[ -z "$SIGN_IDENTITY" ]]; then
        echo "ОШИБКА: не найден действующий сертификат «Apple Development»." >&2
        echo "Войдите в Xcode → Settings → Accounts со своим Apple ID и создайте сертификат," >&2
        echo "или соберите с ADHOC=1 (разрешение будет слетать после каждой пересборки)." >&2
        exit 1
    fi
fi

# --- Компиляция ---------------------------------------------------------------
echo "==> Компиляция (release)"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

# --- Пакет .app ---------------------------------------------------------------
echo "==> Сборка $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Переводы интерфейса: <язык>.lproj/Localizable.strings
cp -R Resources/Localization/*.lproj "$APP/Contents/Resources/"

# --- Подпись ------------------------------------------------------------------
echo "==> Подпись"
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo
echo "Готово: $APP"
codesign -d --verbose=2 "$APP" 2>&1 | grep -E '^(Identifier|Authority|TeamIdentifier)=' | head -n 3
codesign -d -r- "$APP" 2>&1 | grep '^designated' || true

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo
    echo "ВНИМАНИЕ: ad-hoc подпись. После каждой пересборки macOS сбросит разрешение"
    echo "«Универсальный доступ» — его придётся выдавать заново."
fi
