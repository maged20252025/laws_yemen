import os

# الحصول على مسار المجلد الذي يوجد فيه السكربت نفسه
current_dir = os.path.dirname(os.path.abspath(__file__))

# اسم ملف الإخراج
output_file = os.path.join(current_dir, "list.txt")

with open(output_file, "w", encoding="utf-8") as f:
    for root, dirs, files in os.walk(current_dir):
        # كتابة اسم المجلد الحالي
        f.write(f"\n📁 المجلد: {root}\n")

        # كتابة أسماء المجلدات الفرعية
        for d in dirs:
            f.write(f"   📂 {d}\n")

        # كتابة أسماء الملفات
        for file in files:
            # تجاهل السكربت نفسه وملف الإخراج
            if file not in ["list.py", "list.txt"]:
                f.write(f"   📄 {file}\n")

print("تم استخراج جميع الأسماء بنجاح داخل ملف list.txt")
input("اضغط Enter للخروج...")