import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class AvailableDevicesTab extends StatefulWidget {
  final Function(BluetoothDevice) onDeviceConnected;

  const AvailableDevicesTab({super.key, required this.onDeviceConnected});

  @override
  State<AvailableDevicesTab> createState() => _AvailableDevicesTabState();
}

class _AvailableDevicesTabState extends State<AvailableDevicesTab> {
  static List<BluetoothDevice> scanResults = [];
  bool isScanning = false;

  Future<void> _startScan() async {
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    // listen to scan results
    // Note: `onScanResults` clears the results between scans. You should use
    //  `scanResults` if you want the current scan results *or* the results from the previous scan.
    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      setState(() {
        if (results.isNotEmpty) {
          ScanResult r = results.last; // the most recently found device
          print(
            '${r.device.remoteId}: "${r.advertisementData.advName}" found!',
          );
          scanResults.add(r.device);
        }
      });
    }, onError: (e) => print(e));

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);
    // Wait for Bluetooth enabled & permission granted
    // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;
    // Start scanning w/ timeout
    // Optional: use `stopScan()` as an alternative to timeout
    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: 15),
      androidUsesFineLocation: true,
    );
    // wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;

    setState(() {
      isScanning = false;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    // listen for disconnection
    var subscription = device.connectionState.listen((
      BluetoothConnectionState state,
    ) async {
      if (state == BluetoothConnectionState.disconnected) {
        // 1. typically, start a periodic timer that tries to
        //    reconnect, or just call connect() again right now
        // 2. you must always re-discover services after disconnection!
        print(
          "${device.disconnectReason?.code} ${device.disconnectReason?.description}",
        );
      }
    });

    // cleanup: cancel subscription when disconnected
    //   - [delayed] This option is only meant for `connectionState` subscriptions.
    //     When `true`, we cancel after a small delay. This ensures the `connectionState`
    //     listener receives the `disconnected` event.
    //   - [next] if true, the the stream will be canceled only on the *next* disconnection,
    //     not the current disconnection. This is useful if you setup your subscriptions
    //     before you connect.
    device.cancelWhenDisconnected(subscription, delayed: true, next: true);

    // Connect to the device
    await device.connect();
    widget.onDeviceConnected(device);
    // cancel to prevent duplicate listeners
    subscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: isScanning ? null : _startScan,
            child: const Text('SCAN'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: scanResults.length,
            itemBuilder: (context, index) {
              BluetoothDevice result = scanResults[index];
              return ListTile(
                title: Text(
                  result.platformName.isEmpty
                      ? 'Unknown Device'
                      : result.platformName,
                ),
                subtitle: Text(result.remoteId.toString()),
                trailing: ElevatedButton(
                  onPressed: () => _connectToDevice(result),
                  child: const Text('Подключить'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
