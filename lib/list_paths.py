import os

def print_tree(start_path, prefix=""):
    entries = [e for e in os.listdir(start_path) if not e.startswith('.')]
    entries = [e for e in entries if not e.startswith('__pycache__')]
    entries.sort()
    for i, entry in enumerate(entries):
        path = os.path.join(start_path, entry)
        connector = "└─ " if i == len(entries) - 1 else "├─ "
        print(prefix + connector + entry)
        if os.path.isdir(path):
            extension = "    " if i == len(entries) - 1 else "│   "
            print_tree(path, prefix + extension)

# المسار الصحيح فعلياً
root = r"C:\Users\user\laws_yemen\lib"
print("lib/")
print_tree(root)