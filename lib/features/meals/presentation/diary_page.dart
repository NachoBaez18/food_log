import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../camera/capture_page.dart';
import '../../settings/reminder_panel.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../data/meal_store.dart';
import '../domain/meal.dart';
import '../../../core/theme_preferences.dart';
import '../../reports/report_panel.dart';
import '../../settings/backup_panel.dart';

class DiaryPage extends ConsumerStatefulWidget {
  const DiaryPage({super.key});
  @override
  ConsumerState<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends ConsumerState<DiaryPage> {
  DateTime week = monday(DateTime.now());
  bool busy = false;
  int tab = 0;
  DateTime? selectedDay;
  static DateTime monday(DateTime d) => DateTime(d.year,d.month,d.day-d.weekday+1);
  DateTime shift(int days) => DateTime(week.year,week.month,week.day+days);
  void error(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo completar: $e')));
  }
  Future<void> capture() async {
    setState(() => busy = true);
    try {
      final file = await captureMealPhoto(context);
      if (file == null || !mounted) return;
      final now = DateTime.now();
      final sources = <String>[file.path];
      final meal = await showModalBottomSheet<Meal>(context: context, isScrollControlled: true,
        builder: (_) => MealEditor(at: now, source: file.path, sources: sources));
      if (meal == null || !mounted) return;
      await ref.read(storeProvider).save(meal,sources);
      ref.invalidate(mealsProvider);
      if (mounted) setState(() => week = monday(meal.capturedAt));
    } catch(e) { error(e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> share(List<Meal> meals) async {
    try {
      final store = ref.read(storeProvider);
      final files = <XFile>[];
      for(final meal in meals.reversed){files.addAll((await store.photos(meal)).map((f)=>XFile(f.path)));}
      if (files.isNotEmpty) await Share.shareXFiles(files, text: 'Registro semanal de comidas');
    } catch(e) { error(e); }
  }
  Future<void> edit(Meal meal) async {
    final store = ref.read(storeProvider);
    final sources = await store.editSources(meal);
    if (!mounted) return;
    final updated = await showModalBottomSheet<Meal>(context: context, isScrollControlled: true,
      builder: (_) => MealEditor(at: meal.capturedAt, source: sources.first, existing: meal, sources: sources));
    if (updated != null) {
      try { await store.replacePhotos(meal,updated,sources); if(mounted){ref.invalidate(mealsProvider);setState((){week=monday(updated.capturedAt);selectedDay=null;});} } catch(e) { error(e); }
    }
  }
  Future<void> remove(Meal meal) async {
    final yes = await showDialog<bool>(context: context,builder: (ctx) => AlertDialog(
      title: const Text('Eliminar registro'), content: const Text('Se eliminarán también todas las fotografías.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx,false),child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx,true),child: const Text('Eliminar'))]));
    if (yes == true) {
      try { await ref.read(storeProvider).delete(meal); ref.invalidate(mealsProvider); } catch(e) { error(e); }
    }
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = ref.watch(mealsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('FoodLog'), actions: [IconButton(tooltip:'Semana actual',onPressed: () => setState(() {week=monday(DateTime.now());selectedDay=null;}),icon: const Icon(Icons.today))]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() { tab=i; selectedDay=null; if(i==0) week=monday(DateTime.now()); }), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined),selectedIcon: Icon(Icons.home),label:'Inicio'),NavigationDestination(icon:Icon(Icons.calendar_month),label:'Historial'),NavigationDestination(icon:Icon(Icons.description_outlined),label:'Reportes'),NavigationDestination(icon:Icon(Icons.settings_outlined),label:'Ajustes')]),
      floatingActionButton: FloatingActionButton.extended(onPressed: busy ? null : capture, icon: const Icon(Icons.camera_alt_outlined),label: const Text('Registrar comida')),
      body: data.when(loading: () => const Center(child:CircularProgressIndicator()), error: (e,_) => Center(child: TextButton(onPressed: () => ref.invalidate(mealsProvider),child: Text('Reintentar: $e'))), data: (all) {
        if(tab==3) return ListView(children:[const ListTile(title:Text('FoodLog'),subtitle:Text('Diario privado · Sin conexión')),ListTile(leading:const Icon(Icons.palette_outlined),title:const Text('Apariencia'),subtitle:const Text('Claro, oscuro o sistema'),onTap:()=>showDialog<void>(context:context,builder:(c)=>SimpleDialog(title:const Text('Apariencia'),children:ThemeMode.values.map((m)=>SimpleDialogOption(onPressed:(){ref.read(themeModeProvider.notifier).select(m).catchError((Object e)=>error(e));Navigator.pop(c);},child:Text(m==ThemeMode.system?'Sistema':m==ThemeMode.light?'Claro':'Oscuro'))).toList()))),const Divider(),const ReminderPanel(),const Divider(),const BackupPanel()]);
        final meals = all.where((m) => !m.capturedAt.isBefore(week) && m.capturedAt.isBefore(shift(7))).toList();
        if(tab==2) return ReportPanel(meals:all);
        final visible = meals.where((m)=>selectedDay==null || DateUtils.isSameDay(m.capturedAt,selectedDay)).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(16,8,16,100),children: [
          Text(tab==1?'Historial':'Mi diario',style: theme.textTheme.headlineMedium),
          const Text('Tus comidas, en un solo lugar.'),
          const SizedBox(height:16),
          if(tab==1) CalendarDatePicker(initialDate: selectedDay??week,firstDate:DateTime(2000),lastDate:DateTime(2100),onDateChanged:(d)=>setState((){week=monday(d);selectedDay=d;})),
          Card(color: theme.colorScheme.secondaryContainer,child: Padding(padding: const EdgeInsets.all(12),child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,children:[
              IconButton(onPressed: () => setState(() {week=shift(-7);selectedDay=null;}),icon: const Icon(Icons.chevron_left)),
              Text('${DateFormat('dd/MM').format(week)} – ${DateFormat('dd/MM/yyyy').format(shift(6))}',style: theme.textTheme.titleMedium),
              IconButton(onPressed: () => setState(() {week=shift(7);selectedDay=null;}),icon: const Icon(Icons.chevron_right)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,children: List.generate(7,(i) {
              final day = shift(i);
              final count = meals.where((m) => DateUtils.isSameDay(m.capturedAt,day)).length;
              return InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>setState(()=>selectedDay=DateUtils.isSameDay(selectedDay,day)?null:day),child:Padding(padding:const EdgeInsets.all(5),child:Column(children:[Text(['L','M','X','J','V','S','D'][i]),CircleAvatar(radius:16,backgroundColor:DateUtils.isSameDay(selectedDay,day)?theme.colorScheme.primary:theme.colorScheme.surface,foregroundColor:DateUtils.isSameDay(selectedDay,day)?theme.colorScheme.onPrimary:theme.colorScheme.onSurface,child:Text('${day.day}')),Icon(count>0?Icons.circle:Icons.circle_outlined,size:8)])));
            })),
            const SizedBox(height:12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,children:[Text('${meals.length} registros'),FilledButton.tonalIcon(onPressed: meals.isEmpty?null:()=>share(meals),icon: const Icon(Icons.share_outlined),label: const Text('Compartir'))])
          ]))),
          if (meals.isEmpty) const Padding(padding: EdgeInsets.all(32),child: Column(children:[Icon(Icons.restaurant_menu,size:48),SizedBox(height:12),Text('Todavía no hay comidas esta semana.')])),
          for(final meal in visible) Card(clipBehavior: Clip.antiAlias,child: Column(crossAxisAlignment: CrossAxisAlignment.start,children:[
            MealPhotos(key:ValueKey('${meal.id}-${meal.capturedAt}-${meal.type.name}-${meal.photoCount}'),meal:meal),
            ListTile(title: Text(meal.type.label),subtitle: Text('${meal.photoCount} foto(s) · ${DateFormat('dd/MM HH:mm').format(meal.capturedAt)}${meal.notes.isEmpty?'':' • ${meal.notes}'}'),
              trailing: PopupMenuButton<String>(onSelected:(v)=>v=='edit'?edit(meal):remove(meal),itemBuilder:(_)=>const [PopupMenuItem(value:'edit',child:Text('Editar')),PopupMenuItem(value:'delete',child:Text('Eliminar'))]))
          ]))
        ]);
      }),
    );
  }
}

class MealEditor extends StatefulWidget {
  const MealEditor({super.key,required this.at,required this.source,this.existing,this.sources});
  final DateTime at;
  final String source;
  final Meal? existing;
  final List<String>? sources;
  @override
  State<MealEditor> createState()=>_MealEditorState();
}
class _MealEditorState extends State<MealEditor> {
  bool taking=false;
  late DateTime at = widget.at;
  Future<void> addPhoto() async {
    setState(()=>taking=true);
    try{final file=await captureMealPhoto(context);if(file!=null&&mounted)setState(()=>widget.sources!.add(file.path));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>taking=false);}
  }
  late MealType type = widget.existing?.type ?? MealType.suggest(widget.at);
  late final notes = TextEditingController(text:widget.existing?.notes ?? '');
  @override
  void dispose(){notes.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(20,20,20,20+MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(widget.existing==null?'Registrar comida':'Editar comida',style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:12),
      SizedBox(height:160,child:ListView(scrollDirection:Axis.horizontal,children:[for(final path in widget.sources??[widget.source]) Padding(padding:const EdgeInsets.only(right:8),child:Stack(children:[ClipRRect(borderRadius:BorderRadius.circular(16),child:Image.file(File(path),height:160,width:160,fit:BoxFit.cover)),if((widget.sources?.length??0)>1)Positioned(right:0,top:0,child:IconButton.filled(onPressed:taking?null:()=>setState(()=>widget.sources!.remove(path)),icon:const Icon(Icons.close)))])),if(widget.sources!=null&&widget.sources!.length<12)OutlinedButton(onPressed:taking?null:addPhoto,child:const Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.add_a_photo),Text('Agregar foto')]))])),
      const SizedBox(height:12),
      ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.schedule),title:Text(DateFormat('dd/MM/yyyy HH:mm').format(at)),trailing:const Icon(Icons.edit_calendar),onTap:() async {final d=await showDatePicker(context:context,initialDate:at,firstDate:DateTime(2000),lastDate:DateTime(2100));if(d==null||!mounted)return;final t=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(at));if(t==null||!mounted)return;setState(()=>at=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:MealType.values.map((t)=>ChoiceChip(label:Text(t.label),selected:type==t,onSelected:(_)=>setState(()=>type=t))).toList()),
      const SizedBox(height:12),
      TextField(controller:notes,decoration:const InputDecoration(labelText:'Observaciones (opcional)',border:OutlineInputBorder()),maxLines:2),
      const SizedBox(height:16),
      SizedBox(width:double.infinity,child:FilledButton(onPressed:taking?null:()=>Navigator.pop(context,Meal(id:widget.existing?.id??widget.at.microsecondsSinceEpoch.toString(),capturedAt:at,type:type,notes:notes.text.trim(),photoCount:widget.sources?.length??widget.existing?.photoCount??1)),child:const Text('Guardar comida')))
    ]))));
}

class MealPhotos extends ConsumerWidget {
  const MealPhotos({super.key,required this.meal});
  final Meal meal;
  @override
  Widget build(BuildContext context,WidgetRef ref)=>FutureBuilder<List<File>>(future:ref.read(storeProvider).photos(meal),builder:(context,s){
    final photos=s.data;
    if(photos==null)return const SizedBox(height:190,child:Center(child:CircularProgressIndicator()));
    return SizedBox(height:190,child:PageView.builder(itemCount:photos.length,itemBuilder:(context,i)=>GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Scaffold(appBar:AppBar(title:Text('${meal.type.label} · ${i+1}/${photos.length}')),body:Center(child:InteractiveViewer(child:Image.file(photos[i])))))),child:Stack(fit:StackFit.expand,children:[Image.file(photos[i],fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Center(child:Icon(Icons.broken_image))),if(photos.length>1)Positioned(bottom:12,right:12,child:Chip(label:Text('${i+1}/${photos.length}')))]))));
  });
}
