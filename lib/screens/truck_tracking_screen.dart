import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TruckTrackingScreen extends StatefulWidget {
  final bool isAdmin;
  const TruckTrackingScreen({super.key, required this.isAdmin});

  @override
  State<TruckTrackingScreen> createState() => _TruckTrackingScreenState();
}

class _TruckTrackingScreenState extends State<TruckTrackingScreen> {
  final MapController _mapController = MapController();

  static const LatLng _initialCenter = LatLng(35.1686, -2.9335);

  int? _selectedTruckId;

  Stream<List<Map<String, dynamic>>> _getTrucksStream() {
    return Supabase.instance.client
        .from('trucks')
        .stream(primaryKey: ['id'])
        .order('id');
  }

  Future<List<LatLng>> _getPolyline(int truckId) async {
    final response = await Supabase.instance.client
        .from('truck_locations')
        .select()
        .eq('truck_id', truckId)
        .order('created_at', ascending: true)
        .limit(100);
    final history = List<Map<String, dynamic>>.from(response);
    return history
        .where((p) {
          final lat = (p['latitude'] as num?)?.toDouble();
          final lng = (p['longitude'] as num?)?.toDouble();
          return lat != null && lng != null;
        })
        .map((p) => LatLng(
          (p['latitude'] as num).toDouble(),
          (p['longitude'] as num).toDouble(),
        ))
        .toList();
  }

  void _focusOnTruck(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 12.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getTrucksStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('خطأ في جلب نظام التتبع: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final trucks = snapshot.data ?? [];

          final trucksWithLocation = trucks.where((truck) {
            final lat = (truck['current_latitude'] as num?)?.toDouble();
            final lng = (truck['current_longitude'] as num?)?.toDouble();
            return lat != null && lng != null && lat != 0.0 && lng != 0.0;
          }).toList();

          List<Marker> markers = trucksWithLocation.map((truck) {
            final double lat = (truck['current_latitude'] as num).toDouble();
            final double lng = (truck['current_longitude'] as num).toDouble();
            final String truckNum = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? 'شاحنة';
            final int? truckId = truck['id'] as int?;

            return Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedTruckId = truckId);
                  _focusOnTruck(lat, lng);
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : Colors.blueGrey[900],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        truckNum,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.deepOrange,
                      size: 34,
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: 6.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.international_transport_app',
                  ),
                  if (_selectedTruckId != null)
                    FutureBuilder<List<LatLng>>(
                      future: _getPolyline(_selectedTruckId!),
                      builder: (context, polylineSnapshot) {
                        if (!polylineSnapshot.hasData) return const SizedBox.shrink();
                        final points = polylineSnapshot.data!;
                        if (points.length < 2) return const SizedBox.shrink();
                        return PolylineLayer(
                          polylines: [
                            Polyline(
                              points: points,
                              color: Colors.blueAccent,
                              strokeWidth: 4.0,
                            ),
                          ],
                        );
                      },
                    ),
                  MarkerLayer(markers: markers),
                ],
              ),

              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'center_btn',
                  backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  onPressed: () => _mapController.move(_initialCenter, 6.0),
                  child: const Icon(Icons.my_location_rounded),
                ),
              ),

              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: SizedBox(
                  height: 90,
                  child: trucksWithLocation.isEmpty
                      ? Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('لا توجد شاحنات تبث موقعها حالياً على الطريق.'),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: trucksWithLocation.length,
                          itemBuilder: (context, index) {
                            final truck = trucksWithLocation[index];
                            final double lat = (truck['current_latitude'] as num).toDouble();
                            final double lng = (truck['current_longitude'] as num).toDouble();
                            final int? truckId = truck['id'] as int?;
                            final bool isSelected = _selectedTruckId == truckId;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedTruckId = truckId);
                                _focusOnTruck(lat, lng);
                              },
                              child: Container(
                                width: 180,
                                margin: const EdgeInsets.only(left: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blueAccent
                                        : Colors.teal.withValues(alpha: 0.3),
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: (isSelected ? Colors.blueAccent : Colors.teal).withValues(alpha: 0.15),
                                      child: Icon(
                                        Icons.navigation_rounded,
                                        color: isSelected ? Colors.blueAccent : Colors.teal,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            truck['driver_name']?.toString() ?? 'سائق مجهول',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'شاحنة: ${truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? '-'}',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
