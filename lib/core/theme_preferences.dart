import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final themeModeProvider = StateNotifierProvider<ThemePreferences, ThemeMode>((ref) => ThemePreferences());

class ThemePreferences extends StateNotifier<ThemeMode> {
  ThemePreferences():super(ThemeMode.system){_load();}
  bool _changed=false;
  Future<File> _file() async => File('${(await getApplicationDocumentsDirectory()).path}/theme.txt');
  Future<void> _load() async {
    try {
      final file=await _file();
      if(await file.exists()){
        final value=ThemeMode.values.byName((await file.readAsString()).trim());
        if(mounted&&!_changed) state=value;
      }
    }catch(_){}
  }
  Future<void> select(ThemeMode value) async {
    _changed=true;
    state=value;
    await (await _file()).writeAsString(value.name,flush:true);
  }
}
