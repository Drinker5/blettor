import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'available_devices_tab.dart';
import 'connected_devices_tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Device Controller',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<BluetoothDevice> connectedDevices = [];
  Map<String, String> deviceStatuses = {};

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _loadConnectedDevices();
  }

  Future<void> _initBluetooth() async {
    // first, check if bluetooth is supported by your hardware
    // Note: The platform is initialized on the first call to any FlutterBluePlus method.
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // handle bluetooth on & off
    // note: for iOS the initial state is typically BluetoothAdapterState.unknown
    // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
    var subscription = FlutterBluePlus.adapterState.listen((
      BluetoothAdapterState state,
    ) {
      print(state);
      if (state == BluetoothAdapterState.on) {
        // usually start scanning, connecting, etc
      } else {
        // show an error to the user, etc
      }
    });

    // turn on bluetooth ourself if we can
    // for iOS, the user controls bluetooth enable/disable
    if (!kIsWeb && Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    // cancel to prevent duplicate listeners
    subscription.cancel();
  }

  Future<void> _loadConnectedDevices() async {
    List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;
    setState(() {
      connectedDevices = devices;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BLE Device Controller'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Доступные'),
              Tab(text: 'Играют'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AvailableDevicesTab(
              onDeviceConnected: (device) {
                setState(() {
                  if (!connectedDevices.contains(device)) {
                    connectedDevices.add(device);
                    print('Added: $device');
                  }
                });
              },
            ),
            ConnectedDevicesTab(
              devices: connectedDevices,
              onDeviceDisconnected: (device) {
                setState(() {
                  connectedDevices.remove(device);
                  deviceStatuses.remove(device.remoteId.toString());
                });
              },
              deviceStatuses: deviceStatuses,
              onStatusUpdated: (deviceId, status) {
                setState(() {
                  deviceStatuses[deviceId] = status;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
