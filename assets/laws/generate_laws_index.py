import os
import json

# حدد مسار مجلد القوانين تلقائياً بناءً على مكان السكريبت نفسه
directory = os.path.dirname(os.path.abspath(__file__))

# اجمع جميع الملفات بصيغة json ماعدا ملف index نفسه
files = [
    f for f in os.listdir(directory)
    if f.endswith('.json') and f != 'laws_index.json'
]

# أنشئ أو حدث ملف index بالقائمة الجديدة
with open(os.path.join(directory, 'laws_index.json'), 'w', encoding='utf-8') as f:
    json.dump(files, f, ensure_ascii=False, indent=2)

print('تم توليد ملف laws_index.json ويحتوي على الملفات التالية:')
print(files)