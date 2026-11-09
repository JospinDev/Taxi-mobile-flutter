import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/models/geo_point.dart';
import '../../../../core/services/geo_services.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_motion.dart';

/// What the user picked in [showPlaceSearch].
class PlaceSearchResult {
  const PlaceSearchResult.place(Place this.place) : pickOnMap = false;
  const PlaceSearchResult.onMap() : place = null, pickOnMap = true;

  final Place? place;
  final bool pickOnMap;
}

/// Full-height address search (OSM Nominatim, debounced).
Future<PlaceSearchResult?> showPlaceSearch(
  BuildContext context, {
  required String title,
  GeoPoint? near,
  String hint = 'Rechercher une adresse, un lieu…',
}) {
  return showModalBottomSheet<PlaceSearchResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _PlaceSearchSheet(title: title, near: near, hint: hint),
  );
}

class _PlaceSearchSheet extends ConsumerStatefulWidget {
  const _PlaceSearchSheet({required this.title, required this.near, required this.hint});

  final String title;
  final GeoPoint? near;
  final String hint;

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _loading = false;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Nominatim allows 1 request/second: debounce typing.
    _debounce = Timer(const Duration(milliseconds: 550), () => _search(value));
  }

  Future<void> _search(String value) async {
    final id = ++_requestId;
    setState(() => _loading = value.trim().length >= 3);
    final results = await ref.read(geoServicesProvider).search(value, near: widget.near);
    if (!mounted || id != _requestId) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final near = widget.near;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .88,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 42, height: 5, decoration: BoxDecoration(color: AppColors.line, borderRadius: AppRadius.rPill)),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: AppTypography.h2)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _search,
                style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : (_query.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _query.clear();
                                  setState(() => _results = const []);
                                },
                              )),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            ListTile(
              onTap: () => Navigator.pop(context, const PlaceSearchResult.onMap()),
              leading: Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(color: AppColors.brandSoft, shape: BoxShape.circle),
                child: const Icon(Icons.pin_drop_rounded, color: AppColors.brandDeep, size: 20),
              ),
              title: Text('Choisir sur la carte', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink)),
              subtitle: const Text('Déplacez la carte pour placer le point'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
            const Divider(),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.xl),
                        child: Text(
                          _query.text.trim().length < 3
                              ? 'Tapez au moins 3 lettres pour chercher une adresse.'
                              : (_loading ? 'Recherche…' : 'Aucun résultat. Essayez « Choisir sur la carte ».'),
                          textAlign: TextAlign.center,
                          style: AppTypography.body.copyWith(color: AppColors.muted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: AppSpace.xl),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(indent: 72),
                      itemBuilder: (context, i) {
                        final p = _results[i];
                        final km = near == null ? null : near.distanceTo(p.point) / 1000;
                        return ListTile(
                          onTap: () => Navigator.pop(context, PlaceSearchResult.place(p)),
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
                            child: const Icon(Icons.place_rounded, color: AppColors.inkSoft, size: 20),
                          ),
                          title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink)),
                          subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: km == null ? null : Text('${km.toStringAsFixed(1)} km', style: AppTypography.caption),
                        ).entrance(index: i);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
