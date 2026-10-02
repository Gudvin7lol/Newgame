class ZamerCeilingVisibilityPolicy {
  const ZamerCeilingVisibilityPolicy._();

  /// Orbit view intentionally keeps the ceiling open so the room can be
  /// inspected from above. Walk and Photo modes represent the finished
  /// interior and therefore must keep the ceiling visible.
  static bool visible({
    required bool walkMode,
    required bool photoPreview,
  }) => walkMode || photoPreview;
}
