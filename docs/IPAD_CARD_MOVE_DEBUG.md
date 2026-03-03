# iPad 카드 이동 갱신 문제 원인 파악 가이드

> "이동을 하면 화면 크기 차이 때문인지 이동 관련 갱신이 제대로 안됨"

---

## 1. 증상 정리

| 항목 | 확인됨 |
|------|--------|
| **이동 유형** | 같은 컬럼 내 드래그 재정렬 |
| "갱신이 안됨" | (추가 확인 필요: UI 미반영? 서버 미반영? WebSocket?) |
| iPhone | (비교 테스트 필요) |
| 재현 조건 | (특정 조건에서만? 항상?) |

---

## 2. 의심 원인 후보

### A. ReorderableListView (같은 컬럼 내 드래그) ← **주요 의심**

| 후보 | 설명 |
|------|------|
| **내부 상태 미갱신** | ReorderableListView가 드래그 후 내부 리스트 상태를 갱신하지 않음 (Flutter 이슈) |
| **_displayCards vs 실제 렌더** | setState 후 _displayCards는 갱신됐는데 ReorderableListView가 itemBuilder를 다시 호출하지 않음 |
| **buildDefaultDragHandles** | iPad에서 드래그 핸들 인식 차이 |
| **viewport/스크롤** | iPad 큰 화면에서 스크롤 영역·레이아웃 계산 차이 |

### B. PageView + 데이터 전파

| 후보 | 설명 |
|------|------|
| **itemBuilder 미호출** | optimisticMoves 변경 시 PageView가 현재 페이지의 itemBuilder를 다시 호출하지 않음 |
| **캐시된 페이지** | PageView가 이전 페이지 상태를 캐시해 새 데이터를 반영하지 않음 |
| **key 변경 타이밍** | `ValueKey('col_${col.id}_$cardsKey')` 변경 시 위젯 재생성 순서/타이밍 이슈 |

### C. optimisticMoves / boardDetailCache 전파

| 후보 | 설명 |
|------|------|
| **Provider 리빌드 순서** | iPad에서 rebuild 스케줄링이 달라 데이터 전파가 늦음 |
| **cachedDetail vs detail** | `effective = cachedDetail ?? detail` 사용 시 캐시가 stale한 상태로 유지 |

### D. WebSocket / REST

| 후보 | 설명 |
|------|------|
| **CARD_MOVED 미수신** | iPad에서 WebSocket 연결/메시지 수신 차이 |
| **REST 폴백 실패** | WebSocket 미연결 시 REST 호출이 실패하거나 응답을 반영하지 않음 |

---

## 3. 디버그 로그 추가 (원인 추적용)

### 3.1 `_onReorder` 진입·완료

```dart
// _onReorder 시작
debugPrint('[카드이동] _onReorder START old=$oldIndex new=$newIndex cards=${_displayCards.length}');

// setState 직후
debugPrint('[카드이동] _onReorder setState done, _displayCards=${_displayCards.map((c) => '${c.id}:${c.position}').join(',')}');

// optimistic 업데이트 직후
debugPrint('[카드이동] _onReorder optimistic updated');
```

### 3.2 `didUpdateWidget` 호출 여부

```dart
@override
void didUpdateWidget(_ColumnView oldWidget) {
  super.didUpdateWidget(oldWidget);
  final changed = !_listEquals(widget.cards, oldWidget.cards);
  debugPrint('[카드이동] didUpdateWidget col=${widget.column.id} changed=$changed oldLen=${oldWidget.cards.length} newLen=${widget.cards.length}');
  if (changed) {
    _displayCards = List.from(widget.cards);
    debugPrint('[카드이동] didUpdateWidget _displayCards synced');
  }
}
```

### 3.3 PageView itemBuilder 호출

```dart
// _BoardColumnsViewState build 내부, itemBuilder 안
itemBuilder: (context, index) {
  debugPrint('[카드이동] PageView itemBuilder index=$index col=${col.id} cardsLen=${cards.length}');
  // ...
}
```

### 3.4 CARD_MOVED / REST 응답

```dart
// _applyCardMoved
debugPrint('[카드이동] _applyCardMoved cardId=$cardId columnId=$columnId position=$position');

// REST 성공 시
debugPrint('[카드이동] _onReorder REST success, calling onRefresh');
```

---

## 4. 확인 절차

1. **로그 추가** 후 iPad에서 카드 이동 실행
2. **콘솔 로그 확인**:
   - `_onReorder START` → `setState done` → `optimistic updated` 순서로 출력되는지
   - `didUpdateWidget`가 호출되는지, `changed`가 true인지
   - `PageView itemBuilder`가 optimistic 업데이트 이후에 다시 호출되는지
3. **비교**: iPhone에서 동일 동작 시 로그 차이 확인

---

## 5. 다음 단계

- 로그 결과를 바탕으로 **어느 구간에서 끊기는지** 특정
- 해당 구간에 맞는 수정 방안 적용 (예: itemBuilder 미호출 → PageView key/캐시 조정 등)
