import 'dart:async';

abstract class NetworkDiscovery {
  Future<String?> discoverPeerIp();
  void dispose();
}

class LocalhostDiscovery implements NetworkDiscovery {
  @override
  Future<String?> discoverPeerIp() async => '127.0.0.1';

  @override
  void dispose() {}
}
