"""6단계: ADAS 기능 신고 후보 추출. 판정은 labels/adas_labels.csv에 신고 번호(odi)로 기록한다."""
import csv, re, os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = list(csv.DictReader(open(os.path.join(BASE, 'results', 'complaints_labeled.csv'), encoding='utf-8-sig')))
ADAS = re.compile(r'smart cruise|adaptive cruise|cruise control|lane (keep|follow|assist|departure)|forward collision|phantom|automatic emergency|emergency brak|\baeb\b|highway driving assist|collision avoidance|driver attention|forward attention|blind spot|parking (distance|assist|sensor)|radar|camera|sensor', re.I)
out = [{'odi': r['odi'], 'modelYear': r['modelYear'], 'incident': r['incident'], 'components': r['components'], 'summary': r['summary']}
       for r in rows if ADAS.search(r['summary'])]
with open(os.path.join(BASE, 'results', 'adas_candidates.csv'), 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(len(out))
