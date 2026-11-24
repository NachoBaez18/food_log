import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReminderPanel extends StatefulWidget {
  const ReminderPanel({super.key});
  @override
  State<ReminderPanel> createState()=>_ReminderPanelState();
}
class _ReminderPanelState extends State<ReminderPanel>{
  static const channel=MethodChannel('foodlog/reminders');
  static const labels=['Desayuno','Almuerzo','Merienda','Cena'];
  final hours=[7,12,16,20];
  final minutes=[0,0,0,0];
  final enabled=[false,false,false,false];
  bool busy=true;
  @override
  void initState(){super.initState();load();}
  Future<void> load() async{
    try{
      final values=await channel.invokeMethod<List<dynamic>>('list');
      if(!mounted)return;
      if(values!=null)for(var i=0;i<4;i++){final m=Map<String,dynamic>.from(values[i] as Map);hours[i]=m['hour'] as int;minutes[i]=m['minute'] as int;enabled[i]=m['enabled'] as bool;}
    }catch(e){message(e);}
    finally{if(mounted)setState(()=>busy=false);}
  }
  void message(Object e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}
  Future<void> save(int i,bool active,TimeOfDay time)async{
    setState(()=>busy=true);
    try{
      final ok=await channel.invokeMethod<bool>('save',{'id':i,'enabled':active,'hour':time.hour,'minute':time.minute});
      if(ok!=true){message('Permite las notificaciones de FoodLog para activar recordatorios.');return;}
      if(mounted)setState((){enabled[i]=active;hours[i]=time.hour;minutes[i]=time.minute;});
    }catch(e){message(e);}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    const Padding(padding:EdgeInsets.fromLTRB(16,12,16,0),child:Text('Recordatorios diarios',style:TextStyle(fontWeight:FontWeight.bold))),
    const Padding(padding:EdgeInsets.symmetric(horizontal:16),child:Text('Opcionales. Android puede retrasar el aviso para ahorrar batería.')),
    for(var i=0;i<4;i++)ListTile(leading:const Icon(Icons.notifications_outlined),title:Text(labels[i]),subtitle:Text(TimeOfDay(hour:hours[i],minute:minutes[i]).format(context)),onTap:busy?null:()async{final time=await showTimePicker(context:context,initialTime:TimeOfDay(hour:hours[i],minute:minutes[i]));if(time!=null&&mounted)await save(i,enabled[i],time);},trailing:Switch(value:enabled[i],onChanged:busy?null:(v)=>save(i,v,TimeOfDay(hour:hours[i],minute:minutes[i])))),
    if(busy)const LinearProgressIndicator()
  ]);
}
