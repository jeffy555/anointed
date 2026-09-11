import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Coarse online/offline signal.
///
/// Used for the `connectivity` analytics property (analytics-spec §3/§6), the
/// M-17 offline state, and the practice-pack sync trigger in design-spec §19.
/// It reports link availability, not reachability, so API calls still handle
/// their own failures — this only decides which *state* to show first.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _online = true;
  bool get isOnline => _online;

  /// `online` | `offline`, for analytics event properties.
  String get label => _online ? 'online' : 'offline';

  Future<void> start() async {
    _apply(await _connectivity.checkConnectivity());
    _subscription = _connectivity.onConnectivityChanged.listen(_apply);
  }

  /// Fires whenever the device transitions from offline to online. The analytics
  /// flush and the content-pack sync both hook this.
  final List<void Function()> _onReconnect = <void Function()>[];

  void addReconnectListener(void Function() listener) => _onReconnect.add(listener);

  void _apply(List<ConnectivityResult> results) {
    final bool next = results.any((ConnectivityResult result) =>
        result != ConnectivityResult.none);
    if (next == _online) return;
    _online = next;
    notifyListeners();
    if (next) {
      for (final void Function() listener in List<void Function()>.of(_onReconnect)) {
        listener();
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
