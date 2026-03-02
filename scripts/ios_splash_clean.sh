#!/bin/bash
# iOS 스플래시 캐시 완전 삭제 스크립트
# 구 스플래시가 계속 나올 때 실행

set -e
cd "$(dirname "$0")/.."
BUNDLE_ID="com.cheng80.habitcell"

echo "=== 1. Flutter clean ==="
flutter clean

echo ""
echo "=== 2. iOS 빌드 폴더 삭제 ==="
rm -rf ios/build

echo ""
echo "=== 3. Xcode DerivedData 삭제 (Runner, Pods) ==="
rm -rf ~/Library/Developer/Xcode/DerivedData/*Runner* 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/*Pods* 2>/dev/null || true

echo ""
echo "=== 4. 스플래시 재생성 ==="
dart run flutter_native_splash:create

echo ""
echo "=== 4b. iOS LaunchImage 캐시 버스팅 (파일명 변경으로 캐시 무효화) ==="
IMAGESET="ios/Runner/Assets.xcassets/LaunchImage.imageset"
if [ -d "$IMAGESET" ]; then
  CB="cb$(date +%s)"
  for f in "$IMAGESET"/LaunchImage*.png; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .png)
    new_base=$(echo "$base" | sed "s/LaunchImage/LaunchImage_${CB}/")
    mv "$f" "$IMAGESET/${new_base}.png"
  done
  sed -i '' "s/LaunchImage/LaunchImage_${CB}/g" "$IMAGESET/Contents.json"
  echo "  LaunchImage -> LaunchImage_${CB} (캐시 무효화)"
fi

echo ""
echo "=== 5. 시뮬레이터에서 앱 삭제 (캐시 제거) ==="
xcrun simctl uninstall booted "$BUNDLE_ID" 2>/dev/null || echo "  (시뮬레이터 미실행 또는 앱 미설치)"

echo ""
echo "=== 6. pub get ==="
flutter pub get

echo ""
echo "✅ 완료. 다음 명령으로 재빌드하세요:"
echo "   flutter run"
echo ""
echo "※ 여전히 구 이미지가 보이면 시뮬레이터 초기화:"
echo "   Device > Erase All Content and Settings"
