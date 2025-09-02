import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QRScannerScreen extends StatefulWidget {
  final String accessToken;
  final String refreshToken;

  const QRScannerScreen({
    super.key,
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final TextEditingController _qrInputController = TextEditingController();
  List<dynamic> availableEquipment = [];
  Map<String, dynamic>? scannedEquipment;
  bool isLoading = false;
  bool isLoadingEquipment = true;
  String _errorMessage = '';

  final String baseUrl = 'http://10.0.2.2:8000/api';

  @override
  void initState() {
    super.initState();
    _loadAvailableEquipment();
  }

  Future<void> _loadAvailableEquipment() async {
    setState(() {
      isLoadingEquipment = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/equipment/'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final equipmentData = json.decode(response.body);
        setState(() {
          availableEquipment = equipmentData is List ? equipmentData : [];
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load equipment. Status: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading equipment: $e';
      });
    } finally {
      setState(() {
        isLoadingEquipment = false;
      });
    }
  }

  Future<void> _scanQRCode(String qrCode) async {
    if (qrCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a QR code or Device ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = '';
      scannedEquipment = null;
    });

    try {
      // Look for equipment by QR code or device_id
      final equipment = availableEquipment.firstWhere(
            (item) =>
        item['qr_code'] == qrCode ||
            item['device_id'] == qrCode ||
            item['id'] == qrCode,
        orElse: () => null,
      );

      if (equipment != null) {
        setState(() {
          scannedEquipment = equipment;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Equipment "${equipment['name']}" found!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'No equipment found with QR code: $qrCode';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Equipment not found: $qrCode'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error scanning QR code: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _clearScan() {
    setState(() {
      scannedEquipment = null;
      _errorMessage = '';
      _qrInputController.clear();
    });
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      case 'maintenance':
        return Colors.orange;
      case 'error':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getRoomName(String? roomId) {
    if (roomId == null) return 'Unassigned';
    // In a real app, you'd fetch room data, but for simulation we'll show the ID
    return 'Room ID: $roomId';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (scannedEquipment != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearScan,
              tooltip: 'Clear Scan',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simulated Camera View
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Simulated QR Scanner',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use manual input or select from list below',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Scanning overlay
                  if (isLoading)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Manual QR Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manual QR Code Input',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _qrInputController,
                      decoration: const InputDecoration(
                        labelText: 'Enter QR Code or Device ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code),
                        hintText: 'e.g., ESP32_001, QR_12345',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : () => _scanQRCode(_qrInputController.text.trim()),
                        icon: isLoading
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.search),
                        label: Text(isLoading ? 'Scanning...' : 'Scan QR Code'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Available Equipment for Testing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Equipment (For Testing)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap any equipment to simulate scanning its QR code',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    if (isLoadingEquipment)
                      const Center(child: CircularProgressIndicator())
                    else if (availableEquipment.isEmpty)
                      const Center(
                        child: Text(
                          'No equipment available.\nAdd some equipment first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...availableEquipment.take(5).map((equipment) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(equipment['status']).withOpacity(0.2),
                            child: Icon(
                              Icons.qr_code,
                              color: _getStatusColor(equipment['status']),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            equipment['name'] ?? 'Unknown Equipment',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Device ID: ${equipment['device_id'] ?? 'N/A'}\n'
                                'QR Code: ${equipment['qr_code'] ?? 'N/A'}',
                          ),
                          trailing: const Icon(Icons.touch_app, color: Colors.blue),
                          onTap: () {
                            final qrCode = equipment['qr_code'] ?? equipment['device_id'] ?? equipment['id'];
                            _qrInputController.text = qrCode;
                            _scanQRCode(qrCode);
                          },
                          isThreeLine: true,
                        ),
                      )).toList(),

                    if (availableEquipment.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... and ${availableEquipment.length - 5} more equipment',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Error Message
            if (_errorMessage.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Scanned Equipment Details
            if (scannedEquipment != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          const Text(
                            'Equipment Found!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Equipment Details
                      _buildDetailRow('Name', scannedEquipment!['name'] ?? 'Unknown'),
                      _buildDetailRow('Type', scannedEquipment!['type'] ?? 'Unknown'),
                      _buildDetailRow('Device ID', scannedEquipment!['device_id'] ?? 'N/A'),
                      _buildDetailRow('QR Code', scannedEquipment!['qr_code'] ?? 'N/A'),
                      _buildDetailRow('Room', _getRoomName(scannedEquipment!['room']?.toString())),

                      // Status with color indicator
                      Row(
                        children: [
                          const SizedBox(width: 100, child: Text('Status:', style: TextStyle(fontWeight: FontWeight.w500))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(scannedEquipment!['status']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(scannedEquipment!['status']),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  scannedEquipment!['status']?.toUpperCase() ?? 'UNKNOWN',
                                  style: TextStyle(
                                    color: _getStatusColor(scannedEquipment!['status']),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Navigate to equipment details or management
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Equipment details feature coming soon!'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.info),
                              label: const Text('View Details'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _clearScan,
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('Scan Again'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _qrInputController.dispose();
    super.dispose();
  }
}