import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/trip_repository.dart';
import '../services/fleet_service.dart';
import '../services/advance_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/location_service.dart';
import '../l10n/app_localizations.dart';
import '../models/trip_order.dart';
import '../cubits/trips_cubit.dart';
import '../screens/truck_tracking_screen.dart';

// ignore_for_file: use_build_context_synchronously

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final FleetService _fleetService = FleetService();
  final AdvanceService _advanceService = AdvanceService();
  final TripRepository _tripRepository = TripRepository(Supabase.instance.client);
  final NotificationService _notificationService = NotificationService();
  final LocationService _locationService = LocationService();

  List<Map<String, dynamic>> _currentTrips = [];
  List<Map<String, dynamic>> _upcomingTrips = [];
  int? _selectedDriverId;
  String? _driverName;
  bool _isLoading = true;
  bool _isTracking = false;
  bool _isDriverMode = true;
  StreamSubscription? _locationStreamSubscription;
  RealtimeChannel? _subscription;
  int? _lastNotifiedAdvanceId;

  Position? _lastPosition;
  double _totalDistanceMeters = 0.0;
  double _currentSpeedKmh = 0.0;
  String _accuracyLabel = '--';

  @override
  void initState() {
    super.initState();
    _loadDriverAndTrips();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _locationStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverAndTrips() async {
    final drivers = await _fleetService.getDrivers();
    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    int? myDriverId;
    String? myName;

    if (authUserId != null) {
      for (final d in drivers) {
        if (d['user_id']?.toString() == authUserId.toString()) {
          myDriverId = d['id'] as int?;
          myName = d['name']?.toString();
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _selectedDriverId = myDriverId;
        _driverName = myName;
      });
    }
    await _loadTrips();
    await _checkForNewAdvances();
    _subscribeToTripUpdates();
  }

  Future<void> _loadTrips() async {
    if (_selectedDriverId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final allTrips = await _advanceService.getTripOrdersByDriver(_selectedDriverId!);
      if (!mounted) return;

      final now = DateTime.now();
      final current = <Map<String, dynamic>>[];
      final upcoming = <Map<String, dynamic>>[];

      for (final trip in allTrips) {
        final status = (trip['status'] ?? '').toString().toLowerCase();
        final departureDate = trip['departure_date'] != null
            ? DateTime.tryParse(trip['departure_date'].toString())
            : null;

        if (status == 'active' || status == 'en_route') {
          current.add(trip);
        } else if (departureDate != null && departureDate.isAfter(now) && status != 'completed') {
          upcoming.add(trip);
        }
      }

      upcoming.sort((a, b) {
        final da = DateTime.tryParse(a['departure_date']?.toString() ?? '');
        final db = DateTime.tryParse(b['departure_date']?.toString() ?? '');
        return da?.compareTo(db ?? DateTime.now()) ?? 0;
      });

      setState(() {
        _currentTrips = current;
        _upcomingTrips = upcoming;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkForNewAdvances() async {
    if (_selectedDriverId == null) return;
    try {
      final advances = await _advanceService.getAdvancesByDriver(_selectedDriverId!);
      if (!mounted) return;

      final latest = advances.isNotEmpty ? advances.first : null;
      final latestId = latest?['id'] as int?;
      final amount = (latest?['amount_given'] as num?)?.toDouble() ?? 0.0;

      if (latestId != null &&
          latestId != _lastNotifiedAdvanceId &&
          amount > 0) {
        setState(() => _lastNotifiedAdvanceId = latestId);
        await _notificationService.notifyNewAdvanceDelivered(
          _driverName ?? 'السائق',
          amount,
          latestId,
        );
      }
    } catch (e) {
      debugPrint('Error checking new advances: $e');
    }
  }

  void _subscribeToTripUpdates() {
    final driverId = _selectedDriverId;
    if (driverId == null) return;

    _subscription?.unsubscribe();

    _subscription = Supabase.instance.client
        .channel('driver_trips_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trip_orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId.toString(),
          ),
          callback: (payload) {
            if (mounted) {
              final newTrip = TripOrder.fromMap(payload.newRecord);
              context.read<TripsCubit>().updateTripInList(newTrip);
              _loadTrips();

              if (newTrip.status == 'en_route') {
                _notificationService.showTripStartedNotification();
              } else if (newTrip.status == 'arrived') {
                _notificationService.showTripArrivedNotification();
              } else if (newTrip.status == 'completed') {
                _notificationService.showTripEndedNotification();
              }
            }
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            debugPrint('Error in subscription: $error');
          }
        });
  }

  Future<void> _startTrip(int tripId, String route) async {
    try {
      await _tripRepository.updateTripStatus(tripId, 'en_route');
      await AudioService().playTripStarted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('تم بدء الرحلة بنجاح')),
            backgroundColor: Colors.green,
          ),
        );
      }
      _activateGpsTracking(tripId, route);
      _loadTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في البدء: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _activateGpsTracking(int tripId, String route) {
    _stopGpsTracking();
    setState(() {
      _isTracking = true;
      _totalDistanceMeters = 0.0;
      _currentSpeedKmh = 0.0;
      _accuracyLabel = '--';
    });

    _locationStreamSubscription = _locationService.getPositionStream().listen((position) {
      final previous = _lastPosition;
      if (previous != null) {
        final distance = Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          position.latitude,
          position.longitude,
        );
        setState(() {
          _totalDistanceMeters += distance;
          _currentSpeedKmh = (position.speed * 3.6).abs();
          _accuracyLabel = _accuracyFromMeters(position.accuracy);
        });
      } else {
        setState(() {
          _currentSpeedKmh = (position.speed * 3.6).abs();
          _accuracyLabel = _accuracyFromMeters(position.accuracy);
        });
      }

      setState(() => _lastPosition = position);

      _fleetService.updateTruckLocation(
        _selectedDriverId ?? 0,
        position.latitude,
        position.longitude,
      );
      _fleetService.recordTruckLocation(
        _selectedDriverId ?? 0,
        position.latitude,
        position.longitude,
      );
    });
  }

  Future<void> _refreshLocationOnce() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) return;

    setState(() {
      _lastPosition = position;
      _currentSpeedKmh = (position.speed * 3.6).abs();
      _accuracyLabel = _accuracyFromMeters(position.accuracy);
    });

    await _fleetService.updateTruckLocation(
      _selectedDriverId ?? 0,
      position.latitude,
      position.longitude,
    );
    await _fleetService.recordTruckLocation(
      _selectedDriverId ?? 0,
      position.latitude,
      position.longitude,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('تم تحديث الموقع بنجاح')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _stopGpsTracking() {
    _locationStreamSubscription?.cancel();
    _locationStreamSubscription = null;
    setState(() {
      _isTracking = false;
      _lastPosition = null;
      _currentSpeedKmh = 0.0;
      _accuracyLabel = '--';
    });
  }

  Future<void> _endTrip(int tripId, String route) async {
    try {
      await _tripRepository.updateTripStatus(tripId, 'completed');
      await AudioService().playTripEnded();
      _stopGpsTracking();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('تم إنهاء الرحلة بنجاح')),
            backgroundColor: Colors.blue,
          ),
        );
      }

      await _notificationService.notifySecretaryTripEnded(
        _driverName ?? 'السائق',
        route,
        tripId,
      );

      _loadTrips();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في التسجيل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRouteOnMap(Map<String, dynamic> trip) {
    final route = trip['route']?.toString() ?? '';
    final truckPlate = trip['truck_plate']?.toString() ?? trip['plate']?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TruckTrackingScreen(isAdmin: false),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('المسار: $route - الشاحنة: $truckPlate'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _accuracyFromMeters(double accuracy) {
    if (accuracy <= 5) return 'دقيق جداً';
    if (accuracy <= 15) return 'دقيق متوسط';
    return 'دقيق منخفض';
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} كم';
    }
    return '${meters.toStringAsFixed(0)} م';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('رحلاتي ومتابعتي')),
        actions: [
          if (_isTracking)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('تتبع'),
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(_isDriverMode ? Icons.directions_car : Icons.visibility),
            onPressed: () => setState(() => _isDriverMode = !_isDriverMode),
            tooltip: _isDriverMode ? 'وضع القيادة (مبسط)' : 'وضع العرض العادي',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_currentTrips.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.12),
                    Colors.blue.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping, color: Colors.blue, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('الرحلة المنتزلة'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isTracking)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.tr('تتبع'),
                            style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._currentTrips.map((trip) => _buildTodayTripCard(trip, isDark)),
                ],
              ),
            ),
          ],

          if (_upcomingTrips.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                context.tr('الرحلات القادمة'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ..._upcomingTrips.map((trip) => _buildUpcomingTripCard(trip)),
          ],

          if (_currentTrips.isEmpty && _upcomingTrips.isEmpty && !_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_rounded, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('لا توجد رحلات حالياً'),
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildTodayTripCard(Map<String, dynamic> trip, bool isDark) {
    final route = trip['route']?.toString() ?? '';
    final direction = trip['direction']?.toString() ?? 'outbound';
    final directionLabel = direction == 'return' ? context.tr('عودة') : context.tr('ذهاب');
    final departureDate = trip['departure_date']?.toString() ?? '';
    final clientName = trip['client_name']?.toString() ?? '';
    final truckPlate = trip['truck_plate']?.toString() ?? trip['plate']?.toString() ?? '';
    final status = (trip['status'] ?? '').toString().toLowerCase();
    final tripId = trip['id'] as int?;
    final isSmall = MediaQuery.of(context).size.width < 400;

    final isDriverMode = _isDriverMode;
    final titleFontSize = isDriverMode ? 22.0 : (isSmall ? 15.0 : 17.0);
    final cardPadding = isDriverMode ? 20.0 : (isSmall ? 12.0 : 16.0);
    final buttonHeight = isDriverMode ? 70.0 : (isSmall ? 52.0 : 50.0);
    final statusFontSize = isDriverMode ? 16.0 : (isSmall ? 11.0 : 12.0);
    final buttonFontSize = isDriverMode ? 20.0 : (isSmall ? 15.0 : 16.0);
    final buttonIconSize = isDriverMode ? 32.0 : (isSmall ? 20.0 : 22.0);

    return Card(
      margin: EdgeInsets.symmetric(vertical: isDriverMode ? 12 : (isSmall ? 6 : 8)),
      elevation: isDriverMode ? 8 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDriverMode ? 20 : (isSmall ? 14 : 16))),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, color: Colors.blue, size: isDriverMode ? 30 : (isSmall ? 20 : 22)),
                SizedBox(width: isDriverMode ? 12 : (isSmall ? 6 : 8)),
                Expanded(
                  child: Text(
                    route,
                    style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isDriverMode ? 14 : (isSmall ? 8 : 10), vertical: isDriverMode ? 6 : (isSmall ? 3 : 4)),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(isDriverMode ? 12 : (isSmall ? 7 : 8)),
                  ),
                  child: Text(
                    status == 'en_route' ? context.tr('الرحلة المنتزلة') : status.toUpperCase(),
                    style: TextStyle(fontSize: statusFontSize, color: _statusColor(status), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: isDriverMode ? 16 : (isSmall ? 10 : 12)),
            if (!isDriverMode) ...[
              Row(
                children: [
                  Expanded(child: _tripDetailRow(Icons.person, context.tr('الزبون'), clientName, isSmall: isSmall)),
                  Expanded(child: _tripDetailRow(Icons.local_shipping, context.tr('الشاحنة'), truckPlate, isSmall: isSmall)),
                ],
              ),
              SizedBox(height: isSmall ? 6 : 8),
              Row(
                children: [
                  Expanded(child: _tripDetailRow(Icons.arrow_forward, context.tr('الجهة'), directionLabel, isSmall: isSmall)),
                  Expanded(child: _tripDetailRow(Icons.calendar_today, context.tr('التاريخ'), departureDate, isSmall: isSmall)),
                ],
              ),
            ],
            if (_isTracking && !isDriverMode) ...[
              SizedBox(height: isSmall ? 8 : 10),
              Wrap(
                spacing: isSmall ? 8 : 12,
                runSpacing: isSmall ? 6 : 8,
                children: [
                  _gpsChip(Icons.gps_fixed, context.tr('الدقة'), _accuracyLabel, Colors.green, isSmall: isSmall),
                  _gpsChip(Icons.speed, context.tr('السرعة'), '${_currentSpeedKmh.toStringAsFixed(0)} كم/س', Colors.orange, isSmall: isSmall),
                  _gpsChip(Icons.straighten, context.tr('المسافة'), _formatDistance(_totalDistanceMeters), Colors.blue, isSmall: isSmall),
                ],
              ),
              SizedBox(height: isSmall ? 4 : 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _refreshLocationOnce,
                  icon: Icon(Icons.refresh, size: isSmall ? 16 : 18),
                  label: Text(context.tr('تحديث الموقع الآن')),
                ),
              ),
            ],
            SizedBox(height: isDriverMode ? 20 : (isSmall ? 12 : 16)),
            Row(
              children: [
                if (status != 'en_route' && status != 'completed')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: tripId != null ? () => _startTrip(tripId, route) : null,
                      icon: Icon(Icons.play_arrow_rounded, size: buttonIconSize),
                      label: Text(context.tr('بدء الرحلة'), style: TextStyle(fontSize: buttonFontSize)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: buttonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDriverMode ? 16 : (isSmall ? 10 : 12))),
                      ),
                    ),
                  ),
                if (status == 'en_route') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: tripId != null ? () => _endTrip(tripId, route) : null,
                      icon: Icon(Icons.flag_rounded, size: buttonIconSize),
                      label: Text(context.tr('إنهاء الرحلة'), style: TextStyle(fontSize: buttonFontSize)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: buttonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDriverMode ? 16 : (isSmall ? 10 : 12))),
                      ),
                    ),
                  ),
                  SizedBox(width: isDriverMode ? 12 : (isSmall ? 6 : 8)),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showRouteOnMap(trip),
                      icon: Icon(Icons.route, size: buttonIconSize),
                      label: Text(context.tr('المسار'), style: TextStyle(fontSize: buttonFontSize)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: buttonHeight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isDriverMode ? 16 : (isSmall ? 10 : 12))),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _gpsChip(IconData icon, String label, String value, Color color, {bool isSmall = false}) {
    final fontSize = isSmall ? 12.0 : 13.0;
    final paddingH = isSmall ? 8.0 : 10.0;
    final paddingV = isSmall ? 5.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isSmall ? 9 : 10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmall ? 14 : 16, color: color),
          SizedBox(width: isSmall ? 4 : 6),
          Text(
            '$label: $value',
            style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _tripDetailRow(IconData icon, String label, String value, {bool isSmall = false}) {
    final iconSize = isSmall ? 14.0 : 16.0;
    final labelFont = isSmall ? 10.0 : 11.0;
    final valueFont = isSmall ? 12.0 : 13.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: iconSize, color: Colors.grey[600]),
        SizedBox(width: isSmall ? 4 : 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: labelFont, color: Colors.grey[600])),
              Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: valueFont),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTripCard(Map<String, dynamic> trip) {
    final route = trip['route']?.toString() ?? '';
    final direction = trip['direction']?.toString() ?? 'outbound';
    final directionLabel = direction == 'return' ? context.tr('عودة') : context.tr('ذهاب');
    final departureDate = trip['departure_date']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.schedule_rounded, color: Colors.orange),
        title: Text(route, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$directionLabel • $departureDate'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'en_route':
        return Colors.blue;
      case 'active':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
