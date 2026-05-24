// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — Zones de livraison
// Permet au livreur d'ajouter, modifier et supprimer ses zones d'activité.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/driver_zone.dart';
import '../../providers/driver_provider.dart';

class DriverZonesScreen extends ConsumerWidget {
  const DriverZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zonesAsync = ref.watch(driverZonesProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
                color: AppColors.darkBg, shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.darkText),
          ),
        ),
        title: const Text('Zones de livraison',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
              fontWeight: FontWeight.w800, color: AppColors.darkText)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            tooltip: 'Ajouter une zone',
            onPressed: () => _showZoneSheet(context, ref, null),
          ),
        ],
      ),
      body: zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Text('Erreur : $e',
              style: const TextStyle(color: AppColors.danger, fontFamily: 'Nunito'))),
        data: (zones) {
          if (zones.isEmpty) {
            return _EmptyState(onAdd: () => _showZoneSheet(context, ref, null));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: zones.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _ZoneTile(
              zone: zones[i],
              onEdit: () => _showZoneSheet(context, ref, zones[i]),
              onDelete: () => _deleteZone(context, ref, zones[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showZoneSheet(BuildContext context, WidgetRef ref, DriverZone? zone) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ZoneForm(zone: zone, onSaved: () {
        ref.invalidate(driverZonesProvider);
      }),
    );
  }

  Future<void> _deleteZone(BuildContext context, WidgetRef ref, DriverZone zone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('Supprimer la zone',
            style: TextStyle(fontFamily: 'Nunito', color: AppColors.darkText, fontWeight: FontWeight.w800)),
        content: Text('Supprimer « ${zone.name} » ?',
            style: const TextStyle(fontFamily: 'Nunito', color: AppColors.darkSubtext)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(fontFamily: 'Nunito', color: AppColors.darkSubtext)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(fontFamily: 'Nunito', color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiClient.instance.delete('/drivers/me/zones/${zone.id}');
      ref.invalidate(driverZonesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'),
              backgroundColor: AppColors.danger));
      }
    }
  }
}

// ── Tuile de zone ─────────────────────────────────────────────────────────────
class _ZoneTile extends StatelessWidget {
  final DriverZone zone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ZoneTile({required this.zone, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: zone.isDefault
            ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: (zone.isDefault ? AppColors.primary : AppColors.info).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            zone.isDefault ? Icons.star_rounded : Icons.place_rounded,
            color: zone.isDefault ? AppColors.primary : AppColors.info,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(zone.name,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w800, color: AppColors.darkText)),
            if (zone.isDefault) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4)),
                child: const Text('Par défaut',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 9,
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text('${zone.city} · ${zone.country} · ${zone.radiusKm.toStringAsFixed(0)} km',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
        ])),
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: AppColors.darkSubtext, size: 18),
          onPressed: onEdit,
          tooltip: 'Modifier',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
          onPressed: onDelete,
          tooltip: 'Supprimer',
        ),
      ]),
    );
  }
}

// ── Formulaire ajout / édition ────────────────────────────────────────────────
class _ZoneForm extends StatefulWidget {
  final DriverZone? zone;
  final VoidCallback onSaved;
  const _ZoneForm({this.zone, required this.onSaved});

  @override
  State<_ZoneForm> createState() => _ZoneFormState();
}

class _ZoneFormState extends State<_ZoneForm> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _radius;
  bool _isDefault = false;
  bool _loading   = false;

  @override
  void initState() {
    super.initState();
    _name    = TextEditingController(text: widget.zone?.name ?? '');
    _city    = TextEditingController(text: widget.zone?.city ?? '');
    _country = TextEditingController(text: widget.zone?.country ?? 'BJ');
    _radius  = TextEditingController(
        text: (widget.zone?.radiusKm ?? 10).toStringAsFixed(0));
    _isDefault = widget.zone?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose(); _city.dispose(); _country.dispose(); _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name   = _name.text.trim();
    final city   = _city.text.trim();
    final country = _country.text.trim().toUpperCase();
    final radius = double.tryParse(_radius.text.trim()) ?? 10.0;

    if (name.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom et ville sont obligatoires'),
            backgroundColor: AppColors.danger));
      return;
    }

    setState(() => _loading = true);
    try {
      final body = {
        'name': name, 'city': city, 'country': country.isEmpty ? 'BJ' : country,
        'radiusKm': radius, 'isDefault': _isDefault,
      };
      if (widget.zone == null) {
        await ApiClient.instance.post('/drivers/me/zones', data: body);
      } else {
        await ApiClient.instance.patch('/drivers/me/zones/${widget.zone!.id}', data: body);
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.zone != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.darkBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text(editing ? 'Modifier la zone' : 'Nouvelle zone',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 18,
                fontWeight: FontWeight.w900, color: AppColors.darkText)),
          const SizedBox(height: 20),
          _Field(controller: _name, label: 'Nom (ex: Centre Cotonou)', icon: Icons.label_rounded),
          const SizedBox(height: 12),
          _Field(controller: _city, label: 'Ville', icon: Icons.location_city_rounded),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Field(controller: _country, label: 'Pays (code)', icon: Icons.flag_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _Field(controller: _radius, label: 'Rayon (km)', icon: Icons.radar_rounded, isNumber: true)),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _isDefault = !_isDefault),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: _isDefault ? AppColors.primary : Colors.transparent,
                  border: Border.all(color: _isDefault ? AppColors.primary : AppColors.darkBorder, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _isDefault
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 10),
              const Text('Zone par défaut',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    color: AppColors.darkText, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _save,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(editing ? 'Enregistrer' : 'Ajouter la zone',
                    style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ]),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool isNumber;
  const _Field({required this.controller, required this.label, required this.icon, this.isNumber = false});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
    style: const TextStyle(fontFamily: 'Nunito', color: AppColors.darkText, fontSize: 14),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontFamily: 'Nunito', color: AppColors.darkSubtext, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.darkSubtext, size: 18),
      filled: true,
      fillColor: AppColors.darkBg,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.darkBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.darkBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    ),
  );
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.place_rounded, color: AppColors.primary, size: 34),
      ),
      const SizedBox(height: 16),
      const Text('Aucune zone configurée',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
            fontWeight: FontWeight.w800, color: AppColors.darkText)),
      const SizedBox(height: 6),
      const Text('Ajoutez vos zones pour recevoir\ndes missions dans ces secteurs.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter une zone',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
      ),
    ]),
  );
}
