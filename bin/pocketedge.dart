import 'dart:io';

import 'package:pocketedge/src/tunnel/cloudflare_tunnel.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args[0] != 'tunnel') {
    _usage();
    exitCode = 64;
    return;
  }

  final command = args[1];
  final options = _options(args.skip(2).toList());
  switch (command) {
    case 'setup':
      await _setup(options);
    case 'start':
      await _start(options);
    case 'status':
      exitCode = await _runCloudflared([
        'tunnel',
        'info',
        options['name'] ?? 'pocketedge',
      ]);
    default:
      _usage();
      exitCode = 64;
  }
}

Map<String, String> _options(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final value = args[i];
    if (!value.startsWith('--')) continue;
    final key = value.substring(2);
    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      result[key] = args[++i];
    } else {
      result[key] = 'true';
    }
  }
  return result;
}

Future<void> _setup(Map<String, String> options) async {
  final hostname = options['hostname'];
  if (hostname == null || !_validHostname(hostname)) {
    stderr.writeln('사용법: pocketedge tunnel setup --hostname edge.example.com');
    exitCode = 64;
    return;
  }
  if (!await _hasCloudflared()) {
    stderr.writeln('cloudflared가 설치되어 있지 않습니다.');
    stderr.writeln(
        '설치 안내: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/');
    exitCode = 69;
    return;
  }

  final name = options['name'] ?? 'pocketedge';
  final port = int.tryParse(options['port'] ?? '8080') ?? 8080;
  final configPath = options['config'] ?? _defaultConfigPath;
  final tunnelId = await _createTunnel(name);
  if (tunnelId == null) return;

  final routeExitCode = await _runCloudflared([
    'tunnel',
    'route',
    'dns',
    name,
    hostname,
  ]);
  if (routeExitCode != 0) {
    exitCode = routeExitCode;
    return;
  }

  final config = CloudflareTunnelConfig(
    tunnelId: tunnelId,
    tunnelName: name,
    hostname: hostname,
    localPort: port,
  );
  await config.writeTo(File(configPath));
  stdout.writeln('\n완료되었습니다.');
  stdout.writeln('설정 파일: $configPath');
  stdout.writeln('PocketEdge 공개 주소: https://$hostname');
  stdout.writeln('다음 명령으로 Tunnel을 시작하세요:');
  stdout.writeln('  pocketedge tunnel start --name $name --config $configPath');
}

Future<void> _start(Map<String, String> options) async {
  if (!await _hasCloudflared()) {
    stderr.writeln('cloudflared가 설치되어 있지 않습니다.');
    exitCode = 69;
    return;
  }
  final name = options['name'] ?? 'pocketedge';
  final config = options['config'] ?? _defaultConfigPath;
  final process = await Process.start(
    'cloudflared',
    ['tunnel', '--config', config, 'run', name],
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await process.exitCode;
}

Future<String?> _createTunnel(String name) async {
  stdout.writeln('Cloudflare Tunnel을 확인합니다: $name');
  final result = await Process.run('cloudflared', ['tunnel', 'create', name]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('Tunnel 생성에 실패했습니다. 먼저 `cloudflared tunnel login`을 실행하세요.');
    exitCode = result.exitCode;
    return null;
  }
  final output = '${result.stdout}\n${result.stderr}';
  final match = RegExp(r'[0-9a-f]{8}-[0-9a-f-]{27,}').firstMatch(output);
  if (match == null) {
    stderr.writeln('Tunnel ID를 확인하지 못했습니다. `cloudflared tunnel list`로 확인하세요.');
    exitCode = 1;
    return null;
  }
  return match.group(0);
}

Future<int> _runCloudflared(List<String> args) async {
  final process = await Process.start(
    'cloudflared',
    args,
    mode: ProcessStartMode.inheritStdio,
  );
  return process.exitCode;
}

Future<bool> _hasCloudflared() async {
  final result = await Process.run(
    Platform.isWindows ? 'where' : 'which',
    ['cloudflared'],
  );
  return result.exitCode == 0;
}

bool _validHostname(String value) => RegExp(
      r'^[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}$',
    ).hasMatch(value);

String get _defaultConfigPath => Platform.isWindows
    ? '${Platform.environment['USERPROFILE'] ?? '.'}\\.cloudflared\\config.yml'
    : '${Platform.environment['HOME'] ?? '.'}/.cloudflared/config.yml';

void _usage() {
  stdout.writeln('''PocketEdge Tunnel 도우미

사용법:
  pocketedge tunnel setup --hostname edge.example.com [--name pocketedge] [--port 8080]
  pocketedge tunnel start [--name pocketedge] [--config ~/.cloudflared/config.yml]
  pocketedge tunnel status [--name pocketedge]

처음 한 번만 실행:
  cloudflared tunnel login
''');
}
