package com.foodlog.foodlog

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import java.util.Calendar

object Reminders {
    val labels = arrayOf("Desayuno", "Almuerzo", "Merienda", "Cena")
    val defaults = intArrayOf(7,12,16,20)
    fun prefs(c: Context) = c.getSharedPreferences("meal_reminders",Context.MODE_PRIVATE)
    fun pending(c: Context,id:Int):PendingIntent = PendingIntent.getBroadcast(c,id,Intent(c,ReminderReceiver::class.java).putExtra("id",id),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun schedule(c:Context,id:Int){
        val p=prefs(c)
        val alarm=c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.cancel(pending(c,id))
        if(!p.getBoolean("enabled$id",false))return
        val time=Calendar.getInstance().apply{
            set(Calendar.HOUR_OF_DAY,p.getInt("hour$id",defaults[id]))
            set(Calendar.MINUTE,p.getInt("minute$id",0))
            set(Calendar.SECOND,0);set(Calendar.MILLISECOND,0)
            if(timeInMillis<=System.currentTimeMillis())add(Calendar.DAY_OF_YEAR,1)
        }
        alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,time.timeInMillis,pending(c,id))
    }
}
class ReminderReceiver:BroadcastReceiver(){
    override fun onReceive(c:Context,intent:Intent){
        val id=intent.getIntExtra("id",-1)
        if(id !in 0..3)return
        if(!Reminders.prefs(c).getBoolean("enabled$id",false))return
        Reminders.schedule(c,id)
        if(Build.VERSION.SDK_INT>=33&&c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return
        val manager=c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if(Build.VERSION.SDK_INT>=26)manager.createNotificationChannel(NotificationChannel("meals","Recordatorios de comidas",NotificationManager.IMPORTANCE_DEFAULT))
        val launch=c.packageManager.getLaunchIntentForPackage(c.packageName) ?: return
        val action=PendingIntent.getActivity(c,id,launch,PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder=if(Build.VERSION.SDK_INT>=26)Notification.Builder(c,"meals") else Notification.Builder(c)
        manager.notify(id,builder.setSmallIcon(android.R.drawable.ic_menu_camera).setContentTitle(Reminders.labels[id]).setContentText("Registra tu comida en FoodLog").setContentIntent(action).setAutoCancel(true).build())
    }
}
class ReminderBootReceiver:BroadcastReceiver(){
    override fun onReceive(c:Context,intent:Intent){for(id in 0..3)Reminders.schedule(c,id)}
}
