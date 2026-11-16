"""아이오닉5 NHTSA 결함 신고 증상 분류 (키워드 규칙 기반)."""
import json, glob, re, csv, collections, os, sys
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = []
for f in sorted(glob.glob(os.path.join(BASE, 'data', 'ioniq5_complaints_*.json'))):
    my = f[-9:-5]
    for r in json.load(open(f, encoding='utf-8'))['results']:
        r['modelYear'] = my
        rows.append(r)

PAT = {
    'ICCU': r'\biccu\b|integrated charging control',
    '12V': r'\b12 ?v\b|12-volt|12 volt|auxiliary battery|aux battery',
    'POWER_LOSS': r'loss of (motive |drive )?power|lost (all )?(motive |drive )?power|lost propulsion|reduced power|power (was |is )?(limited|reduced)|turtle|limp|stopped moving|would not move|no power to|lost acceleration|loss of propulsion|shut (itself )?(down|off) while',
    'CHARGING': r'\bcharg(e|ing|er)\b.{0,40}\b(fail|stop|won|not|unable|error|interrupt)|unable to charge|would not charge|won.t charge|not charg',
    'WARNING': r'warning (light|message|lamp)|check (ev|electric|vehicle|the ev) system|service (ev|vehicle)|dash(board)? lit up|error message',
    'NOISE': r'\bpop(ped|ping)?\b|\bbang\b|loud (noise|sound|clunk)',
    'ADAS': r'smart cruise|adaptive cruise|lane (keep|follow|assist|departure)|forward collision|phantom brak|automatic emergency|\baeb\b|highway driving assist|collision avoidance',
    'BRAKE': r'\bbrak(e|es|ing)\b',
    'RECALL_REPAIRED': r'recall (was |had been )?(performed|completed|done|repair)|after (the )?(recall|software update|update)|(already|previously) (had|been) (the )?(recall|replaced)|second (time|iccu)|replaced (again|twice)|again after|third (time|iccu)',
}
REX = {k: re.compile(v, re.I) for k, v in PAT.items()}

def primary(t):
    # 대표 증상 우선순위: ICCU > 12V > 주행 출력 저하 > 충전 > ADAS > 제동 > 경고등 > 기타
    if REX['ICCU'].search(t): return 'ICCU 고장'
    if REX['12V'].search(t): return '12V 배터리 방전'
    if REX['POWER_LOSS'].search(t): return '주행 중 출력 저하·정지'
    if REX['CHARGING'].search(t): return '충전 불가'
    if REX['ADAS'].search(t): return 'ADAS 오작동'
    if REX['BRAKE'].search(t): return '제동'
    if REX['WARNING'].search(t): return '경고등만'
    return '기타'

out = []
for r in rows:
    t = r['summary'] or ''
    lab = {k: bool(REX[k].search(t)) for k in PAT}
    out.append({'odi': r['odiNumber'], 'modelYear': r['modelYear'],
                'incident': r['dateOfIncident'], 'filed': r['dateComplaintFiled'],
                'crash': r['crash'], 'fire': r['fire'], 'injuries': r['numberOfInjuries'],
                'components': r['components'], 'primary': primary(t), **lab, 'summary': t})

n = len(out)
S = {'total': n}
S['primary'] = collections.Counter(o['primary'] for o in out).most_common()
S['multi_label'] = {k: sum(o[k] for o in out) for k in PAT}
S['primary_by_modelyear'] = {y: collections.Counter(o['primary'] for o in out if o['modelYear']==y).most_common()
                             for y in sorted({o['modelYear'] for o in out})}
ic = [o for o in out if o['ICCU']]
S['iccu'] = {
    'n': len(ic),
    'with_12V': sum(o['12V'] for o in ic),
    'with_power_loss': sum(o['POWER_LOSS'] for o in ic),
    'with_noise': sum(o['NOISE'] for o in ic),
    'with_warning': sum(o['WARNING'] for o in ic),
    'mentions_repeat_after_recall_or_repair': sum(o['RECALL_REPAIRED'] for o in ic),
    'crash': sum(1 for o in ic if o['crash']),
}
def yr(d):
    m = re.search(r'(\d{4})', d or ''); return m.group(1) if m else '?'
S['iccu_by_incident_year'] = sorted(collections.Counter(yr(o['incident']) for o in ic).items())
S['all_by_incident_year'] = sorted(collections.Counter(yr(o['incident']) for o in out).items())
json.dump(S, open(os.path.join(BASE, 'results', 'summary.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
with open(os.path.join(BASE, 'results', 'complaints_labeled.csv'), 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(json.dumps(S, ensure_ascii=False, indent=1))
