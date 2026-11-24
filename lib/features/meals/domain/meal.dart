enum MealType {
  breakfast('Desayuno'), morningSnack('Media mañana'), lunch('Almuerzo'),
  snack('Merienda'), dinner('Cena'), other('Otros');
  const MealType(this.label);
  final String label;
  static MealType suggest(DateTime time) {
    final h = time.hour;
    if (h < 9) return breakfast;
    if (h < 11) return morningSnack;
    if (h < 15) return lunch;
    if (h < 19) return snack;
    return dinner;
  }
}

class Meal {
  const Meal({required this.id, required this.capturedAt, required this.type, this.notes = ''});
  final String id;
  final DateTime capturedAt;
  final MealType type;
  final String notes;
  Map<String, dynamic> toJson() => {'id': id, 'capturedAt': capturedAt.toIso8601String(), 'type': type.name, 'notes': notes};
  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
    id: json['id'] as String, capturedAt: DateTime.parse(json['capturedAt'] as String),
    type: MealType.values.byName(json['type'] as String), notes: json['notes'] as String? ?? '',
  );
}
