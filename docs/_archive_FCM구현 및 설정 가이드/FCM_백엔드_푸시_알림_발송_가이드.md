# FCM 푸시 알림 발송 가이드

백엔드 API와 Flutter 클라이언트에서 FCM 푸시 알림을 발송하는 방법을 설명합니다.

**대상**: 
- 백엔드 개발자 (예약, 결제 등 API 개발자)
- Flutter 클라이언트 개발자

---

## 📋 개요

이 가이드는 다른 API 파일(`reserve.py`, `payment.py` 등)에서 FCM 푸시 알림을 발송하는 방법을 설명합니다.

**중요**: 
- 공통 서비스 모듈(`FCMService`)을 사용하므로, 복잡한 초기화나 설정 없이 간단하게 사용할 수 있습니다.
- 다른 팀원의 파일을 수정하지 않고도 `import`만 추가하면 사용 가능합니다.
- **현재 상태**: ✅ 구현 완료 및 사용 가능

---

## ✅ 사전 요구사항

다음 항목들이 준비되어 있어야 합니다:

1. **Firebase 서비스 계정 키 파일**
   - `fastapi/serviceAccountKey.json` 파일이 존재해야 합니다
   - Firebase 콘솔에서 다운로드한 서비스 계정 키 파일
   - 파일이 없으면 알림 발송이 실패합니다 (로그에 경고 메시지 출력)

2. **Python 패키지 설치**
   - `firebase-admin>=6.0.0` 패키지가 설치되어 있어야 합니다
   - `requirements.txt`에 포함되어 있으므로 `pip install -r requirements.txt` 실행

3. **FCM 토큰 등록**
   - 고객이 앱에 로그인하여 FCM 토큰이 서버에 등록되어 있어야 합니다
   - `POST /api/customer/{customer_seq}/fcm-token` API를 통해 등록됨

**확인 방법**:
- 서버 실행 시 로그에 `✅ Firebase Admin SDK initialized successfully` 메시지가 출력되면 정상
- `⚠️  Warning: serviceAccountKey.json not found` 메시지가 나오면 서비스 계정 키 파일이 없는 것

---

## 🚀 빠른 시작

### 1. Import 추가

API 파일 상단에 다음을 추가하세요:

```python
from app.utils.fcm_service import FCMService
```

### 2. 알림 발송

예약 완료, 결제 완료 등 필요한 시점에 다음 코드를 추가하세요:

```python
# 예약 완료 시 알림 발송
FCMService.send_notification_to_customer(
    customer_seq=customer_seq,
    title="예약 완료",
    body="예약이 완료되었습니다.",
    data={
        "type": "reservation_complete",
        "reserve_seq": str(reserve_seq),
        "screen": "reservation_detail"
    }
)
```

**끝!** 이게 전부입니다. 🎉

**참고**: 
- 전역 초기화는 자동으로 처리됩니다 (`FCMService` 내부에서)
- 에러가 발생해도 API 응답은 정상적으로 반환됩니다 (로그에만 기록)
- 실제 동작 예시는 `fastapi/app/api/push_debug.py` 파일을 참고하세요

---

## 🎯 Flutter 클라이언트에서 사용하기

Flutter 앱에서도 간단하게 푸시 알림을 발송할 수 있습니다.

### 빠른 시작 (Flutter)

#### 1. Import 추가

```dart
import 'package:table_now_app/utils/push_notification_service.dart';
```

#### 2. 알림 발송

**특정 FCM 토큰에 발송:**
```dart
// 특정 토큰에 알림 발송
final messageId = await PushNotificationService.sendToToken(
  token: 'fcm_token_here',
  title: '알림 제목',
  body: '알림 내용',
  data: {
    'type': 'custom',
    'key': 'value',
  },
);

if (messageId != null) {
  print('✅ 알림 발송 성공: $messageId');
} else {
  print('❌ 알림 발송 실패');
}
```

**고객의 모든 기기에 발송 (권장):**
```dart
// 고객 번호만 있으면 자동으로 모든 기기에 발송
final successCount = await PushNotificationService.sendToCustomer(
  customerSeq: 123,
  title: '예약 완료',
  body: '예약이 완료되었습니다.',
  data: {
    'type': 'reservation_complete',
    'reserve_seq': '456',
    'screen': 'reservation_detail',
  },
);

print('✅ $successCount개 기기에 알림 발송 완료');
```

**끝!** 이게 전부입니다. 🎉

---

## 📖 상세 사용법 (백엔드)

### 함수 종류

`FCMService`는 다음 3가지 함수를 제공합니다:

#### 1. `send_notification_to_customer()` (권장)

**용도**: 고객의 모든 기기에 알림 발송 (가장 많이 사용)

**특징**:
- 고객 번호만 있으면 자동으로 DB에서 FCM 토큰 조회
- 여러 기기를 사용하는 고객에게 모두 발송
- 가장 간단하고 편리함

**사용 예시**:
```python
from app.utils.fcm_service import FCMService

# 예약 완료 시
FCMService.send_notification_to_customer(
    customer_seq=customer_seq,
    title="예약 완료",
    body="예약이 완료되었습니다.",
    data={
        "type": "reservation_complete",
        "reserve_seq": str(reserve_seq),
        "screen": "reservation_detail"
    }
)

# 예약 취소 시
FCMService.send_notification_to_customer(
    customer_seq=customer_seq,
    title="예약 취소",
    body="예약이 취소되었습니다.",
    data={
        "type": "reservation_cancelled",
        "reserve_seq": str(reserve_seq),
        "screen": "reservation_list"
    }
)

# 결제 완료 시
FCMService.send_notification_to_customer(
    customer_seq=customer_seq,
    title="결제 완료",
    body="결제가 완료되었습니다.",
    data={
        "type": "payment_complete",
        "payment_seq": str(payment_seq),
        "screen": "payment_detail"
    }
)
```

**반환값**: 발송 성공한 기기 수 (int)

---

#### 2. `send_notification()`

**용도**: 특정 FCM 토큰에 알림 발송

**사용 예시**:
```python
from app.utils.fcm_service import FCMService

# 특정 토큰에 알림 발송
message_id = FCMService.send_notification(
    token="fcm_token_here",
    title="알림 제목",
    body="알림 내용",
    data={
        "type": "custom",
        "key": "value"
    }
)
```

**반환값**: 메시지 ID (str) 또는 None (실패 시)

---

#### 3. `send_multicast_notification()`

**용도**: 여러 기기에 동시에 알림 발송 (최대 500개)

**사용 예시**:
```python
from app.utils.fcm_service import FCMService

# 여러 토큰에 동시 발송
tokens = ["token1", "token2", "token3"]
success_count = FCMService.send_multicast_notification(
    tokens=tokens,
    title="공지사항",
    body="새로운 공지사항이 있습니다.",
    data={
        "type": "announcement",
        "id": "123"
    }
)
```

**반환값**: 발송 성공한 기기 수 (int)

---

## 💡 실제 사용 예시

### Flutter 클라이언트 예시

#### 예시 1: 예약 완료 후 알림 발송
```dart
import 'package:table_now_app/utils/push_notification_service.dart';

// 예약 완료 후
Future<void> onReservationComplete(int customerSeq, int reserveSeq) async {
  // ... 예약 완료 로직 ...
  
  // 푸시 알림 발송
  await PushNotificationService.sendToCustomer(
    customerSeq: customerSeq,
    title: '예약 완료',
    body: '예약이 완료되었습니다.',
    data: {
      'type': 'reservation_complete',
      'reserve_seq': reserveSeq.toString(),
      'screen': 'reservation_detail',
    },
  );
}
```

#### 예시 2: 예약 취소 후 알림 발송
```dart
Future<void> onReservationCancelled(int customerSeq, int reserveSeq) async {
  // ... 예약 취소 로직 ...
  
  await PushNotificationService.sendToCustomer(
    customerSeq: customerSeq,
    title: '예약 취소',
    body: '예약이 취소되었습니다.',
    data: {
      'type': 'reservation_cancelled',
      'reserve_seq': reserveSeq.toString(),
      'screen': 'reservation_list',
    },
  );
}
```

#### 예시 3: 특정 토큰에 알림 발송 (테스트용)
```dart
// Dev_07 화면에서 사용 예시
Future<void> sendTestPush(String token) async {
  final messageId = await PushNotificationService.sendToToken(
    token: token,
    title: '테스트 알림',
    body: '이것은 테스트 메시지입니다.',
    data: {
      'type': 'test',
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
  
  if (messageId != null) {
    // 성공 처리
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('알림 발송 성공: $messageId')),
    );
  }
}
```

---

### 백엔드 API 예시

#### 예시 1: 예약 완료 API (`reserve.py`)

```python
from fastapi import APIRouter
from app.utils.fcm_service import FCMService

router = APIRouter()

@router.post("/create")
async def create_reservation(customer_seq: int, ...):
    # ... 예약 생성 로직 ...
    
    # 예약 완료 후 푸시 알림 발송
    FCMService.send_notification_to_customer(
        customer_seq=customer_seq,
        title="예약 완료",
        body="예약이 완료되었습니다.",
        data={
            "type": "reservation_complete",
            "reserve_seq": str(reserve_seq),
            "screen": "reservation_detail"
        }
    )
    
    return {"result": "OK", "reserve_seq": reserve_seq}
```

### 예시 2: 예약 취소 API (`reserve.py`)

```python
@router.delete("/cancel/{reserve_seq}")
async def cancel_reservation(reserve_seq: int):
    # ... 예약 취소 로직 ...
    
    # 예약 취소 후 푸시 알림 발송
    FCMService.send_notification_to_customer(
        customer_seq=customer_seq,
        title="예약 취소",
        body="예약이 취소되었습니다.",
        data={
            "type": "reservation_cancelled",
            "reserve_seq": str(reserve_seq),
            "screen": "reservation_list"
        }
    )
    
    return {"result": "OK"}
```

### 예시 3: 결제 완료 API (`payment.py`)

```python
from app.utils.fcm_service import FCMService

@router.post("/complete")
async def complete_payment(customer_seq: int, ...):
    # ... 결제 완료 로직 ...
    
    # 결제 완료 후 푸시 알림 발송
    FCMService.send_notification_to_customer(
        customer_seq=customer_seq,
        title="결제 완료",
        body="결제가 완료되었습니다.",
        data={
            "type": "payment_complete",
            "payment_seq": str(payment_seq),
            "amount": str(amount),
            "screen": "payment_detail"
        }
    )
    
    return {"result": "OK"}
```

---

## 📝 Flutter PushNotificationService API

### 함수 종류

`PushNotificationService`는 다음 2가지 함수를 제공합니다:

#### 1. `sendToCustomer()` (권장)

**용도**: 고객의 모든 기기에 알림 발송

**특징**:
- 고객 번호만 있으면 자동으로 DB에서 FCM 토큰 조회
- 여러 기기를 사용하는 고객에게 모두 발송
- 가장 간단하고 편리함

**사용 예시**:
```dart
final successCount = await PushNotificationService.sendToCustomer(
  customerSeq: customerSeq,
  title: '예약 완료',
  body: '예약이 완료되었습니다.',
  data: {
    'type': 'reservation_complete',
    'reserve_seq': '123',
    'screen': 'reservation_detail',
  },
);
```

**반환값**: 발송 성공한 기기 수 (int)

---

#### 2. `sendToToken()`

**용도**: 특정 FCM 토큰에 알림 발송

**사용 예시**:
```dart
final messageId = await PushNotificationService.sendToToken(
  token: 'fcm_token_here',
  title: '알림 제목',
  body: '알림 내용',
  data: {
    'type': 'custom',
    'key': 'value',
  },
);
```

**반환값**: 메시지 ID (String?) 또는 null (실패 시)

---

## 📝 알림 데이터 구조

### `data` 필드 구조

알림 클릭 시 화면 이동을 위해 `data` 필드에 다음 정보를 포함하세요:

```python
data={
    "type": "알림_타입",           # 예: "reservation_complete"
    "reserve_seq": "123",          # 예약 번호 (필요시)
    "payment_seq": "456",          # 결제 번호 (필요시)
    "screen": "화면_경로"           # 예: "reservation_detail"
}
```

### 알림 타입별 권장 구조

#### 예약 완료
```python
{
    "type": "reservation_complete",
    "reserve_seq": str(reserve_seq),
    "screen": "reservation_detail"
}
```

#### 예약 취소
```python
{
    "type": "reservation_cancelled",
    "reserve_seq": str(reserve_seq),
    "screen": "reservation_list"
}
```

#### 예약 변경
```python
{
    "type": "reservation_modified",
    "reserve_seq": str(reserve_seq),
    "screen": "reservation_detail"
}
```

#### 결제 완료
```python
{
    "type": "payment_complete",
    "payment_seq": str(payment_seq),
    "amount": str(amount),
    "screen": "payment_detail"
}
```

---

## ⚠️ 주의사항

1. **비동기 처리**: 푸시 알림 발송은 비동기로 처리되므로, API 응답 속도에 영향을 주지 않습니다.

2. **에러 처리**: 발송 실패 시 자동으로 로그에 기록되며, API 응답은 정상적으로 반환됩니다.

3. **토큰 없음**: 고객에게 등록된 FCM 토큰이 없으면 알림이 발송되지 않습니다 (정상 동작).

4. **토큰 만료**: 만료된 토큰은 자동으로 무시되며, 성공한 기기만 알림을 받습니다.

---

## 🔍 문제 해결

### 알림이 발송되지 않는 경우

1. **FCM 토큰 확인**: 고객이 앱에 로그인하여 FCM 토큰이 등록되었는지 확인
2. **서비스 계정 키 확인**: `fastapi/serviceAccountKey.json` 파일이 존재하는지 확인
3. **로그 확인**: 서버 로그에서 에러 메시지 확인

### 로그 확인 방법

서버 실행 시 다음 로그를 확인하세요:
- `✅ Firebase Admin SDK initialized successfully` - 초기화 성공
- `✅ Push notification sent: {message_id}` - 발송 성공
- `⚠️  FCM token is invalid or expired` - 토큰 만료
- `❌ Failed to send push notification: {error}` - 발송 실패

---

## 📚 관련 문서

- [FCM 메시지 데이터 활용 가이드](./FCM_메시지_데이터_활용_가이드.md) - `data` 필드 활용 방법
- [FCM 로컬 저장소 및 서버 연동 가이드](./FCM_로컬_저장소_및_서버_연동_가이드.md) - FCM 토큰 관리
- [FastAPI FCM 단발 푸시 테스트 가이드](./FastAPI_FCM_단발_푸시_테스트_가이드.md) - 테스트 방법

---

## 🔄 백엔드 API 엔드포인트

### 1. 특정 토큰에 알림 발송
```
POST /api/debug/push
Content-Type: application/json

{
  "token": "fcm_token_here",
  "title": "알림 제목",
  "body": "알림 내용",
  "data": {
    "type": "custom",
    "key": "value"
  }
}
```

### 2. 고객의 모든 기기에 알림 발송 (신규 추가)
```
POST /api/customer/{customer_seq}/push
Content-Type: application/json

{
  "title": "알림 제목",
  "body": "알림 내용",
  "data": {
    "type": "reservation_complete",
    "reserve_seq": "123",
    "screen": "reservation_detail"
  }
}
```

**응답 예시**:
```json
{
  "result": "OK",
  "success_count": 2,
  "message": "2개 기기에 알림이 발송되었습니다."
}
```

---

## 변경 이력

- **2026-01-19**: 초기 문서 작성
  - 백엔드 개발자용 FCM 푸시 알림 발송 가이드 작성
  - 사용 예시 및 주의사항 추가
- **2026-01-19**: 사전 요구사항 섹션 추가
  - Firebase 서비스 계정 키 파일 필요 여부 명시
  - 확인 방법 및 로그 메시지 설명 추가
- **2026-01-18**: Flutter 클라이언트 사용법 추가
  - `PushNotificationService` 유틸리티 클래스 생성
  - Flutter에서 푸시 알림 발송 방법 추가
  - 백엔드 API 엔드포인트 추가 (`POST /api/customer/{customer_seq}/push`)
  - Flutter 사용 예시 추가