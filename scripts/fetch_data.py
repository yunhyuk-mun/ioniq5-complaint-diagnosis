"""NHTSA 공개 API에서 아이오닉5 결함 신고·리콜을 받아 data/에 저장한다."""
import json, os, urllib.request
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, 'data'); os.makedirs(OUT, exist_ok=True)
API = 'https://api.nhtsa.gov'
for y in (2022, 2023, 2024, 2025):
    for kind, path in (('complaints', 'complaints/complaintsByVehicle'), ('recalls', 'recalls/recallsByVehicle')):
        url = f'{API}/{path}?make=hyundai&model=ioniq%205&modelYear={y}'
        with urllib.request.urlopen(url, timeout=120) as r:
            data = json.load(r)
        fn = os.path.join(OUT, f'ioniq5_{kind}_{y}.json')
        json.dump(data, open(fn, 'w', encoding='utf-8'), ensure_ascii=False)
        n = len(data.get('results', []))
        print(f'{fn}: {n}건')
