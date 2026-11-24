import 'package:flutter_test/flutter_test.dart';
import 'package:foodlog/features/meals/domain/meal.dart';

void main() {
  test('Suggests lunch at midday', () {
    expect(MealType.suggest(DateTime(2026, 11, 24, 12)), MealType.lunch);
  });
  test('Suggests dinner in the evening', () {
    expect(MealType.suggest(DateTime(2026, 11, 24, 20)), MealType.dinner);
  });
  test('Meal metadata survives serialization', () {
    final meal = Meal(id: '1', capturedAt: DateTime(2026, 11, 24, 12), type: MealType.lunch, notes: 'Arroz');
    final restored = Meal.fromJson(meal.toJson());
    expect(restored.id, meal.id);
    expect(restored.capturedAt, meal.capturedAt);
    expect(restored.type, meal.type);
    expect(restored.notes, meal.notes);
  });
}
