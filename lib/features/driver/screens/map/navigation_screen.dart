// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver Navigation Screen
//
// Écran de navigation GPS vers un point (pickup ou delivery).
// Affiche une Google Map plein écran avec un marker sur la destination,
// + un bottom panel avec CTA "Ouvrir dans Google Maps" qui lance le mode
// navigation natif via deep link `google.navigation:q=lat,lng&mode=d`.
//
// Fallback web si l'app Google Maps n'est pas installée.
//
// Source : porté depuis ife-food-driver/features/map/screens/navigation_screen.dart
// Remplace le placeholder Text qui était dans le router (cf app_router.dart).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

class DriverNavigationScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String label;
  const DriverNavigationScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.label,
  });

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen> {
  GoogleMapController? _ctrl;

  Future<void> _openGoogleMaps() async {
    // Deep link mode navigation Google Maps Android. Sur iOS, le scheme
    // diffère mais on tombe automatiquement sur le fallback web.
    final uri = Uri.parse('google.navigation:q=${widget.lat},${widget.lng}&mode=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final fallback = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${widget.lat},${widget.lng}&travelmode=driving',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBg,
    extendBodyBehindAppBar: true,
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_rounded, color: AppColors.darkText),
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20)),
        child: Text(widget.label,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
            fontWeight: FontWeight.w700, color: AppColors.darkText)),
      ),
    ),
    body: Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.lat, widget.lng), zoom: 15),
        onMapCreated: (c) => _ctrl = c,
        markers: {
          Marker(
            markerId: const MarkerId('dest'),
            position: LatLng(widget.lat, widget.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: widget.label),
          ),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
      // Bottom panel : carte avec destination + CTA navigation externe
      Positioned(bottom: 0, left: 0, right: 0, child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.location_on_rounded,
                color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Destination',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
              Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w700, color: AppColors.darkText)),
              Text('${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  color: AppColors.darkMuted)),
            ])),
          ]),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openGoogleMaps,
            icon: const Icon(Icons.navigation_rounded, size: 20),
            label: const Text('Ouvrir dans Google Maps'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ]),
      )),
    ]),
  );
}
