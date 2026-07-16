import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/supabase_service.dart';

class TruckTrackingScreen extends StatefulWidget {
  final bool isAdmin;
  const TruckTrackingScreen({super.key, required this.isAdmin});

  @override
  State<TruckTrackingScreen> createState() => _TruckTrackingScreenState();
}

class _TruckTrackingScreenState extends State<TruckTrackingScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final MapController _mapController = MapController();

  // موقع افتراضي مسبق للتمركز (شمال المغرب / الناظور كنقطة انطلاق ممتازة للنقل الدولي)
  static const LatLng _initialCenter = LatLng(35.1686, -2.9335);

  // جلب دفق حي ومستمر لمواقع جميع الشاحنات من قاعدة البيانات
  Stream<List<Map<String, dynamic>>> _getTrucksStream() {
    return _supabaseService.supabase
        .from('trucks')
        .stream(primaryKey: ['id'])
        .order('id');
  }

  // دالة تحريك الكاميرا بسلاسة وتحديد موقع الشاحنة المحددة
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

          // تصفية الشاحنات التي تمتلك إحداثيات صالحة
          final trucksWithLocation = trucks.where((truck) {
            final lat = (truck['current_latitude'] as num?)?.toDouble();
            final lng = (truck['current_longitude'] as num?)?.toDouble();
            return lat != null && lng != null && lat != 0.0 && lng != 0.0;
          }).toList();

          // إنشاء مصفوفة علامات الشاحنات (Markers) على الخريطة
          List<Marker> markers = trucksWithLocation.map((truck) {
            final double lat = (truck['current_latitude'] as num).toDouble();
            final double lng = (truck['current_longitude'] as num).toDouble();
            final String driverName = truck['driver_name']?.toString() ?? 'سائق';
            final String truckNum = truck['plate']?.toString() ?? truck['plate_number']?.toString() ?? 'شاحنة';

            return Marker(
              point: LatLng(lat, lng),
              child: SizedBox(
                width: 80,
                height: 80,
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('السائق: $driverName | الشاحنة: $truckNum'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
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
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
              ),
            );
          }).toList();

          return Stack(
            children: [
              // 🗺️ عنصر الخريطة التفاعلي الرئيسي
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
                  MarkerLayer(markers: markers),
                ],
              ),

              // 🎯 زر العودة السريعة للمركز الرئيسي للشركة
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

              // 🚛 لوحة سفلية أفقية لعرض الشاحنات النشطة والتحليق نحوها
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

                            return GestureDetector(
                              onTap: () => _focusOnTruck(lat, lng),
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
                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.teal.withValues(alpha: 0.15),
                                      child: const Icon(Icons.navigation_rounded, color: Colors.teal),
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
