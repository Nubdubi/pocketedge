# Security policy

PocketEdge is local-first, but a local network is not automatically trusted. Report suspected vulnerabilities privately to the repository maintainers before opening a public issue.

The MVP includes optional TLS, persistent session storage, bounded rate limiting, and basic file-upload hardening. Pairing tokens are short-lived and single-use. Applications should still add authentication policy, malware scanning, quotas, and content-specific validation before exposing uploads to untrusted users.

Android foreground hosting requires the system notification permission where applicable. The service does not bypass Android force-stop, battery restrictions, or device shutdown behavior.

Desktop persistent mode changes window lifecycle only; it does not grant additional network or filesystem permissions.

Replay protection is opt-in per protected POST route and validates request ID/nonce uniqueness plus timestamp freshness. It is not a substitute for request-body signatures or TLS.

`EdgeFileStore` never uses client-provided filenames as paths and validates signatures for PNG, JPEG, WebP, and PDF uploads by default. Applications should still scan files and validate thumbnails before displaying untrusted uploads.

Do not enable wildcard CORS origins for privileged APIs. Configure explicit trusted origins with `edgeCors`.

Set `realtimeAuthRequired: true` when WebSocket channels contain privileged data. The Local Room demo leaves this disabled so a plain browser can demonstrate local chat.
