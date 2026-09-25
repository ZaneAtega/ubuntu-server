import json

with open("gitignore/etc.json", encoding="utf-8") as f:
    values = json.loads("\n".join(line.split("//", 1)[0] for line in f))

with open("etc.sh", encoding="utf-8") as f:
    lines = f.readlines()

with open("etc_ready.sh", 'w', encoding="utf-8") as f:
    for line in lines:
        for prefix, value in values.items():
            if line.lstrip().startswith(prefix):
                line = f"{line.split('=')[0]}={value}\n"
                break

        f.write(line)