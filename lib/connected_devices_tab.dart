import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

class ConnectedDevicesTab extends StatefulWidget {
  final List<BluetoothDevice> devices;
  final Function(BluetoothDevice) onDeviceDisconnected;
  final Map<String, String> deviceStatuses;
  final Function(String, String) onStatusUpdated;

  const ConnectedDevicesTab({
    super.key,
    required this.devices,
    required this.onDeviceDisconnected,
    required this.deviceStatuses,
    required this.onStatusUpdated,
  });

  @override
  State<ConnectedDevicesTab> createState() => _ConnectedDevicesTabState();
}

class _ConnectedDevicesTabState extends State<ConnectedDevicesTab> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  void _setupNotifications() async {
    for (BluetoothDevice device in widget.devices) {
      await _subscribeToDeviceNotifications(device);
    }
  }

  Future<void> _subscribeToDeviceNotifications(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    
    for (BluetoothService service in services) {
      if (service.serviceUuid.toString().toUpperCase() == '0000A002-0000-1000-8000-00805F9B34FB') {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.characteristicUuid.toString().toUpperCase() == '0000C300-0000-1000-8000-00805F9B34FB') {
            await characteristic.setNotifyValue(true);
            characteristic.onValueReceived.listen((value) {
              if (value.isNotEmpty) {
                String status = String.fromCharCodes(value).trim();
                widget.onStatusUpdated(device.remoteId.toString(), status);
              }
            });
          }
        }
      }
    }
  }

  Future<void> _writeToCharacteristic(
    BluetoothDevice device, 
    String characteristicUuid, 
    String value
  ) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.serviceUuid.toString().toUpperCase() == '0000A003-0000-1000-8000-00805F9B34FB') {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.characteristicUuid.toString().toUpperCase() == characteristicUuid) {
              await characteristic.write(utf8.encode(value));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error writing to characteristic: $e');
    }
  }

  Future<void> _disconnectDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      widget.onDeviceDisconnected(device);
    } catch (e) {
      debugPrint('Error disconnecting device: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.devices.length,
      itemBuilder: (context, index) {
        BluetoothDevice device = widget.devices[index];
        String deviceId = device.remoteId.toString();
        String status = widget.deviceStatuses[deviceId] ?? '----';
        
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${index + 1}'),
                    Text(device.platformName.isEmpty ? 'Unknown' : device.platformName),
                    Text(deviceId),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: status),
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Статус',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _writeToCharacteristic(
                        device, 
                        '0000C400-0000-1000-8000-00805F9B34FB', 
                        '1'
                      ),
                      child: const Text('Свет'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _writeToCharacteristic(
                        device, 
                        '0000C401-0000-1000-8000-00805F9B34FB', 
                        '1'
                      ),
                      child: const Text('Звук'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () => _writeToCharacteristic(
                        device, 
                        '0000C402-0000-1000-8000-00805F9B34FB', 
                        '1'
                      ),
                      child: const Text('Свет и звук'),
                    ),
                    ElevatedButton(
                      onPressed: () => _disconnectDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Отключить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}