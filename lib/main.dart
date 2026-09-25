import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pocketedge/pocketedge.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketEdgeExampleApp());
}

class PocketEdgeExampleApp extends StatelessWidget {
  const PocketEdgeExampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PocketEdge Local Room',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff4f46e5)),
          useMaterial3: true,
        ),
        home: const LocalRoomPage(),
      );
}

class LocalRoomPage extends StatefulWidget {
  const LocalRoomPage({super.key});
  @override
  State<LocalRoomPage> createState() => _LocalRoomPageState();
}

class _LocalRoomPageState extends State<LocalRoomPage> {
  static const _backgroundChannel = MethodChannel('pocketedge/background');
  final _edge = PocketEdge();
  final _desktopHost = DesktopHostController();
  final _messageController = TextEditingController();
  final _messages = <String>[
    'Welcome to the local room.',
    'This chat keeps working when the internet is off.',
  ];
  bool _running = false;

  @override
  void dispose() {
    _messageController.dispose();
    _edge.stop();
    super.dispose();
  }

  Future<void> _toggleServer() async {
    if (_running) {
      await _edge.stop();
      await _desktopHost.setPersistent(false);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _backgroundChannel.invokeMethod<void>('stop');
      }
    } else {
      _edge.issuePairingToken(role: 'staff');
      _edge.get(
        '/hello',
        (_) async => EdgeResponse.json({'message': 'Hello from PocketEdge'}),
      );
      await _edge.start();
      await _desktopHost.setPersistent(true);
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _backgroundChannel.invokeMethod<void>('start');
      }
    }
    if (mounted) setState(() => _running = !_running);
  }

  void _send() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    setState(() {
      _messages.add(message);
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _edge.status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PocketEdge Local Room'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                Icons.circle,
                size: 12,
                color: _running ? Colors.green : Colors.grey,
              ),
              label: Text(_running ? 'Local host online' : 'Host stopped'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      runSpacing: 16,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'A local-first room',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Share this room over Wi-Fi. No cloud account required.',
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: _toggleServer,
                          icon: const Icon(Icons.power_settings_new),
                          label: Text(
                            _running ? 'Stop host' : 'Start local host',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_running)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          QrImageView(data: _edge.joinInfo.encode(), size: 112),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.wifi),
                              title: Text(
                                status.localAddress == null
                                    ? 'Listening locally'
                                    : status.url,
                              ),
                              subtitle: Text(
                                'Scan to join · Node ${_edge.nodeId}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        const ListTile(
                          leading: Icon(Icons.forum_outlined),
                          title: Text('Room chat'),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _messages.length,
                            itemBuilder: (_, index) => Align(
                              alignment: index == _messages.length - 1
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: index == _messages.length - 1
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(_messages[index]),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  onSubmitted: (_) => _send(),
                                  decoration: const InputDecoration(
                                    hintText: 'Write a local message...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _send,
                                icon: const Icon(Icons.send),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
