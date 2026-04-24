class ProviderProfile {
  const ProviderProfile({
    required this.name,
    this.serviceIdentifier,
    this.metadata = const {},
  });

  final String name;
  final String? serviceIdentifier;
  final Map<String, String> metadata;

  String get stableIdentifier {
    final sid = serviceIdentifier;
    if (sid != null && sid.isNotEmpty) return sid;
    return name.toLowerCase();
  }

  bool matches(ProviderProfile? other) =>
      other != null && stableIdentifier == other.stableIdentifier;

  ProviderProfile copyWith({
    String? name,
    String? serviceIdentifier,
    Map<String, String>? metadata,
  }) =>
      ProviderProfile(
        name: name ?? this.name,
        serviceIdentifier: serviceIdentifier ?? this.serviceIdentifier,
        metadata: metadata ?? this.metadata,
      );
}
