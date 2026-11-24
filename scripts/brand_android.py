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
