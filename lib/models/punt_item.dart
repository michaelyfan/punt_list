class PuntItem {
  final String id;
  final String text;
  final bool isChecked;
  final String? parentId; // null = top-level, non-null = sub-item

  const PuntItem({
    required this.id,
    required this.text,
    this.isChecked = false,
    this.parentId,
  });

  PuntItem copyWith({String? text, bool? isChecked}) {
    return PuntItem(
      id: id,
      text: text ?? this.text,
      isChecked: isChecked ?? this.isChecked,
      parentId: parentId,
    );
  }

  PuntItem withParentId(String? newParentId) {
    return PuntItem(
      id: id,
      text: text,
      isChecked: isChecked,
      parentId: newParentId,
    );
  }

  /// Serialize to a Firestore-compatible map (excludes id, sortOrder, timestamps).
  Map<String, dynamic> toMap() => {
        'text': text,
        'isChecked': isChecked,
        'parentId': parentId,
      };

  /// Deserialize from a Firestore document snapshot.
  factory PuntItem.fromMap(String id, Map<String, dynamic> data) => PuntItem(
        id: id,
        text: data['text'] as String? ?? '',
        isChecked: data['isChecked'] as bool? ?? false,
        parentId: data['parentId'] as String?,
      );
}
