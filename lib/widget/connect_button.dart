import 'package:flutter/material.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

class ConnectButton extends StatelessWidget {
  final VPNStage? vpnStage;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  const ConnectButton({
    Key? key,
    required this.vpnStage,
    this.onConnect,
    this.onDisconnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (vpnStage == VPNStage.disconnected) {
          onConnect?.call();
        } else if (vpnStage == VPNStage.connected) {
          onDisconnect?.call();
        }
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getButtonColor(),
          boxShadow: [
            BoxShadow(
              color: _getButtonColor().withOpacity(0.5),
              spreadRadius: 5,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: _getButtonChild(),
        ),
      ),
    );
  }

  Color _getButtonColor() {
    switch (vpnStage) {
      case VPNStage.connected:
        return Colors.red;
      case VPNStage.connecting:
        return Colors.grey;
      case VPNStage.disconnected:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _getButtonChild() {
    switch (vpnStage) {
      case VPNStage.connected:
        return const Icon(
          Icons.power_settings_new,
          color: Colors.white,
          size: 80,
        );
      case VPNStage.connecting:
        return const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        );
      case VPNStage.disconnected:
        return const Icon(
          Icons.power_settings_new,
          color: Colors.white,
          size: 80,
        );
      default:
        return const Icon(
          Icons.power_settings_new,
          color: Colors.white,
          size: 80,
        );
    }
  }
}
