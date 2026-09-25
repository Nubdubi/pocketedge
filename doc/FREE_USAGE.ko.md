# 무료 사용 범위

PocketEdge의 공개 패키지는 다음 기능을 무료로 제공합니다.

- 같은 네트워크의 LAN HTTP/WebSocket 연결
- QR 및 `GET /_edge/join` 연결 정보
- Pairing Token과 세션 인증
- 메모리·SQLite 저장소
- 사용자가 직접 운영하는 Cloudflare Tunnel
- `pocketedge tunnel` 설정 도우미

이 저장소에는 유료 서비스의 Relay 서버, 운영용 API Key, 결제 로직,
Cloudflare 인증서 또는 운영 도메인을 포함하지 않습니다. 유료 Relay는
나중에 별도 서버와 별도 패키지로 추가할 수 있도록 현재 패키지는
`PocketEdgeCloudAdapter`와 공개 연결 설정만 제공합니다.

## 무료 외부 접속

외부 접속이 필요하면 사용자의 컴퓨터에 `cloudflared`를 설치하고 사용자의
Cloudflare 계정과 도메인을 연결합니다.

```bash
cloudflared tunnel login
dart pub global activate pocketedge
pocketedge tunnel setup --hostname edge.example.com --port 8080
pocketedge tunnel start
```

호스트 앱은 다음처럼 공개 주소를 광고합니다.

```dart
final edge = PocketEdge(
  config: PocketEdgeConfig(
    bindAddress: '127.0.0.1',
    port: 8080,
    publicBaseUrl: Uri.parse('https://edge.example.com'),
    pairingRequired: true,
    realtimeAuthRequired: true,
  ),
);
```

API Key는 QR 코드나 Flutter 클라이언트에 넣지 마세요. Tunnel 인증서,
`config.yml`, 토큰은 Git에 커밋하지 말고 사용자 컴퓨터의
`~/.cloudflared/`에 보관해야 합니다.
