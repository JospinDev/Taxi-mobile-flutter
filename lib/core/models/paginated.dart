/// Standard Django REST Framework page wrapper.
class Paginated<T> {
  const Paginated({
    required this.count,
    required this.results,
    this.next,
    this.previous,
  });

  final int count;
  final List<T> results;
  final String? next;
  final String? previous;

  bool get hasNext => next != null && next!.isNotEmpty;

  factory Paginated.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) => Paginated(
    count: (json['count'] as num?)?.toInt() ?? 0,
    next: json['next'] as String?,
    previous: json['previous'] as String?,
    results: (json['results'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => itemFromJson(e.cast<String, dynamic>()))
        .toList(growable: false),
  );
}
