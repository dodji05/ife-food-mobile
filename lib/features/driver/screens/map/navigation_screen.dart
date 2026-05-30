// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver Navigation Screen
//
// Affiche une Google Maps plein écran (preview in-app) + un bouton qui lance
// le fournisseur de navigation configuré par l'admin via PlatformConfig
// key='navigation_provider' :
//   - GOOGLE_MAPS  : deep link google.navigation: (mode d) — fallback web
//   - OPENSTREETMAP: geo: scheme Android (ouvre l'app de cartes par défaut)
//                    + fallback OSM web
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/driver_provider.dart';

class DriverNavigationScreen extends ConsumerStatefulWidget {
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
  ConsumerState<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends ConsumerState<DriverNavigationScreen> {
  Future<void> _navigate(String provider) async {
    if (provider == 'OPENSTREETMAP') {
      await _openOSM();
    } else {
      await _openGoogleMaps();
    }
  }

  Future<void> _openGoogleMaps() async {
    final uri = Uri.parse(
      'google.navigation:q=${widget.lat},${widget.lng}&mode=d');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(
        Uri.parse('https://www.google.com/maps/dir/?api=1'
            '&destination=${widget.lat},${widget.lng}&travelmode=driving'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _openOSM() async {
    // Sur Android, `geo:` ouvre l'app de cartes par défaut (OSM, Maps, etc.).
    final geoUri = Uri.parse('geo:${widget.lat},${widget.lng}?q=${widget.lat},${widget.lng}(${Uri.encodeComponent(widget.label)})');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      // Fallback web OpenStreetMap
      await launchUrl(
        Uri.parse('https://www.openstreetmap.org/?mlat=${widget.lat}&mlon=${widget.lng}#map=16/${widget.lat}/${widget.lng}'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config   = ref.watch(driverConfigProvider).valueOrNull ?? {};
    final provider = (config['navigationProvider'] as String?) ?? 'GOOGLE_MAPS';
    final isOSM    = provider == 'OPENSTREETMAP';

    return Scaffold(
      backgroundColor: context.bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: AppColors.darkSurface, shape: BoxShape.circle),
            child: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.darkSurface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20)),
          child: Text(widget.label,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w700, color: context.textPrimary)),
        ),
      ),
      body: Stack(children: [
        // ── Carte in-app (toujours Google Maps) ────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(
              target: LatLng(widget.lat, widget.lng), zoom: 15),
          onMapCreated: (_) {},
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

        // ── Panel bas ───────────────────────────────────────────────────────
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.darkSurface,
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
                Text('Destination',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    color: context.textSecondary, fontWeight: FontWeight.w600)),
                Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                    fontWeight: FontWeight.w700, color: context.textPrimary)),
                Text('${widget.lat.toStringAsFixed(4)}, ${widget.lng.toStringAsFixed(4)}',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    color: context.textMuted)),
              ])),
            ]),
            const SizedBox(height: 16),

            // Bouton principal — fournisseur configuré
            ElevatedButton.icon(
              onPressed: () => _navigate(provider),
              icon: Icon(isOSM ? Icons.map_rounded : Icons.navigation_rounded, size: 20),
              label: Text(isOSM ? 'Naviguer avec OpenStreetMap' : 'Ouvrir dans Google Maps'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            ),

            // Bouton secondaire — autre fournisseur (toujours disponible)
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => isOSM ? _openGoogleMaps() : _openOSM(),
              icon: Icon(
                isOSM ? Icons.navigation_rounded : Icons.map_rounded,
                size: 16,
                color: context.textSecondary,
              ),
              label: Text(
                isOSM ? 'Ouvrir dans Google Maps' : 'Ouvrir dans OpenStreetMap',
                style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary),
              ),
            ),
          ]),
        )),
      ]),
    );
  }
}
