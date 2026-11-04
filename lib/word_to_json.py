# -*- coding: utf-8 -*-
import sys
import os
import json
import re
from docx import Document
from docx.oxml.ns import qn

ARABIC_DIGITS = '٠١٢٣٤٥٦٧٨٩'
EN_DIGITS = '0123456789'
AR2EN = str.maketrans(ARABIC_DIGITS, EN_DIGITS)
EN2AR = str.maketrans(EN_DIGITS, EN_DIGITS)

SECTION_KEYWORDS = ('الكتاب', 'الباب', 'الفصل', 'الفرع', 'الجزء', 'القسم')
DOT_CHARS = r'\.\u06D4\uFF0E\uFE52'
DOT_CLASS = f'[{DOT_CHARS}]'

def arabic_to_en_digits(s):
    if not s: return ""
    return s.translate(AR2EN)

def en_to_ar_digits(s): 
    return s.translate(EN2AR)

def normalize_line(t):
    t = t.replace('\u200f', '').replace('\u202c', '').replace('\u202d', '').strip()
    t = re.sub(r'\s+', ' ', t)
    t = re.sub(r'^ه\s*-\s*', 'هـ - ', t)
    return t

def get_paragraph_text(p):
    return normalize_line(''.join(run.text for run in p.runs))

def ensure_final_dot(text):
    text = text.rstrip()
    text = re.sub(r'\s+([%s])$' % DOT_CHARS, r'\1', text)
    if not re.search(DOT_CLASS + r'$', text):
        text += '.'
    return text

def is_section_title(line):
    return any(line.startswith(kw) for kw in SECTION_KEYWORDS)

ARTICLE_RE = re.compile(
    r'^\s*(?:المادة|مادة)\s*[\(（]?\s*([0-9%s]+(?:\s*مكرر)?)\s*[\)）]?' % ARABIC_DIGITS
)

def extract_article_number(line):
    m = re.match(r'^\s*(?:المادة|مادة)\s*[\(（]?\s*([^)）]+)\s*[\)）]?', line)
    if not m: 
        return None
    raw = m.group(1).strip()
    num_digits = re.match(r'^([0-9%s]+)' % ARABIC_DIGITS, raw)
    if not num_digits: 
        return None
    try:
        return int(arabic_to_en_digits(num_digits.group(1))), raw
    except:
        return None

def collect_section_title(pars, start_idx):
    title_lines, i = [], start_idx
    while i < len(pars):
        txt = get_paragraph_text(pars[i])
        if not txt or ARTICLE_RE.match(txt): 
            break
        if not title_lines and not is_section_title(txt): 
            break
        title_lines.append(txt)
        i += 1
    return ' '.join(title_lines), i

def finalize_text(lines):
    return ensure_final_dot('\n'.join(lines).strip())

def extract_preamble(pars):
    pre_lines = []
    for p in pars:
        txt = get_paragraph_text(p)
        if not txt: 
            continue
        if ARTICLE_RE.match(txt) or is_section_title(txt): 
            break
        pre_lines.append(txt)
    return {"type": "preamble", "text": '\n'.join(pre_lines).strip()} if pre_lines else None

def extract_intro_section(pars, start_idx):
    for i in range(start_idx, len(pars)):
        txt = get_paragraph_text(pars[i])
        if not txt: 
            continue
        if txt.strip() == "باب تمهيدي":
            return {"type": "section", "level": "باب", "title": "باب تمهيدي"}, i + 1
        if ARTICLE_RE.match(txt): 
            break
    return None, start_idx

def extract_conclusion(pars):
    concl_lines = []
    for p in reversed(pars):
        txt = get_paragraph_text(p)
        if not txt: 
            continue
        if any(x in txt for x in ["رئيس الجمهورية", "رئيس مجلس الرئاسة", "صدر برئاسة الجمهورية"]):
            concl_lines.insert(0, txt)
            continue
        if ARTICLE_RE.match(txt) or is_section_title(txt): 
            break
        concl_lines.insert(0, txt)
    return {"type": "conclusion", "text": '\n'.join(concl_lines).strip()} if concl_lines else None

# ===================== إضافة: العناوين الجانبية =====================
def is_side_title_candidate(line):
    if not line:
        return False
    clean = re.sub(r'(\s*[:：]\-?|\s*\.)$', '', line).strip()
    words = clean.split()
    if len(words) == 0 or len(words) > 5:
        return False
    if is_section_title(clean):
        return False
    if ARTICLE_RE.match(clean):
        return False
    return True
# ===================== نهاية الإضافة =====================

# ===================== إضافة: استخراج الجداول =====================
def extract_table_text(tbl):
    lines = []
    for row in tbl.rows:
        cells = [normalize_line(cell.text) for cell in row.cells if cell.text.strip()]
        if cells:
            lines.append(' | '.join(cells))
    return lines
# ===================== نهاية الإضافة =====================

def iter_body_elements(doc):
    for child in doc.element.body:
        if child.tag == qn('w:p'):
            yield ('p', child)
        elif child.tag == qn('w:tbl'):
            yield ('tbl', child)

def parse_docx_to_items(docx_path):
    doc = Document(docx_path)
    items = []

    pars = doc.paragraphs
    preamble = extract_preamble(pars)
    if preamble:
        items.append(preamble)

    intro_section, start_i = extract_intro_section(pars, len(items))
    if intro_section:
        items.append(intro_section)

    conclusion = extract_conclusion(pars)
    conclusion_lines = conclusion["text"].split('\n') if conclusion else []

    current_article = None
    current_text_lines = []

    for typ, elem in iter_body_elements(doc):

        if typ == 'p':
            line = normalize_line(''.join(t.text for t in elem.xpath('.//w:t') if t.text))
            if not line:
                continue

            if current_article and is_side_title_candidate(line):
                items.append(current_article | {"text": finalize_text(current_text_lines)})
                current_article = None
                current_text_lines = []
                items.append({"type": "side_title", "text": f"*** {line} ***"})
                continue

            num_info = extract_article_number(line)
            if num_info:
                if current_article:
                    items.append(current_article | {"text": finalize_text(current_text_lines)})
                    current_text_lines = []
                en_num, raw_num = num_info
                current_article = {"type": "article", "article_number": en_num, "num": raw_num}
                after = ARTICLE_RE.sub('', line, count=1).strip()
                if after:
                    current_text_lines.append(after)
                continue

            if current_article:
                current_text_lines.append(line)

        elif typ == 'tbl' and current_article:
            table = Document().add_table(rows=0, cols=0)
            table._element = elem
            current_text_lines.extend(extract_table_text(table))

    if current_article:
        filtered_lines = [l for l in current_text_lines if l not in conclusion_lines]
        items.append(current_article | {"text": finalize_text(filtered_lines)})

    if conclusion:
        items.append(conclusion)

    return items

def process_folder_recursive(base_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    for root, _, files in os.walk(base_dir):
        for name in files:
            if not name.lower().endswith('.docx') or name.startswith('~$'):
                continue
            src = os.path.join(root, name)
            try:
                items = parse_docx_to_items(src)
                out_path = os.path.join(output_dir, f"{os.path.splitext(name)[0]}.json")
                with open(out_path, 'w', encoding='utf-8') as f:
                    json.dump(items, f, ensure_ascii=False, indent=2)
                print(f"تم بنجاح: {name}")
            except Exception as e:
                print(f"خطأ في {name}: {e}")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(script_dir, "output_json")
    process_folder_recursive(script_dir, output_dir)
    input("تم الانتهاء.. اضغط Enter للإغلاق...")
