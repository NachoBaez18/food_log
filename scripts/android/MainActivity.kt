package com.foodlog.foodlog

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity:FlutterActivity(){
    private var pendingResult:MethodChannel.Result?=null
    private var pendingArgs:Map<String,Any>?=null
    override fun configureFlutterEngine(engine:FlutterEngine){
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger,"foodlog/reminders").setMethodCallHandler{call,result->
            when(call.method){
                "list"->{
                    val p=Reminders.prefs(this)
                    result.success((0..3).map{i->mapOf("enabled" to p.getBoolean("enabled$i",false),"hour" to p.getInt("hour$i",Reminders.defaults[i]),"minute" to p.getInt("minute$i",0))})
                }
                "save"->{
                    val id=call.argument<Int>("id") ?: -1
                    val hour=call.argument<Int>("hour") ?: -1
                    val minute=call.argument<Int>("minute") ?: -1
                    val enabled=call.argument<Boolean>("enabled") ?: false
                    if(id !in 0..3||hour !in 0..23||minute !in 0..59){result.error("invalid","Horario no válido",null)}
                    else if(enabled&&Build.VERSION.SDK_INT>=33&&checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED){
                        if(pendingResult!=null){result.error("busy","Permiso pendiente",null)}
                        else{pendingResult=result;pendingArgs=mapOf("id" to id,"hour" to hour,"minute" to minute,"enabled" to enabled);requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),701)}
                    }else{save(id,hour,minute,enabled);result.success(true)}
                }
                else->result.notImplemented()
            }
        }
    }
    private fun save(id:Int,hour:Int,minute:Int,enabled:Boolean){
        Reminders.prefs(this).edit().putInt("hour$id",hour).putInt("minute$id",minute).putBoolean("enabled$id",enabled).apply()
        Reminders.schedule(this,id)
    }
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray){
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
        if(requestCode==701){
            val args=pendingArgs;val result=pendingResult;pendingArgs=null;pendingResult=null
            val granted=grantResults.firstOrNull()==PackageManager.PERMISSION_GRANTED
            if(granted&&args!=null)save(args["id"] as Int,args["hour"] as Int,args["minute"] as Int,args["enabled"] as Boolean)
            result?.success(granted)
        }
    }
}
