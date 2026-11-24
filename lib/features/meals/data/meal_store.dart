import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../domain/meal.dart';

final storeProvider = Provider((ref) => MealStore());
final mealsProvider = FutureProvider((ref) => ref.watch(storeProvider).load());

class MealStore {
  Future<Directory> directory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/foodlog').create(recursive: true);
  }
  Future<File> photo(Meal meal) async => File('${(await directory()).path}/${meal.id}.jpg');
  Future<List<Meal>> load() async {
    final dir = await directory();
    final result = <Meal>[];
    await for (final entry in dir.list()) {
      if (entry is File && entry.path.endsWith('.json')) {
        result.add(Meal.fromJson(jsonDecode(await entry.readAsString()) as Map<String,dynamic>));
      }
    }
    result.sort((a,b) => b.capturedAt.compareTo(a.capturedAt));
    return result;
  }
  Future<void> save(Meal meal, String source) async {
    final decoded = img.decodeImage(await File(source).readAsBytes());
    if (decoded == null) throw const FormatException('Imagen no válida');
    final oriented = img.bakeOrientation(decoded);
    final picture = oriented.width > 1600 ? img.copyResize(oriented, width: 1600) : oriented;
    final original = File('${(await directory()).path}/${meal.id}.original');
    await original.writeAsBytes(await File(source).readAsBytes());
    stamp(picture, meal);
    final file = await photo(meal);
    await file.writeAsBytes(img.encodeJpg(picture, quality: 85));
    await writeMetadata(meal);
  }
  void stamp(img.Image picture, Meal meal) {
    final scale = picture.width >= 700 ? 24 : 14;
    final font = scale == 24 ? img.arial24 : img.arial14;
    final height = scale * 3;
    img.fillRect(picture, x1: 0, y1: 0, x2: picture.width - 1,
      y2: height, color: img.ColorRgba8(0, 0, 0, 190));
    img.drawString(picture, meal.type.label.toUpperCase(), font: font,
      x: 12, y: 6, color: img.ColorRgb8(255,255,255));
    img.drawString(picture, DateFormat('dd/MM/yyyy HH:mm').format(meal.capturedAt),
      font: font, x: 12, y: scale + 12, color: img.ColorRgb8(255,255,255));
  }
  Future<void> update(Meal meal) async {
    final original = File('${(await directory()).path}/${meal.id}.original');
    if (await original.exists()) {
      final decoded = img.decodeImage(await original.readAsBytes());
      if (decoded != null) {
        final oriented = img.bakeOrientation(decoded);
        final picture = oriented.width > 1600 ? img.copyResize(oriented, width: 1600) : oriented;
        stamp(picture, meal);
        await (await photo(meal)).writeAsBytes(img.encodeJpg(picture, quality: 85));
      }
    }
    await writeMetadata(meal);
  }
  Future<void> writeMetadata(Meal meal) async {
    final file = File('${(await directory()).path}/${meal.id}.json');
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(meal.toJson()), flush: true);
    await temp.rename(file.path);
  }
  Future<void> delete(Meal meal) async {
    final meta = File('${(await directory()).path}/${meal.id}.json');
    if (await meta.exists()) await meta.delete();
    final file = await photo(meal);
    if (await file.exists()) await file.delete();
    final original = File('${(await directory()).path}/${meal.id}.original');
    if (await original.exists()) await original.delete();
  }
}
