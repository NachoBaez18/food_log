import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../meals/data/meal_store.dart';
import '../meals/domain/meal.dart';

class ReportPanel extends ConsumerStatefulWidget {
  const ReportPanel({super.key,required this.meals});
  final List<Meal> meals;
  @override
  ConsumerState<ReportPanel> createState()=>_ReportPanelState();
}
class _ReportPanelState extends ConsumerState<ReportPanel> {
  late DateTimeRange range = DateTimeRange(start: DateUtils.dateOnly(DateTime.now()).subtract(Duration(days:DateTime.now().weekday-1)),end:DateUtils.dateOnly(DateTime.now()));
  final excluded=<String>{};
  bool busy=false;
  @override
  Widget build(BuildContext context) {
    final meals=widget.meals.where((m)=>!DateUtils.dateOnly(m.capturedAt).isBefore(range.start)&&!DateUtils.dateOnly(m.capturedAt).isAfter(range.end)).toList();
    final selected=meals.where((m)=>!excluded.contains(m.id)).toList();
    final fmt=DateFormat('dd/MM/yyyy');
    return ListView(padding:const EdgeInsets.fromLTRB(16,16,16,110),children:[
      Text('Reportes',style:Theme.of(context).textTheme.headlineMedium),
      const Text('Elige las comidas que deseas compartir.'),
      const SizedBox(height:16),
      OutlinedButton.icon(onPressed:()async{final value=await showDateRangePicker(context:context,firstDate:DateTime(2000),lastDate:DateTime(2100),initialDateRange:range);if(value!=null&&mounted)setState((){range=value;excluded.clear();});},icon:const Icon(Icons.date_range),label:Text('${fmt.format(range.start)} – ${fmt.format(range.end)}')),
      Row(children:[Expanded(child:Text('${selected.length} seleccionados')),TextButton(onPressed:()=>setState(()=>excluded.clear()),child:const Text('Todos')),TextButton(onPressed:()=>setState(()=>excluded.addAll(meals.map((m)=>m.id))),child:const Text('Ninguno'))]),
      if(meals.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('No hay registros en este período.')),
      for(final meal in meals)CheckboxListTile(value:!excluded.contains(meal.id),title:Text(meal.type.label),subtitle:Text(DateFormat('dd/MM/yyyy HH:mm').format(meal.capturedAt)),onChanged:(v)=>setState((){if(v==true){excluded.remove(meal.id);}else{excluded.add(meal.id);}})),
      FilledButton.icon(onPressed:selected.isEmpty||busy?null:()async{setState(()=>busy=true);try{final store=ref.read(storeProvider);final files=<XFile>[];for(final meal in selected.reversed){files.addAll((await store.photos(meal)).map((f)=>XFile(f.path)));}await Share.shareXFiles(files,text:'Registro de comidas · ${fmt.format(range.start)} – ${fmt.format(range.end)}');}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('No se pudo compartir: $e')));}finally{if(mounted)setState(()=>busy=false);}},icon:const Icon(Icons.share),label:const Text('Compartir fotografías'))
    ]);
  }
}
