"""받은 원본 데이터의 기록(data_manifest.json)을 만든다.
원본 JSON은 저장소에 올리지 않으므로, 당시 결과를 확인할 수 있게 요청 조건·건수·해시·신고 번호 목록 해시를 남긴다."""
import json, os, glob, hashlib, datetime as dt
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = {'source': 'NHTSA public API', 'request': {
        'complaints': 'https://api.nhtsa.gov/complaints/complaintsByVehicle?make=hyundai&model=ioniq%205&modelYear={year}',
        'recalls': 'https://api.nhtsa.gov/recalls/recallsByVehicle?make=hyundai&model=ioniq%205&modelYear={year}'},
       'files': []}
for f in sorted(glob.glob(os.path.join(BASE, 'data', '*.json'))):
    raw = open(f, 'rb').read(); d = json.loads(raw)
    res = d.get('results', []); ids = sorted(str(r.get('odiNumber', r.get('NHTSACampaignNumber', ''))) for r in res)
    out['files'].append({'file': os.path.basename(f),
        'downloaded': dt.datetime.fromtimestamp(os.path.getmtime(f)).strftime('%Y-%m-%d %H:%M'),
        'records': len(res), 'sha256': hashlib.sha256(raw).hexdigest(),
        'id_list_sha256': hashlib.sha256(','.join(ids).encode()).hexdigest()})
json.dump(out, open(os.path.join(BASE, 'data_manifest.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for x in out['files']: print(x['file'], x['downloaded'], x['records'])
