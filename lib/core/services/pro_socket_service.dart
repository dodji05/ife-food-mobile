// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Service Socket.IO côté professionnel
//
// Connexion au namespace /tracking avec auth JWT.
// Le backend auto-joint le pro à la room `professional_<userId>` dès la
// connexion → il reçoit `new_order` sans connaître l'orderId à l'avance.
//
// Usage :
//   final svc = ref.read(proSocketServiceProvider);
//   svc.connect(token);
//   svc.newOrders.listen((_) => ref.invalidate(liveOrdersProvider));
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/app_constants.dart';

class ProSocketService {
  io.Socket? _socket;
  final _player = AudioPlayer();

  final _newOrderCtrl    = StreamController<Map<String, dynamic>>.broadcast();
  final _orderStatusCtrl = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get newOrders    => _newOrderCtrl.stream;
  Stream<Map<String, dynamic>> get orderStatuses => _orderStatusCtrl.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (isConnected) return;
    _socket = io.io(
      '${AppConstants.wsUrl}/tracking',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {});

    _socket!.on('new_order', (data) {
      final payload = Map<String, dynamic>.from(data as Map);
      _newOrderCtrl.add(payload);
      _playAlert();
    });

    _socket!.on('order_status', (data) {
      _orderStatusCtrl.add(Map<String, dynamic>.from(data as Map));
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  Future<void> _playAlert() async {
    try {
      await _player.play(AssetSource('sounds/new_order.mp3'));
    } catch (_) {
      // Son non bloquant — si l'asset manque ou device en silencieux, on ignore.
    }
  }

  void dispose() {
    _socket?.dispose();
    _newOrderCtrl.close();
    _orderStatusCtrl.close();
    _player.dispose();
  }
}

final proSocketServiceProvider = Provider<ProSocketService>((ref) {
  final svc = ProSocketService();
  ref.onDispose(svc.dispose);
  return svc;
});
