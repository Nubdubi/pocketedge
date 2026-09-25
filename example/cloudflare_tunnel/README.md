# Cloudflare Tunnel example

This example exposes a PocketEdge host through a public HTTPS hostname without
opening an inbound router port. `cloudflared` makes the outbound tunnel and
forwards the hostname to the local PocketEdge HTTP listener.

## 1. Configure the host

Use a loopback listener and advertise the public origin in join information:

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

`publicBaseUrl` is used for QR codes and `GET /_edge/join`. It does not change
where PocketEdge listens. Keep pairing enabled and issue short-lived pairing
tokens for clients.

## 2. Create and run the tunnel

Install `cloudflared`, authenticate it, then run:

```bash
cloudflared tunnel login
cloudflared tunnel create pocketedge
cloudflared tunnel route dns pocketedge edge.example.com
cloudflared tunnel ingress validate
cloudflared tunnel --config ~/.cloudflared/config.yml run pocketedge
```

For guided setup without manual YAML editing:

```bash
cloudflared tunnel login
dart pub global activate pocketedge
pocketedge tunnel setup --hostname edge.example.com --port 8080
pocketedge tunnel start
```

The helper creates the tunnel, routes DNS, writes `config.yml`, and prints the
public URL. Use `pocketedge tunnel status` to inspect it.

Start PocketEdge before the tunnel, or make sure the tunnel retries while the
local service is starting. The final catch-all ingress rule is required.

## Security

The public hostname is now reachable from the internet. Use PocketEdge pairing
and session authentication, keep the tunnel credentials outside Git, and add
Cloudflare Access when the application needs an identity or organization-level
policy. The example deliberately uses local HTTP between `cloudflared` and
PocketEdge; Cloudflare terminates HTTPS at the public edge. If the local origin
is configured for HTTPS instead, change the service URL to `https://...` and
configure the matching origin certificate settings.
