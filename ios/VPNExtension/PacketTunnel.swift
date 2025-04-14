import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
  override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
      // Запускается при подключении VPN
      completionHandler(nil)
  }

  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
      // Вызывается при отключении
      completionHandler()
  }
}
