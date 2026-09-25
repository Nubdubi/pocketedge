# PocketEdge 사용 안내

PocketEdge는 인터넷이나 클라우드가 끊겨도 같은 LAN에서 동작하는 Flutter용 로컬 서버 프레임워크입니다. HTTP API, WebSocket, QR 연결, SQLite 저장소, 파일 공유, 오프라인 큐와 선택적 클라우드 동기화를 제공합니다.

## 시작하기

```bash
flutter pub get
flutter analyze
flutter test
```

기본 호스트:

```dart
import 'package:pocketedge/pocketedge.dart';

final edge = PocketEdge();
edge.get('/api/hello', (_) async =>
    EdgeResponse.json({'message': '안녕하세요'}));
await edge.start();
print(edge.url);
```

호스트를 종료할 때는 `await edge.stop()`을 호출합니다. QR 연결 정보는 `edge.joinInfo` 또는 `GET /_edge/join`으로 가져옵니다.

## Cloudflare Tunnel로 외부 접속

같은 Wi-Fi 밖의 기기에서도 접속하려면 PocketEdge를 로컬 루프백에만
바인딩하고, 같은 기기에서 `cloudflared`를 실행합니다.

```dart
final edge = PocketEdge(
  config: PocketEdgeConfig(
    port: 8080,
    bindAddress: '127.0.0.1',
    publicBaseUrl: Uri.parse('https://edge.example.com'),
    pairingRequired: true,
    realtimeAuthRequired: true,
  ),
);
await edge.start();
```

`publicBaseUrl`은 QR 코드와 `GET /_edge/join`에 공개 주소를 넣습니다.
실제 PocketEdge 포트를 인터넷에 직접 공개하는 설정은 아닙니다.
`example/cloudflare_tunnel/config.yml.example`처럼 `cloudflared`가
`http://127.0.0.1:8080`으로 전달하도록 설정하세요. 공개 HTTPS는
Cloudflare에서 종료되고, WebSocket은 자동으로 `wss://`를 사용합니다.

인터넷에서 접근 가능해지므로 `pairingRequired`와
`realtimeAuthRequired`를 켜고, 터널 인증서·토큰 파일은 Git에 커밋하지
마세요. 조직 계정 인증이 필요하면 Cloudflare Access도 함께 사용하세요.

### YAML을 직접 작성하지 않는 방법

다음 명령을 사용하면 Tunnel 생성, DNS 연결, YAML 생성을 자동으로 처리할
수 있습니다.

```bash
cloudflared tunnel login
dart pub global activate pocketedge
pocketedge tunnel setup --hostname edge.example.com --port 8080
pocketedge tunnel start
```

생성된 설정은 `~/.cloudflared/config.yml`에 저장됩니다. 상태 확인은
`pocketedge tunnel status`로 할 수 있습니다.

## 보안 사용법

권한이 필요한 API는 pairing token으로 세션을 만든 뒤 사용합니다.

```dart
final token = edge.issuePairingToken(role: 'staff');
```

클라이언트는 `POST /_edge/pair`에 `pairToken`과 `deviceId`를 보내고, 응답의 세션 토큰을 `Authorization: Bearer <token>`으로 전송합니다. 운영 환경에서는 `pairingRequired: true`, 명시적 CORS origin, HTTPS, `realtimeAuthRequired: true`를 검토하십시오.

비밀값과 인증서는 `.env`, `*.pem`, `*.key`, `*.p12`, Android keystore 등에 저장하며 Git에 커밋하지 않습니다. 이미 커밋된 비밀값은 `.gitignore`만으로 삭제되지 않으므로 즉시 폐기하고 교체해야 합니다.

## 파일 공유

`EdgeFileStore`는 파일 크기, MIME allowlist, PNG/JPEG/WebP/PDF 시그니처를 검사합니다. 업로드 파일은 악성코드 검사와 썸네일 검사를 별도로 적용하십시오.

## 배포

```bash
flutter build apk --release
flutter build appbundle --release
flutter build macos --release
flutter build web --release --no-wasm-dry-run
```

Android Play Store는 release keystore와 `.aab`가 필요하고, macOS 배포는 Developer ID 서명과 공증이 필요합니다. Web은 `build/web` 전체를 정적 호스팅에 업로드합니다.

## Web 제한사항

SQLite는 `dart:ffi` 기반이므로 Web에서 사용할 수 없습니다. Web에서는 기본 메모리 저장소와 메모리 큐를 사용하고, 영속성이 필요하면 서버 또는 클라우드 adapter를 사용하십시오.
