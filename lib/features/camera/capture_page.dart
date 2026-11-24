import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

Future<XFile?> captureMealPhoto(BuildContext context) =>
    Navigator.of(context).push<XFile>(MaterialPageRoute(builder: (_) => const CapturePage()));

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});
  @override
  State<CapturePage> createState() => _CapturePageState();
}
class _CapturePageState extends State<CapturePage> with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras=[];
  int index=0;
  int generation=0;
  bool busy=false;
  bool flash=false;
  XFile? photo;
  String? error;
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_open();}
  Future<void> _open() async {
    final token=++generation;
    final old=controller;
    controller=null;
    if(mounted)setState((){error=null;flash=false;});
    await old?.dispose();
    CameraController? next;
    try{
      if(cameras.isEmpty){
        cameras=await availableCameras();
        final back=cameras.indexWhere((c)=>c.lensDirection==CameraLensDirection.back);
        if(back>=0)index=back;
      }
      if(cameras.isEmpty)throw StateError('No hay cámaras disponibles');
      if(!mounted||token!=generation)return;
      next=CameraController(cameras[index],ResolutionPreset.high,enableAudio:false);
      await next.initialize();
      if(!mounted||token!=generation){await next.dispose();return;}
      setState(()=>controller=next);
    }catch(e){await next?.dispose();if(mounted&&token==generation)setState(()=>error=e.toString());}
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.inactive||state==AppLifecycleState.paused){
      generation++;final old=controller;controller=null;old?.dispose();
      if(mounted)setState((){});
    }else if(state==AppLifecycleState.resumed&&photo==null&&!busy){_open();}
  }
  @override
  void dispose(){generation++;WidgetsBinding.instance.removeObserver(this);controller?.dispose();super.dispose();}
  Future<void> take() async {
    final c=controller;
    if(c==null||busy)return;
    setState(()=>busy=true);
    try{final file=await c.takePicture();if(mounted)setState(()=>photo=file);}
    catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> fallback() async {
    try{final file=await ImagePicker().pickImage(source:ImageSource.camera);if(mounted&&file!=null)Navigator.pop(context,file);else if(mounted)_open();}
    catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  @override
  Widget build(BuildContext context){
    final c=controller;
    return Scaffold(backgroundColor:Colors.black,appBar:AppBar(backgroundColor:Colors.black,foregroundColor:Colors.white,title:const Text('Fotografiar comida'),actions:[
      if(photo==null&&c!=null)IconButton(tooltip:'Flash',onPressed:busy?null:()async{try{await c.setFlashMode(flash?FlashMode.off:FlashMode.torch);if(mounted)setState(()=>flash=!flash);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Flash no disponible')));}},icon:Icon(flash?Icons.flash_on:Icons.flash_off)),
      if(photo==null&&cameras.length>1)IconButton(tooltip:'Cambiar cámara',onPressed:busy?null:(){index=(index+1)%cameras.length;_open();},icon:const Icon(Icons.cameraswitch))
    ]),body:SafeArea(child:Column(children:[
      Expanded(child:Center(child:photo!=null?Image.file(File(photo!.path),fit:BoxFit.contain):error!=null?Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Text('No se pudo abrir la cámara integrada.',style:TextStyle(color:Colors.white)),const SizedBox(height:12),FilledButton(onPressed:_open,child:const Text('Reintentar')),TextButton(onPressed:fallback,child:const Text('Usar cámara del sistema'))])):c==null?const CircularProgressIndicator():CameraPreview(c))),
      Padding(padding:const EdgeInsets.all(24),child:photo!=null?Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[OutlinedButton(onPressed:(){final old=photo;setState(()=>photo=null);if(old!=null)File(old.path).delete().catchError((Object _)=>File(old.path));if(controller==null)_open();},child:const Text('Repetir')),FilledButton.icon(onPressed:()=>Navigator.pop(context,photo),icon:const Icon(Icons.check),label:const Text('Usar foto'))]):IconButton.filled(iconSize:42,onPressed:c==null||busy?null:take,icon:const Icon(Icons.camera_alt)))
    ])));
  }
}
