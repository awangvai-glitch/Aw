import 'package:flutter/material.dart';
import 'package:openvpn_flutter/openvpn_flutter.dart';

class ConnectButton extends StatelessWidget {
  final VPNStage vpnStage;
  final VoidCallback onPressed;

  const ConnectButton({
    super.key,
    required this.vpnStage,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    String text = "CONNECT";
    Color color = Colors.blue;

    switch (vpnStage) {
      case VPNStage.connected:
        text = "DISCONNECT";
        color = Colors.red;
        break;
      case VPNStage.connecting:
        text = "CONNECTING...";
        color = Colors.orange;
        break;
      case VPNStage.disconnecting:
        text = "DISCONNECTING...";
        color = Colors.orange;
        break;
      case VPNStage.denied:
        text = "DENIED";
        color = Colors.red;
        break;
      case VPNStage.error:
        text = "ERROR";
        color = Colors.red;
        break;
      default:
        text = "CONNECT";
        color = Colors.blue;
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        textStyle: const TextStyle(fontSize: 18),
      ),
      child: Text(text),
    );
  }
}
