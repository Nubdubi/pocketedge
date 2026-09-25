# PocketEdge AI 사용 가이드

이 문서는 AI 코딩 도구가 PocketEdge를 정확하고 안전하게 사용하는 데 필요한 작업 순서와 선택 기준을 정의합니다.

## 기본 선택 규칙

| 목적 | 사용할 API |
| --- | --- |
| 공개 GET API | `edge.get()` |
| 공개 POST API | `edge.post()` |
| 세션이 필요한 API | `edge.secureGet()` / `edge.securePost()` |
| 로컬 데이터 | `MemoryEdgeStorage` 또는 native `SqliteEdgeStorage` |
| 실시간 이벤트 | `edge.channel(name)` |
| 파일 업로드 | `EdgeFileStore` + `files.write` 권한 |
| 오프라인 작업 | `OfflineQueue` 또는 native `SqliteOfflineQueue` |
| 클라우드 동기화 | `SyncCoordinator` + `PocketEdgeCloudAdapter` |
| QR 연결 | `edge.joinInfo` |

## 표준 구현 순서

1. 앱의 호스트 플랫폼과 Web 여부를 확인합니다.
2. `PocketEdgeConfig`에서 포트, pairing, realtime, TLS를 결정합니다.
3. 공개 health/join API와 애플리케이션 API를 구분합니다.
4. 개인 데이터 API에는 `secureGet` 또는 `securePost`를 사용합니다.
5. pairing token으로 세션을 발급하고 역할/권한을 확인합니다.
6. `await edge.start()` 후 사용하고, 종료 시 `await edge.stop()`을 호출합니다.
7. `flutter analyze`와 `flutter test`를 실행합니다.

## 보안 기본값

AI는 다음 설정을 우선 제안해야 합니다.

```dart
final edge = PocketEdge(
  config: const PocketEdgeConfig(
    pairingRequired: true,
    realtimeAuthRequired: true,
  ),
);
```

실제 서비스에서는 명시적인 CORS origin과 TLS를 사용합니다. 토큰, 인증서,
keystore, SQLite 데이터베이스, 클라우드 API 키를 코드나 README 예제에 넣지
않습니다. 파일 업로드에는 `EdgeFileStore`의 크기·MIME·시그니처 검사를 유지하고,
운영 환경에서는 악성코드 검사를 추가합니다.

## 플랫폼별 주의

- Web에서는 SQLite API를 사용하지 않습니다. `MemoryEdgeStorage` 또는 서버 저장소를 사용합니다.
- Android foreground service는 force-stop과 기기 종료를 우회하지 않습니다.
- QR payload에는 단기 pairing token만 넣고 장기 비밀키를 넣지 않습니다.
- `edge.stop()`은 서버와 LAN 주소 모니터를 종료합니다.

## AI가 피해야 할 패턴

```dart
// 피해야 함: 인증 없는 개인 데이터 API
edge.get('/api/orders', handler);

// 피해야 함: 비밀값을 클라이언트 코드에 하드코딩
headers: {'authorization': 'Bearer real-production-token'};
```

대신 개인 데이터에는 권한 검사를 사용하고, 클라우드 인증정보는 신뢰할 수
있는 백엔드 adapter에 보관합니다.
