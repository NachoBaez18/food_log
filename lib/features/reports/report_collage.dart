import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../meals/data/meal_store.dart';
import '../meals/domain/meal.dart';

class ReportCollage {
  ReportCollage(this.store);
  final MealStore store;
  Future<List<File>> create(List<Meal> meals) async {
    final groups=<String,List<String>>{};
    final ordered=[...meals]..sort((a,b)=>a.capturedAt.compareTo(b.capturedAt));
    for(final meal in ordered){
      final key=DateFormat('yyyy-MM-dd').format(meal.capturedAt);
      groups.putIfAbsent(key,()=>[]).addAll((await store.photos(meal)).map((f)=>f.path));
    }
    final dir=await (await getTemporaryDirectory()).createTemp('foodlog-collage-');
    final result=<File>[];
    for(final day in groups.entries){
      for(var i=0;i<day.value.length;i+=6){
        final page=i~/6+1;
        final output='${dir.path}/foodlog-${day.key}-$page.jpg';
        await compute(renderCollage,<String,Object>{'paths':day.value.skip(i).take(6).toList(),'day':day.key,'page':page,'total':(day.value.length/6).ceil(),'output':output});
        result.add(File(output));
      }
    }
    return result;
  }
}

void renderCollage(Map<String,Object> args){
  final paths=args['paths'] as List<String>;
  const tile=600, gap=20, header=100;
  final rows=(paths.length/2).ceil();
  final canvas=img.Image(width:tile*2+gap*3,height:header+rows*(tile+gap)+gap);
  img.fill(canvas,color:img.ColorRgb8(247,248,243));
  img.fillRect(canvas,x1:0,y1:0,x2:canvas.width-1,y2:header-1,color:img.ColorRgb8(45,106,79));
  img.drawString(canvas,'FoodLog | ${args['day']} | ${args['page']}/${args['total']}',font:img.arial48,x:gap,y:24,color:img.ColorRgb8(255,255,255));
  for(var i=0;i<paths.length;i++){
    final photo=img.decodeImage(File(paths[i]).readAsBytesSync());
    if(photo==null)throw const FormatException('Fotografia no valida');
    final scale=math.min(tile/photo.width,tile/photo.height);
    final resized=img.copyResize(photo,width:math.max(1,(photo.width*scale).round()),height:math.max(1,(photo.height*scale).round()));
    final x=gap+(i%2)*(tile+gap);
    final y=header+gap+(i~/2)*(tile+gap);
    img.fillRect(canvas,x1:x,y1:y,x2:x+tile-1,y2:y+tile-1,color:img.ColorRgb8(230,235,230));
    img.compositeImage(canvas,resized,dstX:x+(tile-resized.width)~/2,dstY:y+(tile-resized.height)~/2);
  }
  File(args['output'] as String).writeAsBytesSync(img.encodeJpg(canvas,quality:90));
}
