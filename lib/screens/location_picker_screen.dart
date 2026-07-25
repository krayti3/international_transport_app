import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  const LocationPickerScreen({super.key, this.initialLatitude, this.initialLongitude});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController = MapController();
  late LatLng _center;
  LatLng? _picked;

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  bool _satellite = false;
  bool _showLabels = true;
  bool _dragging = false;
  Offset? _dragPixel;

  static const String _lightTemplate =
      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _satelliteTemplate =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
  static const String _labelsTemplate =
      'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}.png';

  @override
  void initState() {
    super.initState();
    _center = widget.initialLatitude != null && widget.initialLongitude != null
        ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
        : const LatLng(35.1686, -2.9335);
    _picked = widget.initialLatitude != null && widget.initialLongitude != null ? _center : null;
    _latController.text = _picked?.latitude.toString() ?? '';
    _lngController.text = _picked?.longitude.toString() ?? '';
  }

  void _setPicked(LatLng point) {
    setState(() {
      _picked = point;
      _latController.text = point.latitude.toString();
      _lngController.text = point.longitude.toString();
    });
  }

  void _clearPicked() {
    setState(() {
      _picked = null;
      _latController.clear();
      _lngController.clear();
    });
  }

  void _applyPasted() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال إحداثيات صحيحة (خط العرض، خط الطول)')),
      );
      return;
    }
    final point = LatLng(lat, lng);
    _mapController.move(point, 14.0);
    _setPicked(point);
  }

  void _jumpTo(double lat, double lng) {
    final point = LatLng(lat, lng);
    _mapController.move(point, 14.0);
    _setPicked(point);
  }

  void _openLink() async {
    final raw = _linkController.text.trim();
    if (raw.isEmpty) return;

    final coords = _extractCoordsFromUrl(raw);
    if (coords != null) {
      _jumpTo(coords.$1, coords.$2);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (raw.contains('maps.app.goo.gl') ||
        raw.contains('goo.gl') ||
        raw.contains('bit.ly') ||
        raw.contains('tinyurl.com')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('الرابط المختصر يتطلب اتصالاً بالإنترنت لفتحه')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('تعذر استخراج الإحداثيات من الرابط')),
      );
    }

    final uri = Uri.tryParse(raw);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  (double, double)? _extractCoordsFromUrl(String url) {
    final lower = url.toLowerCase();

    final patterns = [
      RegExp(r'[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(r'[?&]ll=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(r'/place/[^/]*?/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(r'(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(lower);
      if (m != null) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) {
          return (lat, lng);
        }
      }
    }
    return null;
  }

  void _onDragEnd() {
    if (_dragPixel == null) return;
    setState(() {
      final point = _mapController.camera.screenOffsetToLatLng(_dragPixel!);
      _dragPixel = null;
      _dragging = false;
      _setPicked(LatLng(
        point.latitude.clamp(-85.0511, 85.0511),
        point.longitude.clamp(-180.0, 180.0),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final markerPixel = picked != null
        ? _mapController.camera.latLngToScreenOffset(picked)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد الموقع على الخريطة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'تأكيد الموقع',
            onPressed: _picked == null
                ? null
                : () => Navigator.pop(context, {'lat': _picked!.latitude, 'lng': _picked!.longitude}),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'خط العرض', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'خط الطول', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _applyPasted, child: const Text('تحديد')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'رابط خرائط جوجل',
                      border: OutlineInputBorder(),
                      hintText: 'https://maps.google.com/?q=lat,lng',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _openLink, child: const Text('فتح الرابط')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('خريطة')),
                    ButtonSegment<bool>(value: true, label: Text('قمر صناعي')),
                  ],
                  selected: {_satellite},
                  onSelectionChanged: (set) {
                    setState(() {
                      _satellite = set.first;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('الأسماء'),
                  selected: _showLabels,
                  onSelected: (v) {
                    setState(() {
                      _showLabels = v;
                    });
                  },
                ),
                OutlinedButton.icon(
                  onPressed: _picked == null ? null : _clearPicked,
                  icon: const Icon(Icons.clear),
                  label: const Text('مسح التحديد'),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, _) => Stack(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onLongPressStart: (details) {
                      if (_picked == null) return;
                      setState(() {
                        _dragging = true;
                        _dragPixel = details.localPosition;
                      });
                    },
                    onLongPressMoveUpdate: (details) {
                      if (_dragging) {
                        setState(() {
                          _dragPixel = details.localPosition;
                        });
                      }
                    },
                    onLongPressEnd: (_) => _onDragEnd(),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _picked != null ? 14.0 : 6.0,
                        onTap: (tapPosition, point) => _setPicked(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: _satellite ? _satelliteTemplate : _lightTemplate,
                          userAgentPackageName: 'com.example.international_transport_app',
                        ),
                        if (_showLabels && !_satellite)
                          TileLayer(
                            urlTemplate: _labelsTemplate,
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.example.international_transport_app',
                          ),
                        if (picked != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: picked,
                                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (picked != null && markerPixel != null)
                    Positioned(
                      left: (_dragPixel?.dx ?? markerPixel.dx) - 20,
                      top: (_dragPixel?.dy ?? markerPixel.dy) - 40,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.location_on,
                          color: _dragging ? Colors.redAccent : Colors.red,
                          size: 40,
                          shadows: const [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_picked != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('الإحداثيات المحددة: ${_picked!.latitude}, ${_picked!.longitude}'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'الموقع الحالي',
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final pos = await Geolocator.getCurrentPosition();
            if (!mounted) return;
            final point = LatLng(pos.latitude, pos.longitude);
            _mapController.move(point, 14.0);
            _setPicked(point);
          } catch (e) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(content: Text('تعذر تحديد الموقع: $e')),
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
