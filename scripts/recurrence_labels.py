"""3단계: 재발 후보 판정(labels/recurrence_labels.csv) 요약.
판정 (후보 본문을 읽고 결정)
 H = ICCU를 교체한 뒤 다시 고장났다고 서술
 R = 리콜·캠페인·소프트웨어 조치나 점검을 받은 뒤 ICCU 고장 (이전 ICCU 교체 언급 없음)
 U = 재발로 보이나 불분명
 N = 재발 아님 (리콜 미이행, 같은 사건 안의 반복, 앞으로의 걱정, 일반론 등)
 D = 같은 신고자의 중복 신고로 보여 제외
gap_days: 본문에 이전 조치와 재고장 사이 기간이 적힌 경우의 대략 일수.
"""
import csv, os, json, statistics, collections
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cand = {r['odi']: r for r in csv.DictReader(open(os.path.join(BASE, 'results', 'recurrence_candidates.csv'), encoding='utf-8-sig'))}
lab = {l['odi']: l for l in csv.DictReader(open(os.path.join(BASE, 'labels', 'recurrence_labels.csv'), encoding='utf-8-sig'))}
missing = [o for o in cand if o not in lab]
rows = [dict(cand[o], **lab[o]) for o in cand if o in lab]
res = {'candidates': len(cand), 'unlabeled_candidates': len(missing),
       'labels': dict(collections.Counter(r['label'] for r in rows)),
       'by_modelyear': {L: dict(sorted(collections.Counter(r['modelYear'] for r in rows if r['label'] == L).items())) for L in 'HR'}}
for L in 'HR':
    g = sorted(int(r['gap_days']) for r in rows if r['label'] == L and r['gap_days'])
    res[f'gap_{L}'] = {'n': len(g), 'median_days': statistics.median(g), 'within_30d': sum(x <= 30 for x in g), 'min': g[0], 'max': g[-1]}
json.dump(res, open(os.path.join(BASE, 'results', 'recurrence_summary.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(json.dumps(res, ensure_ascii=False, indent=1))
