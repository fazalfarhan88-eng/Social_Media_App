import json

with open('ai_models/app.py', 'r', encoding='utf-8') as f:
    app_py_lines = f.readlines()

app_py_cell_source = ["%%writefile app.py\n"] + app_py_lines

# Read UTF-16 because PowerShell > outputs UTF-16
with open('ai_models/AI_Models_Colab_Old.ipynb', 'r', encoding='utf-16') as f:
    old_data = json.load(f)

for cell in old_data['cells']:
    if cell.get('cell_type') == 'code':
        if len(cell['source']) > 0 and cell['source'][0].startswith('%%writefile app.py'):
            cell['source'] = app_py_cell_source
            break

with open('ai_models/AI_Models_Colab.ipynb', 'w', encoding='utf-8') as f:
    json.dump(old_data, f, indent=1)

