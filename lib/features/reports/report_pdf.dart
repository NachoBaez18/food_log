import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../meals/data/meal_store.dart';
import '../meals/domain/meal.dart';

class ReportPdf {
  ReportPdf(this.store);
  final MealStore store;
  Future<File> create(List<Meal> meals) async {
    final document=pw.Document();
    final ordered=[...meals]..sort((a,b)=>a.capturedAt.compareTo(b.capturedAt));
    final fmt=DateFormat('dd/MM/yyyy HH:mm');
    for(final meal in ordered){
      final files=await store.photos(meal);
      for(var offset=0;offset<files.length;offset+=4){
        final pictures=<pw.MemoryImage>[];
        for(final file in files.skip(offset).take(4)){pictures.add(pw.MemoryImage(await file.readAsBytes()));}
        document.addPage(pw.Page(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(32),build:(_)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
          pw.Container(width:double.infinity,padding:const pw.EdgeInsets.all(16),color:PdfColor.fromHex('#2D6A4F'),child:pw.Text('FoodLog | Diario de comidas',style:pw.TextStyle(color:PdfColors.white,fontSize:20,fontWeight:pw.FontWeight.bold))),
          pw.SizedBox(height:16),
          pw.Text(meal.type.label,style:pw.TextStyle(fontSize:20,fontWeight:pw.FontWeight.bold)),
          pw.Text(fmt.format(meal.capturedAt)),
          if(meal.notes.isNotEmpty)pw.Padding(padding:const pw.EdgeInsets.symmetric(vertical:8),child:pw.Text(meal.notes.length>500?meal.notes.substring(0,500):meal.notes,maxLines:5)),
          pw.SizedBox(height:12),
          pw.Wrap(spacing:10,runSpacing:10,children:[for(final picture in pictures)pw.Container(width:255,height:220,color:PdfColors.grey100,child:pw.Image(picture,fit:pw.BoxFit.contain))]),
          pw.Spacer(),
          pw.Text('Fotos ${offset+1}-${offset+pictures.length} de ${files.length}',style:const pw.TextStyle(fontSize:10))
        ])));
      }
    }
    final dir=await (await getTemporaryDirectory()).createTemp('foodlog-pdf-');
    final file=File('${dir.path}/foodlog-reporte.pdf');
    await file.writeAsBytes(await document.save());
    return file;
  }
}
