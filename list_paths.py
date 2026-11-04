import os

def print_tree(start_path, prefix=""):
    entries = [e for e in os.listdir(start_path) if not e.startswith('.')]
    entries.sort()
    for i, name in enumerate(entries):
        path = os.path.join(start_path, name)
        connector = "└─ " if i == len(entries) - 1 else "├─ "
        print(prefix + connector + name)
        if os.path.isdir(path):
            new_prefix = prefix + ("   " if i == len(entries) - 1 else "│   ")
            print_tree(path, new_prefix)

root = os.path.join(os.getcwd(), "lib")
print("lib/")
print_tree(root)