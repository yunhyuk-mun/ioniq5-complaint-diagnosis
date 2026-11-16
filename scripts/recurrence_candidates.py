"""3단계: 리콜·수리 후 재발 후보 추출. 판정은 labels/recurrence_labels.csv에 신고 번호(odi)로 기록한다."""
import csv, re, os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = list(csv.DictReader(open(os.path.join(BASE, 'results', 'complaints_labeled.csv'), encoding='utf-8-sig')))
ic = [r for r in rows if r['ICCU'] == 'True']
FIX = r'(recall|campaign|\b997\b|tsb|bulletin|software update|update)'
DONE = re.compile(FIX + r'.{0,80}\b(performed|completed|done|applied|installed|finished)\b|\b(had|got|received|completed|performed|did|after)\b( the| all| its| a)?.{0,25}' + FIX, re.I)
REP = re.compile(r'\b(second|2nd|third|3rd|fourth|4th)\b.{0,20}(time|iccu|failure|fail)|\bagain\b|\btwice\b|another iccu|re-?occur|recur|replaced.{0,60}(before|previously|already|last (year|month)|months? ago)', re.I)
out = []
for r in ic:
    t = r['summary']; hits = [m.span() for p in (DONE, REP) for m in p.finditer(t)]
    if not hits: continue
    wins = []
    for a, b in hits[:3]:
        wins.append(t[max(0, a - 120): b + 120].replace('\n', ' '))
    out.append({'odi': r['odi'], 'modelYear': r['modelYear'], 'incident': r['incident'],
                'done': bool(DONE.search(t)), 'repeat': bool(REP.search(t)), 'windows': ' ... '.join(wins), 'summary': t})
with open(os.path.join(BASE, 'results', 'recurrence_candidates.csv'), 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(len(out), sum(o['done'] for o in out), sum(o['repeat'] for o in out))
