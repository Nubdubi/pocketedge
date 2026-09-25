import 'dart:io';

import 'package:pocketedge/pocketedge.dart';

Future<void> main() async {
  final edge = PocketEdge(
    config: const PocketEdgeConfig(pairingRequired: true),
  );

  edge.get('/api/hello', (_) async {
    return EdgeResponse.json({'message': 'Hello from PocketEdge'});
  });

  edge.issuePairingToken(role: 'staff');
  await edge.start();
  stdout.writeln('PocketEdge is running at ${edge.url}');
}
