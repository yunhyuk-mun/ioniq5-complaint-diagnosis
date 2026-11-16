"""2단계: 월별 신고 추이와 리콜 시점 비교 (발생일 기준)."""
import csv, os, re, json, collections, datetime as dt
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = list(csv.DictReader(open(os.path.join(BASE, 'results', 'complaints_labeled.csv'), encoding='utf-8-sig')))
def d(s):
    try: return dt.datetime.strptime(s, '%m/%d/%Y').date()
    except Exception: return None
rows = [r for r in rows if d(r['incident']) and d(r['incident']).year >= 2022]
for r in rows: r['ym'] = d(r['incident']).strftime('%Y-%m')

def months(a, b):
    y, m = a; out = []
    while (y, m) <= b:
        out.append(f'{y}-{m:02d}'); m += 1
        if m == 13: y, m = y + 1, 1
    return out
M = months((2022, 1), (2026, 11))
cnt = {k: collections.Counter() for k in ['iccu_recall_my', 'iccu_2025', 'other']}
for r in rows:
    k = 'other' if r['ICCU'] != 'True' else ('iccu_2025' if r['modelYear'] == '2025' else 'iccu_recall_my')
    cnt[k][r['ym']] += 1

# 겨울(12~3월) 집중도와 추위 언급
def winter(ym): return int(ym[5:]) in (12, 1, 2, 3)
ic = [r for r in rows if r['ICCU'] == 'True']; non = [r for r in rows if r['ICCU'] != 'True']
COLD = re.compile(r'\bcold\b|freez|winter|snow|below zero|\b[0-2]?\d ?(°|degrees?) ?f?\b.*(cold|weather)|blizzard', re.I)
res = {
  'n_with_valid_incident_date': len(rows),
  'winter_share_iccu': round(sum(winter(r['ym']) for r in ic) / len(ic), 3),
  'winter_share_other': round(sum(winter(r['ym']) for r in non) / len(non), 3),
  'cold_mention_iccu': round(sum(bool(COLD.search(r['summary'])) for r in ic) / len(ic), 3),
  'cold_mention_other': round(sum(bool(COLD.search(r['summary'])) for r in non) / len(non), 3),
}
def win(a, b, key=None):
    sel = [m for m in M if a <= m <= b]
    return {'months': len(sel), 'iccu_recall_my': sum(cnt['iccu_recall_my'][m] for m in sel),
            'iccu_2025': sum(cnt['iccu_2025'][m] for m in sel), 'other': sum(cnt['other'][m] for m in sel)}
res['periods'] = {
  'before_24V204 (2023-01~2024-03)': win('2023-01', '2024-03'),
  'between (2024-04~2024-12)': win('2024-04', '2024-12'),
  'after_24V868_letters (2025-01~2026-09)': win('2025-01', '2026-09'),
}
res['winters_iccu'] = {f'{y}-{y+1} 12~3월': sum(cnt['iccu_recall_my'][m] + cnt['iccu_2025'][m] for m in M
                       if (m[:4] == str(y) and m[5:] == '12') or (m[:4] == str(y+1) and int(m[5:]) <= 3)) for y in (2022, 2023, 2024, 2025)}
res['peak_month'] = max(M, key=lambda m: cnt['iccu_recall_my'][m] + cnt['iccu_2025'][m])
json.dump(res, open(os.path.join(BASE, 'results', 'trend_summary.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(json.dumps(res, ensure_ascii=False, indent=1))

# 그림
plt.rcParams['font.family'] = 'Malgun Gothic'; plt.rcParams['axes.unicode_minus'] = False
SURF, INK, INK2, GRID = '#fcfcfb', '#0b0b0b', '#52514e', '#e4e3df'
C1, C2, C3 = '#2a78d6', '#eb6834', '#c9c8c2'
fig, ax = plt.subplots(figsize=(11, 4.6), facecolor=SURF); ax.set_facecolor(SURF)
x = range(len(M)); b = [0]*len(M)
for key, col, lab in [('iccu_recall_my', C1, 'ICCU 언급: 2022~2024년식 (리콜 대상)'),
                      ('iccu_2025', C2, 'ICCU 언급: 2025년식 (리콜 대상 아님)'),
                      ('other', C3, 'ICCU 언급 없음')]:
    v = [cnt[key][m] for m in M]
    ax.bar(x, v, bottom=b, color=col, width=0.8, edgecolor=SURF, linewidth=1, label=lab)
    b = [p+q for p, q in zip(b, v)]
for ym, txt in [('2024-03', '24V-204 리콜\n2024.3'), ('2024-12', '24V-868 리콜 통지\n2024.12')]:
    i = M.index(ym); ax.axvline(i, color=INK2, lw=1, ls='--')
    ax.text(i + 0.4, max(b)*0.92, txt, color=INK2, fontsize=9, va='top')
i0 = M.index('2026-08'); ax.axvspan(i0 - 0.5, len(M) - 0.5, color='#f0efec', zorder=0)
ax.text(len(M) - 0.6, max(b)*0.55, '최근 월은\n신고 지연으로\n덜 집계됨', ha='right', fontsize=8.5, color=INK2)
ticks = [i for i, m in enumerate(M) if m[5:] in ('01', '07')]
ax.set_xticks(ticks); ax.set_xticklabels([M[i].replace('-', '.') for i in ticks], color=INK2, fontsize=9)
ax.tick_params(axis='y', colors=INK2, labelsize=9); ax.set_ylabel('월별 신고 수 (발생일 기준)', color=INK2, fontsize=9)
for s in ['top', 'right']: ax.spines[s].set_visible(False)
for s in ['left', 'bottom']: ax.spines[s].set_color(GRID)
ax.yaxis.grid(True, color=GRID, lw=0.8); ax.set_axisbelow(True)
ax.set_title('아이오닉5 NHTSA 결함 신고 월별 추이와 ICCU 리콜 시점', loc='left', color=INK, fontsize=12, pad=12)
ax.legend(frameon=False, fontsize=9, loc='upper left', labelcolor=INK)
fig.tight_layout(); fig.savefig(os.path.join(BASE, 'results', 'fig_trend_monthly.png'), dpi=160, facecolor=SURF)
