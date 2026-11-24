import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../meals/data/meal_store.dart';
import '../meals/domain/meal.dart';

class BackupPanel extends ConsumerStatefulWidget {
  const BackupPanel({super.key});
  @override
  ConsumerState<BackupPanel> createState()=>_BackupPanelState();
}
class _BackupPanelState extends ConsumerState<BackupPanel> {
  bool busy=false;
  Future<void> run(bool restore) async {
    setState(()=>busy=true);
    try {
      final store=ref.read(storeProvider);
      final dir=await store.directory();
      if(restore){
        final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['zip']);
        final path=picked?.files.single.path;
        if(path==null)return;
        final archive=ZipDecoder().decodeBytes(await File(path).readAsBytes(),verify:true);
        final manifest=archive.findFile('meals.json');
        if(manifest==null)throw const FormatException('Copia de FoodLog no válida');
        final records=(jsonDecode(utf8.decode(manifest.content as List<int>)) as List).map((m)=>Meal.fromJson(m as Map<String,dynamic>)).toList();
        final existing=(await store.load()).map((m)=>m.id).toSet();
        for(final meal in records){
          if(!RegExp(r'^[0-9]+$').hasMatch(meal.id))throw const FormatException('Identificador no válido');
          if(archive.findFile('${meal.id}.jpg')==null)throw const FormatException('Faltan fotografías');
        }
        for(final meal in records){
          if(existing.contains(meal.id))continue;
          for(final suffix in ['jpg','original']){
            final entry=archive.findFile('${meal.id}.$suffix');
            if(entry!=null)await File('${dir.path}/${meal.id}.$suffix').writeAsBytes(entry.content as List<int>);
          }
          await store.writeMetadata(meal);
        }
        if(mounted)ref.invalidate(mealsProvider);
        if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Copia restaurada sin reemplazar registros existentes')));
      }else{
        final records=await store.load();
        final archive=Archive();
        final metadata=utf8.encode(jsonEncode(records.map((m)=>m.toJson()).toList()));
        archive.addFile(ArchiveFile('meals.json',metadata.length,metadata));
        for(final meal in records){
          for(final suffix in ['jpg','original']){
            final file=File('${dir.path}/${meal.id}.$suffix');
            if(await file.exists()){
              final bytes=await file.readAsBytes();
              archive.addFile(ArchiveFile('${meal.id}.$suffix',bytes.length,bytes));
            }
          }
        }
        final file=File('${(await getTemporaryDirectory()).path}/foodlog-backup-${DateTime.now().millisecondsSinceEpoch}.zip');
        await file.writeAsBytes(ZipEncoder().encode(archive)!);
        await Share.shareXFiles([XFile(file.path)],text:'Copia privada de FoodLog');
      }
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Error de copia: $e')));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Column(children:[
    ListTile(leading:const Icon(Icons.backup_outlined),title:const Text('Exportar copia de seguridad'),subtitle:const Text('ZIP con registros y fotografías privadas'),enabled:!busy,onTap:()=>run(false)),
    ListTile(leading:const Icon(Icons.restore),title:const Text('Restaurar copia'),subtitle:const Text('Importar sin reemplazar registros existentes'),enabled:!busy,onTap:()=>run(true)),
    if(busy)const LinearProgressIndicator(),
  ]);
}
