import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class TourPreferences {
  static Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/foodlog-tour-v1.txt');
  static Future<bool> seen() async => (await _file()).exists();
  static Future<void> complete() async {await (await _file()).writeAsString('completed',flush:true);}
}

class _Step {
  const _Step(this.tab,this.title,this.description,this.icon);
  final int tab;
  final String title,description;
  final IconData icon;
}

class GuidedTour {
  static const steps=[
    _Step(0,'Bienvenido a FoodLog','Tu diario de comidas es privado y funciona sin conexión. Aquí encontrarás tus registros. No necesitas contar calorías ni crear una cuenta.',Icons.restaurant_menu),
    _Step(0,'Registra una comida','Pulsa Registrar comida para abrir la cámara. Confirma la foto, elige la categoría y agrega más fotos u observaciones si quieres. Después pulsa Guardar comida.',Icons.camera_alt_outlined),
    _Step(0,'Explora tu semana','Usa las flechas para cambiar de semana o toca un día para filtrar las comidas. Toca una foto para ampliarla y usa el menú de cada registro para editarlo o eliminarlo.',Icons.date_range),
    _Step(1,'Consulta el historial','En Historial puedes elegir una fecha del calendario y recuperar las comidas de ese día.',Icons.calendar_month),
    _Step(2,'Comparte con tu nutricionista','Selecciona un rango de fechas y las comidas que quieres enviar. Puedes compartir fotos individuales, collages diarios o un PDF mediante WhatsApp u otra aplicación.',Icons.share_outlined),
    _Step(3,'Personaliza la apariencia','En Ajustes puedes elegir el tema claro, oscuro o el del sistema. FoodLog recuerda tu elección.',Icons.palette_outlined),
    _Step(3,'Configura recordatorios','Activa solo los avisos que necesites y toca cada comida para cambiar su horario. Android puede retrasar las notificaciones por ahorro de batería.',Icons.notifications_outlined),
    _Step(3,'Protege tus recuerdos','Exporta una copia ZIP con tus fotos y registros y guárdala en un lugar seguro. Puedes restaurarla en otro celular sin sustituir registros existentes. Repite este tutorial desde Ajustes.',Icons.backup_outlined)
  ];

  static Future<void> run(BuildContext context,{required List<GlobalKey> keys,required ValueChanged<int> selectTab}) async {
    var index=0;
    while(context.mounted && index>=0 && index<steps.length){
      final step=steps[index];
      selectTab(step.tab);
      await WidgetsBinding.instance.endOfFrame;
      if(!context.mounted)return;
      final target=keys[index].currentContext;
      if(target!=null){
        await Scrollable.ensureVisible(target,duration:const Duration(milliseconds:250),alignment:0.25);
        await WidgetsBinding.instance.endOfFrame;
      }
      if(!context.mounted)return;
      Rect? rect;
      final render=keys[index].currentContext?.findRenderObject();
      if(render is RenderBox && render.attached && render.hasSize){
        final overlay=Overlay.of(context,rootOverlay:true).context.findRenderObject();
        if(overlay is RenderBox){
          rect=render.localToGlobal(Offset.zero,ancestor:overlay)&render.size;
        }
      }
      final result=await showGeneralDialog<int>(context:context,barrierDismissible:false,barrierLabel:'Tutorial FoodLog',barrierColor:Colors.transparent,transitionDuration:const Duration(milliseconds:140),pageBuilder:(c,_,__)=>_TourOverlay(step:step,index:index,total:steps.length,target:rect));
      if(result==null || result==0)break;
      index+=result;
    }
    if(context.mounted)selectTab(0);
  }
}

class _TourOverlay extends StatelessWidget {
  const _TourOverlay({required this.step,required this.index,required this.total,required this.target});
  final _Step step;
  final int index,total;
  final Rect? target;
  @override
  Widget build(BuildContext context){
    final theme=Theme.of(context);
    return Material(type:MaterialType.transparency,child:LayoutBuilder(builder:(context,limits){
      final bounds=Offset.zero & Size(limits.maxWidth,limits.maxHeight);
      final safe=MediaQuery.paddingOf(context);
      final hole=target?.inflate(6).intersect(bounds)??Rect.zero;
      final valid=!hole.isEmpty;
      final below=valid?bounds.height-hole.bottom-safe.bottom:0.0;
      final above=valid?hole.top-safe.top:0.0;
      final placeBelow=below>=above;
      final available=valid?math.max(below,above):bounds.height-safe.top-safe.bottom;
      final dock=available<240;
      return Stack(children:[
        Positioned.fill(child:CustomPaint(painter:_Spotlight(valid?hole:null))),
        Positioned(left:16,right:16,top:!dock&&valid&&placeBelow?hole.bottom+12:!dock&&valid?null:safe.top+12,bottom:!dock&&valid&&!placeBelow?bounds.height-hole.top+12:null,
          child:ConstrainedBox(constraints:BoxConstraints(maxHeight:math.max(100.0,dock?bounds.height-safe.top-safe.bottom-24:available-24)),child:Card(elevation:8,child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Icon(step.icon,color:theme.colorScheme.primary),const SizedBox(width:8),Expanded(child:Text('Paso ${index+1} de $total',style:theme.textTheme.labelLarge)),TextButton(onPressed:()=>Navigator.pop(context,0),child:const Text('Omitir'))]),
            LinearProgressIndicator(value:(index+1)/total),
            const SizedBox(height:14),
            Text(step.title,style:theme.textTheme.titleLarge),
            const SizedBox(height:8),
            Text(step.description),
            const SizedBox(height:16),
            Row(children:[if(index>0)TextButton(onPressed:()=>Navigator.pop(context,-1),child:const Text('Anterior')),const Spacer(),FilledButton(onPressed:()=>Navigator.pop(context,1),child:Text(index==total-1?'Finalizar':'Siguiente'))])
          ])))))
      ]);
    }));
  }
}

class _Spotlight extends CustomPainter{
  const _Spotlight(this.target);
  final Rect? target;
  @override
  void paint(Canvas canvas,Size size){
    final path=Path()..fillType=PathFillType.evenOdd;
    path.addRect(Offset.zero&size);
    if(target!=null)path.addRRect(RRect.fromRectAndRadius(target!,const Radius.circular(16)));
    canvas.drawPath(path,Paint()..color=Colors.black.withValues(alpha:0.65));
    if(target!=null)canvas.drawRRect(RRect.fromRectAndRadius(target!,const Radius.circular(16)),Paint()..color=const Color(0xff95d5b2)..style=PaintingStyle.stroke..strokeWidth=3);
  }
  @override
  bool shouldRepaint(covariant _Spotlight oldDelegate)=>oldDelegate.target!=target;
}
