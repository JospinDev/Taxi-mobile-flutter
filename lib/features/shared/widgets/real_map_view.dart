import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';
import '../../../core/models/geo_point.dart';

/// Visual style of the basemap.
enum MapStyle {
  /// OpenStreetMap standard — clean, readable streets (client & admin).
  light('https://tile.openstreetmap.org/{z}/{x}/{y}.png'),

  /// OSM tiles + dark ColorFilter — night "driver HUD" look (no API key needed).
  dark('https://tile.openstreetmap.org/{z}/{x}/{y}.png');

  const MapStyle(this.url);
  final String url;

  bool get isDark => this == MapStyle.dark;
}

/// Imperative handle on a [RealMapView]: animated moves and fit-to-points.
class AppMapController {
  _RealMapViewState? _state;

  bool get isReady => _state?._ready ?? false;

  void moveTo(GeoPoint point, {double? zoom}) => _state?._animateTo(point, zoom);

  /// Frames all [points] (pickup, dropoff, driver…) with [padding].
  void fitPoints(List<GeoPoint> points, {EdgeInsets padding = const EdgeInsets.all(60)}) =>
      _state?._fit(points, padding);

  GeoPoint? get center {
    final c = _state?._controller.camera.center;
    return c == null ? null : GeoPoint(c.latitude, c.longitude);
  }
}

/// Real interactive OpenStreetMap view (flutter_map, no API key).
///
/// Every map in the app goes through this widget so the tile source, markers
/// and motion stay consistent.
class RealMapView extends StatefulWidget {
  const RealMapView({
    super.key,
    this.controller,
    this.initialCenter = GeoPoint.cityCenter,
    this.initialZoom = 15,
    this.markers = const [],
    this.circles = const [],
    this.polylines = const [],
    this.onTap,
    this.interactive = true,
    this.showAttribution = true,
    this.userLocation,
    this.style = MapStyle.light,
    this.onCameraMoveStarted,
    this.onCameraIdle,
    this.onReady,
  });

  final AppMapController? controller;
  final GeoPoint initialCenter;
  final double initialZoom;
  final List<MapMarkerData> markers;
  final List<MapCircleData> circles;
  final List<MapPolylineData> polylines;
  final void Function(GeoPoint point)? onTap;
  final bool interactive;
  final bool showAttribution;

  /// The device position, drawn as a pulsing blue dot.
  final GeoPoint? userLocation;
  final MapStyle style;

  /// User started dragging the map (lift the centre pin).
  final VoidCallback? onCameraMoveStarted;

  /// Camera stopped: receives the new centre (choose pickup by dragging).
  final void Function(GeoPoint center)? onCameraIdle;

  /// The map is laid out: the controller can now move / fit the camera.
  final VoidCallback? onReady;

  @override
  State<RealMapView> createState() => _RealMapViewState();
}

class _RealMapViewState extends State<RealMapView> with TickerProviderStateMixin {
  final MapController _controller = MapController();
  bool _ready = false;
  AnimationController? _anim;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant RealMapView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller?._state = null;
    _anim?.dispose();
    super.dispose();
  }

  void _animateTo(GeoPoint point, double? zoom) {
    if (!_ready) return;
    final camera = _controller.camera;
    final latTween = Tween(begin: camera.center.latitude, end: point.lat);
    final lngTween = Tween(begin: camera.center.longitude, end: point.lng);
    final zoomTween = Tween(begin: camera.zoom, end: zoom ?? camera.zoom);

    _anim?.dispose();
    final anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _anim = anim;
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
    anim.addListener(() {
      _controller.move(
        LatLng(latTween.evaluate(curved), lngTween.evaluate(curved)),
        zoomTween.evaluate(curved),
      );
    });
    anim.forward();
  }

  void _fit(List<GeoPoint> points, EdgeInsets padding) {
    if (!_ready || points.isEmpty) return;
    if (points.length == 1) return _animateTo(points.first, 16);
    final fitted = CameraFit.coordinates(
      coordinates: [for (final p in points) LatLng(p.lat, p.lng)],
      padding: padding,
      maxZoom: 17,
    ).fit(_controller.camera);
    _animateTo(GeoPoint(fitted.center.latitude, fitted.center.longitude), fitted.zoom);
  }

  void _onEvent(MapEvent event) {
    final gesture = event.source != MapEventSource.mapController &&
        event.source != MapEventSource.fitCamera;
    if (event is MapEventMoveStart && gesture) widget.onCameraMoveStarted?.call();
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd) {
      final c = event.camera.center;
      widget.onCameraIdle?.call(GeoPoint(c.latitude, c.longitude));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.style == MapStyle.dark;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: LatLng(widget.initialCenter.lat, widget.initialCenter.lng),
        initialZoom: widget.initialZoom,
        minZoom: 5,
        maxZoom: 19,
        backgroundColor: dark ? const Color(0xFF1B2232) : const Color(0xFFF2EFE9),
        onMapReady: () {
          setState(() => _ready = true);
          widget.onReady?.call();
        },
        onMapEvent: _onEvent,
        onTap: widget.onTap == null
            ? null
            : (_, p) => widget.onTap!(GeoPoint(p.latitude, p.longitude)),
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        // Dark style: invert OSM tiles and shift hue to blue-grey (no API key).
        if (widget.style.isDark)
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -0.2126, -0.7152, -0.0722, 0, 255,
              -0.2126, -0.7152, -0.0722, 0, 255,
              -0.2126, -0.7152, -0.0722, 0, 255,
              0,       0,       0,       1,   0,
            ]),
            child: TileLayer(
              urlTemplate: widget.style.url,
              userAgentPackageName: 'com.jospindev.taxi',
              maxNativeZoom: 19,
              tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 250)),
            ),
          )
        else
          TileLayer(
            urlTemplate: widget.style.url,
            userAgentPackageName: 'com.jospindev.taxi',
            maxNativeZoom: 19,
            tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 250)),
          ),
        if (widget.circles.isNotEmpty)
          CircleLayer(
            circles: [
              for (final c in widget.circles)
                CircleMarker(
                  point: LatLng(c.point.lat, c.point.lng),
                  radius: c.radius,
                  useRadiusInMeter: c.useRadiusInMeter,
                  color: c.color,
                  borderStrokeWidth: c.borderStrokeWidth,
                  borderColor: c.borderColor,
                ),
            ],
          ),
        if (widget.polylines.isNotEmpty)
          PolylineLayer(
            polylines: [
              for (final p in widget.polylines)
                Polyline(
                  points: [for (final pt in p.points) LatLng(pt.lat, pt.lng)],
                  color: p.color,
                  strokeWidth: p.strokeWidth,
                  borderStrokeWidth: p.borderStrokeWidth,
                  borderColor: p.borderColor,
                  pattern: p.dashed
                      ? StrokePattern.dashed(segments: const [10, 8])
                      : const StrokePattern.solid(),
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.userLocation != null)
              Marker(
                point: LatLng(widget.userLocation!.lat, widget.userLocation!.lng),
                width: 34,
                height: 34,
                child: const _UserDot(),
              ),
            for (final m in widget.markers)
              Marker(
                point: LatLng(m.point.lat, m.point.lng),
                width: m.width ?? m.size,
                height: m.height ?? m.size,
                alignment: m.alignment,
                child: m.child,
              ),
          ],
        ),
        if (widget.showAttribution)
          SimpleAttributionWidget(
            source: Text(
              '© OpenStreetMap © CARTO',
              style: TextStyle(fontSize: 9.5, color: dark ? Colors.white70 : AppColors.muted),
            ),
            backgroundColor: (dark ? Colors.black : Colors.white).withValues(alpha: .55),
          ),
      ],
    );
  }
}

/// A marker payload for [RealMapView] — keeps the map free of domain logic.
class MapMarkerData {
  const MapMarkerData({
    required this.point,
    required this.child,
    this.size = 40,
    this.width,
    this.height,
    this.alignment = Alignment.center,
  });

  final GeoPoint point;
  final Widget child;
  final double size;
  final double? width;
  final double? height;

  /// Use [Alignment.topCenter] for pins whose tip must touch the point.
  final Alignment alignment;
}

class MapCircleData {
  const MapCircleData({
    required this.point,
    required this.radius,
    this.useRadiusInMeter = false,
    this.color = const Color(0x1F10B981),
    this.borderStrokeWidth = 1,
    this.borderColor = AppColors.emerald,
  });

  final GeoPoint point;
  final double radius;
  final bool useRadiusInMeter;
  final Color color;
  final double borderStrokeWidth;
  final Color borderColor;
}

class MapPolylineData {
  const MapPolylineData({
    required this.points,
    this.color = AppColors.ink,
    this.strokeWidth = 5,
    this.borderStrokeWidth = 2,
    this.borderColor = Colors.white,
    this.dashed = false,
  });

  final List<GeoPoint> points;
  final Color color;
  final double strokeWidth;
  final double borderStrokeWidth;
  final Color borderColor;
  final bool dashed;
}

/// Tween between two [GeoPoint]s — smooth marker movement between GPS fixes.
class GeoPointTween extends Tween<GeoPoint> {
  GeoPointTween({super.begin, super.end});

  @override
  GeoPoint lerp(double t) => begin!.lerp(end!, t);
}

/// Pulsing "you are here" dot.
class _UserDot extends StatefulWidget {
  const _UserDot();

  @override
  State<_UserDot> createState() => _UserDotState();
}

class _UserDotState extends State<_UserDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 12 + 22 * _c.value,
            height: 12 + 22 * _c.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.info.withValues(alpha: .35 * (1 - _c.value)),
            ),
          ),
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: AppColors.info,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: AppShadow.soft,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round floating map button (recentre, layers…).
class MapFab extends StatelessWidget {
  const MapFab({super.key, required this.icon, required this.onTap, this.tooltip, this.dark = false});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? AppColors.surfaceDark : Colors.white,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: const Color(0x330F172A),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip ?? '',
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 22, color: dark ? Colors.white : AppColors.ink),
          ),
        ),
      ),
    );
  }
}
