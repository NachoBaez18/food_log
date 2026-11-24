from pathlib import Path
from PIL import Image, ImageDraw
import xml.etree.ElementTree as ET

res = Path('android/app/src/main/res')
for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
    im = Image.new('RGB',(1024,1024),'#2D6A4F')
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((205,340,819,770),radius=90,outline='white',width=38)
    d.rounded_rectangle((390,260,634,365),radius=35,fill='white')
    d.ellipse((365,405,659,699),outline='white',width=29)
    d.polygon([(510,620),(447,575),(449,511),(508,460),(620,446),(615,529),(577,589)],fill='#95D5B2')
    d.line([(470,651),(570,500)],fill='#2D6A4F',width=17)
    folder=res / ('mipmap-'+density)
    folder.mkdir(parents=True,exist_ok=True)
    im.resize((size,size),Image.Resampling.LANCZOS).save(folder/'ic_launcher.png')
    im.resize((size,size),Image.Resampling.LANCZOS).save(folder/'ic_launcher_round.png')
manifest=Path('android/app/src/main/AndroidManifest.xml')
ET.register_namespace('android','http://schemas.android.com/apk/res/android')
tree=ET.parse(manifest)
app=tree.getroot().find('application')
app.set('{http://schemas.android.com/apk/res/android}label','FoodLog')
tree.write(manifest,encoding='utf-8',xml_declaration=True)

# Preserve Flutter's launch theme and customize only its background.
for folder in ['drawable','drawable-v21']:
    target=res / folder
    target.mkdir(parents=True,exist_ok=True)
    (target/'launch_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/foodlog_splash" />
    <item><bitmap android:gravity="center" android:src="@mipmap/ic_launcher" /></item>
</layer-list>''',encoding='utf-8')
for folder in ['values','values-night']:
    target=res / folder
    target.mkdir(parents=True,exist_ok=True)
    (target/'foodlog_colors.xml').write_text('<resources><color name="foodlog_splash">#2D6A4F</color></resources>',encoding='utf-8')
for folder in ['values-v31','values-night-v31']:
    target=res / folder
    target.mkdir(parents=True,exist_ok=True)
    styles=target/'styles.xml'
    if styles.exists():
        tree=ET.parse(styles)
        root=tree.getroot()
    else:
        root=ET.Element('resources')
        tree=ET.ElementTree(root)
    style=next((s for s in root.findall('style') if s.get('name')=='LaunchTheme'),None)
    if style is None:
        style=ET.SubElement(root,'style',{'name':'LaunchTheme','parent':'@android:style/Theme.Light.NoTitleBar'})
    for name,value in [('android:windowSplashScreenBackground','@color/foodlog_splash'),('android:windowSplashScreenAnimatedIcon','@mipmap/ic_launcher'),('android:windowBackground','@drawable/launch_background')]:
        item=next((x for x in style.findall('item') if x.get('name')==name),None)
        if item is None:
            item=ET.SubElement(style,'item',{'name':name})
        item.text=value
    tree.write(styles,encoding='utf-8',xml_declaration=True)

# Install native, offline reminder integration into the generated Android scaffold.
import shutil
android_ns='{http://schemas.android.com/apk/res/android}'
tree=ET.parse(manifest)
root=tree.getroot()
app=root.find('application')
for permission in ['android.permission.CAMERA','android.permission.POST_NOTIFICATIONS','android.permission.RECEIVE_BOOT_COMPLETED']:
    if not any(e.get(android_ns+'name')==permission for e in root.findall('uses-permission')):
        root.insert(0,ET.Element('uses-permission',{android_ns+'name':permission}))
for name in ['.ReminderReceiver','.ReminderBootReceiver']:
    if not any(e.get(android_ns+'name')==name for e in app.findall('receiver')):
        receiver=ET.SubElement(app,'receiver',{android_ns+'name':name,android_ns+'exported':'false'})
        if name.endswith('BootReceiver'):
            f=ET.SubElement(receiver,'intent-filter')
            for action in ['android.intent.action.BOOT_COMPLETED','android.intent.action.TIME_SET','android.intent.action.TIMEZONE_CHANGED','android.intent.action.MY_PACKAGE_REPLACED']:
                ET.SubElement(f,'action',{android_ns+'name':action})
tree.write(manifest,encoding='utf-8',xml_declaration=True)
target=Path('android/app/src/main/kotlin/com/foodlog/foodlog')
target.mkdir(parents=True,exist_ok=True)
for source in Path('scripts/android').glob('*.kt'):
    shutil.copyfile(source,target/source.name)
