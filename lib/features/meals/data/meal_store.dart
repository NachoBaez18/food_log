import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../domain/meal.dart';
import '../../../core/database/local_database.dart';

final storeProvider = Provider((ref) { final store=MealStore(); ref.onDispose(store.close); return store; });
final mealsProvider = FutureProvider((ref) => ref.watch(storeProvider).load());

class MealStore {
  Future<LocalDatabase>? _opening;
  Future<LocalDatabase> database() => _opening ??= _open();
  Future<LocalDatabase> _open() async {
    final dir=await directory();
    final db=LocalDatabase(File('${dir.path}/meals.sqlite'));
    try { await db.migrateLegacy(dir); return db; } catch (_) { await db.close(); rethrow; }
  }
  void close() { _opening?.then((db)=>db.close(),onError:(Object _){}); }
  Future<Directory> directory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/foodlog').create(recursive: true);
  }
  Future<File> photo(Meal meal, [int index=0]) async => File('${(await directory()).path}/${meal.photoStem(index)}.jpg');
  Future<List<File>> photos(Meal meal) => Future.wait(List.generate(meal.photoCount,(i)=>photo(meal,i)));
  Future<List<Meal>> load() async => (await database()).readMeals();
  Future<void> save(Meal meal, List<String> sources) async {
    if(sources.length != meal.photoCount || sources.isEmpty) throw ArgumentError('Cantidad de fotos inválida');
    await database();
    try {
      for(var i=0;i<sources.length;i++){await _savePhoto(meal,sources[i],i);}
      await writeMetadata(meal);
    } catch (_) {
      await _deletePhotos(meal);
      rethrow;
    }
  }
  Future<void> _savePhoto(Meal meal, String source, int index) async {
    final decoded = img.decodeImage(await File(source).readAsBytes());
    if (decoded == null) throw const FormatException('Imagen no válida');
    final oriented = img.bakeOrientation(decoded);
    final picture = oriented.width > 1600 ? img.copyResize(oriented, width: 1600) : oriented;
    final original = File('${(await directory()).path}/${meal.photoStem(index)}.original');
    await original.writeAsBytes(await File(source).readAsBytes());
    stamp(picture, meal);
    final file = await photo(meal,index);
    await file.writeAsBytes(img.encodeJpg(picture, quality: 85));
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
    for(var index=0;index<meal.photoCount;index++){
    final original = File('${(await directory()).path}/${meal.photoStem(index)}.original');
    if (await original.exists()) {
      final decoded = img.decodeImage(await original.readAsBytes());
      if (decoded != null) {
        final oriented = img.bakeOrientation(decoded);
        final picture = oriented.width > 1600 ? img.copyResize(oriented, width: 1600) : oriented;
        stamp(picture, meal);
        await (await photo(meal,index)).writeAsBytes(img.encodeJpg(picture, quality: 85));
      }
    }
    }
    await writeMetadata(meal);
  }
  Future<List<String>> editSources(Meal meal) async {
    final dir=await directory();
    final result=<String>[];
    for(var i=0;i<meal.photoCount;i++){
      final original=File('${dir.path}/${meal.photoStem(i)}.original');
      result.add(await original.exists()?original.path:(await photo(meal,i)).path);
    }
    return result;
  }
  Future<void> replacePhotos(Meal previous, Meal updated, List<String> sources) async {
    if(previous.id!=updated.id || sources.length!=updated.photoCount || sources.isEmpty || sources.length>12)throw ArgumentError('Fotos invalidas');
    final dir=await directory();
    final stage=await dir.createTemp('edit-');
    final oldSources=await editSources(previous);
    final backups=<String,File>{};
    var replacing=false;
    try{
      for(var i=0;i<previous.photoCount;i++){
        for(final suffix in ['jpg','original']){
          final name='${previous.photoStem(i)}.$suffix';
          final file=File('${dir.path}/$name');
          if(await file.exists())backups[name]=await file.copy('${stage.path}/old-$name');
        }
      }
      for(var i=0;i<sources.length;i++){
        final stem=updated.photoStem(i);
        final source=File(sources[i]);
        final oldIndex=oldSources.indexOf(source.path);
        // Older records may have only a stamped JPEG, so preserve its pixels
        // unless a replacement is captured.
        if(oldIndex>=0 && !source.path.endsWith('.original')){
          if(previous.type!=updated.type || previous.capturedAt!=updated.capturedAt)throw StateError('Una foto antigua no tiene original. Elimina esa foto o conserva su fecha y categoria.');
          await source.copy('${stage.path}/$stem.jpg');
        }else{
          final bytes=await source.readAsBytes();
          final decoded=img.decodeImage(bytes);
          if(decoded==null)throw const FormatException('Imagen no valida');
          final oriented=img.bakeOrientation(decoded);
          final picture=oriented.width>1600?img.copyResize(oriented,width:1600):oriented;
          stamp(picture,updated);
          await File('${stage.path}/$stem.original').writeAsBytes(bytes);
          await File('${stage.path}/$stem.jpg').writeAsBytes(img.encodeJpg(picture,quality:85));
        }
      }
      replacing=true;
      await _deletePhotos(previous);
      for(var i=0;i<updated.photoCount;i++){
        for(final suffix in ['jpg','original']){
          final name='${updated.photoStem(i)}.$suffix';
          final file=File('${stage.path}/$name');
          if(await file.exists())await file.copy('${dir.path}/$name');
        }
      }
      await writeMetadata(updated);
    }catch(_){
      if(replacing){
        await _deletePhotos(updated);
        for(final entry in backups.entries){await entry.value.copy('${dir.path}/${entry.key}');}
      }
      rethrow;
    }finally{await stage.delete(recursive:true);}
  }
  Future<void> writeMetadata(Meal meal) async {
    await (await database()).put(meal);
  }
  Future<void> delete(Meal meal) async {
    await (await database()).remove(meal.id);
    final meta = File('${(await directory()).path}/${meal.id}.json');
    if (await meta.exists()) await meta.delete();
    await _deletePhotos(meal);
  }
  Future<void> _deletePhotos(Meal meal) async {
    final dir=await directory();
    for(var i=0;i<meal.photoCount;i++){
      for(final suffix in ['jpg','original']){
        final file=File('${dir.path}/${meal.photoStem(i)}.$suffix');
        if(await file.exists())await file.delete();
      }
    }
  }
}
