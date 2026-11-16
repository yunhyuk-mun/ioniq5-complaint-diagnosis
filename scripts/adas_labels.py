"""6단계: ADAS 후보 판정(labels/adas_labels.csv) 요약.
판정 (후보 본문을 읽고 결정)
 adas: Y = 주된 내용이 ADAS 기능 관련 / U = 불분명 / N = 아님(ICCU·제동·후방 와이퍼 등)
 function: SCC 스마트 크루즈 / LANE 차로 유지·HDA / FCA 전방 충돌 방지·비상 제동 /
           DAW 운전자 주의 경고(실내 카메라) / REAR 후방·후측방·주차 / MULTI 여러 기능 동시
 error: FP 필요 없는데 작동 / FN 필요한데 미작동 / NAG 경고 과다 / OFF 기능 꺼짐·사용 불가 / HMI 조작·표시 설계
 electrical: 같은 신고에 ICCU·12V·계기판 꺼짐 같은 전원 이상이 함께 서술됨 (Y/N/?)
 design_possible: 설명된 동작이 센서 한계나 기능 설계 범위 안일 가능성 (Y/N/?). 판정자의 추정이다.
 repair_mention: 정비소 방문·수리·업데이트·보증 거부 등 정비 이력 서술 (Y/N)
"""
import csv, os, json, collections
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
cand = {r['odi']: r for r in csv.DictReader(open(os.path.join(BASE, 'results', 'adas_candidates.csv'), encoding='utf-8-sig'))}
lab = {l['odi']: l for l in csv.DictReader(open(os.path.join(BASE, 'labels', 'adas_labels.csv'), encoding='utf-8-sig'))}
rows = [dict(cand[o], **lab[o]) for o in cand if o in lab]
Y = [r for r in rows if r['adas'] == 'Y']
C = lambda k, rs=Y: dict(collections.Counter(r[k] for r in rs).most_common())
res = {
    'candidates': len(cand), 'unlabeled': sum(o not in lab for o in cand),
    'adas': C('adas', rows), 'function': C('function'), 'error': C('error'), 'sensor': C('sensor'),
    'electrical': C('electrical'), 'design_possible': C('design_possible'), 'repair_mention': C('repair_mention'),
    'function_by_modelyear': {f: dict(sorted(collections.Counter(r['modelYear'] for r in Y if r['function'] == f).items()))
                              for f in sorted({r['function'] for r in Y})},
    'error_by_function': {f: dict(collections.Counter(r['error'] for r in Y if r['function'] == f).most_common())
                          for f in sorted({r['function'] for r in Y})},
    'conditions_non_none': dict(collections.Counter(r['condition'] for r in Y if r['condition'] != '없음').most_common()),
    'multi_with_electrical': sum(r['function'] == 'MULTI' and r['electrical'] == 'Y' for r in Y),
    'multi_total': sum(r['function'] == 'MULTI' for r in Y),
}
json.dump(res, open(os.path.join(BASE, 'results', 'adas_summary.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(json.dumps(res, ensure_ascii=False, indent=1))
