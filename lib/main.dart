import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map App with Geoapify',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePoints = [];

  // Thay bằng API Key thật của bạn từ Geoapify
  final String apiKey = 'nhan_cho_duc';

  // Hàm geocoding: Chuyển địa chỉ thành tọa độ
  Future<LatLng?> geocodeAddress(String address) async {
    // final url = Uri.parse(
    //   'https://api.geoapify.com/v1/geocode/search?text=${Uri.encodeComponent(address)}&apiKey=$apiKey',
    // );
    final url = Uri.parse(
    'https://api.geoapify.com/v1/geocode/search'
    '?text=${Uri.encodeComponent(address)}'
    '&filter=countrycode:vn' 
    '&lang=vi'
    '&apiKey=$apiKey',
  );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final coords = data['features'][0]['properties'];
          return LatLng(coords['lat'], coords['lon']);
        }
      }
      return null;
    } catch (e) {
      print('Geocoding error: $e');
      return null;
    }
  }

  // Hàm lấy route: Tính đường đi giữa hai điểm
  Future<void> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://api.geoapify.com/v1/routing?waypoints=${start.latitude},${start.longitude}|${end.latitude},${end.longitude}&mode=drive&apiKey=$apiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final route = data['features'][0]['geometry']['coordinates'][0];
          List<LatLng> points = [];
          for (var coord in route) {
            points.add(LatLng(coord[1], coord[0])); // Geoapify trả [lon, lat]
          }
          setState(() {
            _routePoints = points;
          });
          // Di chuyển bản đồ để fit route
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(start, end),
              padding: const EdgeInsets.all(
                50.0,
              ), // Padding để markers không sát mép
            ),
          );
        }
      } else {
        print('Routing API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Routing error: $e');
    }
  }

  // Hàm xử lý khi nhấn button
  Future<void> calculateRoute() async {
    final startAddress = _startController.text.trim();
    final endAddress = _endController.text.trim();

    if (startAddress.isEmpty || endAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa điểm đầu và cuối')),
      );
      return;
    }

    final start = await geocodeAddress(startAddress);
    final end = await geocodeAddress(endAddress);

    if (start != null && end != null) {
      setState(() {
        _startPoint = start;
        _endPoint = end;
        _routePoints = []; // Xóa route cũ trước khi tính mới
      });
      await getRoute(start, end);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy một hoặc cả hai địa điểm'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bản Đồ Với Geoapify')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _startController,
              decoration: const InputDecoration(
                labelText: 'Địa điểm đầu (ví dụ: Hanoi, Vietnam)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _endController,
              decoration: const InputDecoration(
                labelText: 'Địa điểm cuối (ví dụ: Ho Chi Minh City, Vietnam)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: calculateRoute,
            child: const Text('Hiển thị đường đi'),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(21.0285, 105.8542), // Hà Nội
                initialZoom: 5.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                minZoom: 3.0,
                maxZoom: 18.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey=$apiKey',
                  userAgentPackageName: 'com.example.app',
                  tileProvider: NetworkTileProvider(),
                ),
                if (_startPoint != null && _endPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _startPoint!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                      Marker(
                        point: _endPoint!,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.blue,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 4.0,
                        color: Colors.green,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}
