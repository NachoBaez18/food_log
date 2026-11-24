import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import '../../features/meals/domain/meal.dart';

class LocalDatabase extends GeneratedDatabase {
  LocalDatabase(File file):super(NativeDatabase(file));
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(onCreate: (_) async {
    await customStatement('CREATE TABLE meals (id TEXT PRIMARY KEY, captured_at TEXT NOT NULL, payload TEXT NOT NULL)');
    await customStatement('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
  });
  Future<void> migrateLegacy(Directory dir) async {
    final migrated=await customSelect("SELECT value FROM settings WHERE key = 'legacy_imported'").get();
    if(migrated.isNotEmpty)return;
    await transaction(() async {
      await for(final entry in dir.list()){
        if(entry is File && entry.path.endsWith('.json')){
          final meal=Meal.fromJson(jsonDecode(await entry.readAsString()) as Map<String,dynamic>);
          await put(meal);
        }
      }
      await customStatement("INSERT OR REPLACE INTO settings (key,value) VALUES ('legacy_imported','1')");
    });
  }
  Future<void> put(Meal meal) => customStatement('INSERT OR REPLACE INTO meals (id,captured_at,payload) VALUES (?,?,?)',[meal.id,meal.capturedAt.toIso8601String(),jsonEncode(meal.toJson())]);
  Future<void> remove(String id) => customStatement('DELETE FROM meals WHERE id = ?',[id]);
  Future<List<Meal>> readMeals() async {
    final rows=await customSelect('SELECT payload FROM meals ORDER BY captured_at DESC').get();
    return rows.map((row)=>Meal.fromJson(jsonDecode(row.read<String>('payload')) as Map<String,dynamic>)).toList();
  }
}
