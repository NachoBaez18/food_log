import 'package:flutter_test/flutter_test.dart';
import 'package:foodlog/features/meals/domain/meal.dart';

void main() {
  test('Legacy records default to one photo and new records retain count', () {
    final legacy=Meal.fromJson({'id':'123','capturedAt':'2026-11-24T12:00:00','type':'lunch'});
    expect(legacy.photoCount,1);
    final meal=Meal(id:'123',capturedAt:DateTime(2026,11,24),type:MealType.lunch,photoCount:3);
    expect(Meal.fromJson(meal.toJson()).photoCount,3);
    expect(meal.photoStem(0),'123');
    expect(meal.photoStem(2),'123_2');
  });
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
