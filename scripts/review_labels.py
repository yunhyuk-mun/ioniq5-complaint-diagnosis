"""1.5단계: 표본 100건 판정(labels/review_labels.csv)과 규칙 분류 비교.
판정 기준
- human_primary: 규칙과 같은 범주 체계. 'ICCU 고장'은 본문에 ICCU가 명시된 경우만.
- pattern_no_mention: ICCU를 명시하지 않았지만 전형 증상(경고 문구 + 출력 제한·정지, 펑 소리 등)이 보이는 경우.
표본은 처음에 무작위(seed 2026)로 뽑았고, 이후 재현을 위해 신고 번호(odi)로 고정했다.
"""
import csv, os, json, collections
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rule = {r['odi']: r for r in csv.DictReader(open(os.path.join(BASE, 'results', 'complaints_labeled.csv'), encoding='utf-8-sig'))}
lab = list(csv.DictReader(open(os.path.join(BASE, 'labels', 'review_labels.csv'), encoding='utf-8-sig')))
pairs = [(rule[l['odi']]['primary'], l['human_primary']) for l in lab]
cats = sorted({a for a, _ in pairs} | {b for _, b in pairs})
res = {'n': len(pairs), 'primary_accuracy': sum(a == b for a, b in pairs) / len(pairs), 'per_category': {}}
for c in cats:
    tp = sum(a == c and b == c for a, b in pairs); pp = sum(a == c for a, _ in pairs); ap = sum(b == c for _, b in pairs)
    res['per_category'][c] = {'rule': pp, 'human': ap, 'tp': tp,
                              'precision': round(tp / pp, 2) if pp else None, 'recall': round(tp / ap, 2) if ap else None}
res['iccu_pattern_without_mention'] = sum(l['pattern_no_mention'] == 'True' for l in lab)
res['confusions'] = collections.Counter(f'{a} -> {b}' for a, b in pairs if a != b).most_common()
json.dump(res, open(os.path.join(BASE, 'results', 'review_metrics.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(json.dumps(res, ensure_ascii=False, indent=1))
