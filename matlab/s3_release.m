%S3_RELEASE 7-3단계: 레이더 가림으로 스마트 크루즈가 해제될 때, 해제 방식에 따른 감속도·저크·운전자 인계 상태
%   해제 방식: 해제 직전 가속도 명령에서 타력 주행(구동력 0)까지 램프 시간 Tr에 걸쳐 바꾼다. Tr = 0이면 즉시 타력.
%   가림은 끝까지 이어진다고 보고(눈·얼음이 센서를 덮은 경우), 가림 0.5 s 뒤 해제, 해제 1.5 s 뒤 운전자가 인계받는다고 가정한다.
here = fileparts(mfilename('fullpath')); addpath(here);
out = fullfile(here, '..', 'results', 'sim'); if ~exist(out, 'dir'), mkdir(out); end
p = params(); c = acc_params();
k1 = 0.1; k2 = 0.6;              % 7-1에서 선택한 이득
rel_after = 0.5;                 % 가림이 이 시간 이어지면 해제 [s], 가정
t_react = 1.5;                   % 해제 후 운전자 인계까지 [s], 가정
TR = [0 0.5 1 2 3];              % 램프 시간 [s]

% 시나리오 A: 100 km/h 정속 추종 중 10 s에 가림
cA = c; cA.t_brake = Inf; dropA = [10 c.T + 1];
% 시나리오 B: 앞차가 5 s부터 -3 m/s^2로 감속하는 도중 5.5 s에 가림
cB = c; dropB = [5.5 c.T + 1];
S = {'A', cA, dropA; 'B', cB, dropB};

R = {};
for s = 1:2
    for q = 1:numel(TR)
        r = run_release(k1, k2, p, S{s, 2}, S{s, 3}, rel_after, TR(q));
        m = rel_metrics(r, S{s, 2}, t_react); m.scenario = S{s, 1}; m.ramp_s = TR(q);
        R{end+1} = m; %#ok<SAGROW>
    end
end
T = struct2table([R{:}]); disp(T);
TA = T(strcmp(T.scenario, 'A'), :); TB = T(strcmp(T.scenario, 'B'), :);

% 참고: 가림이 없을 때 시나리오 B 같은 시각의 간격
rB0 = simulate_acc(k1, k2, p, cB);
t_h = TB.t_release(1) + t_react; i_h = find(rB0.t >= t_h, 1);
ref.gap_handover_no_occlusion = rB0.gap(i_h);
ref.closing_kmh_no_occlusion = (rB0.v(i_h) - rB0.v_lead(i_h)) * 3.6;
ref.coast_decel_100kmh = -vehicle_long(c.v0, 0, p);
fprintf('가림 없을 때 B 인계 시각 간격 %.1f m, 접근 속도 %.1f km/h, 100 km/h 타력 감속 %.3f m/s^2\n', ...
    ref.gap_handover_no_occlusion, ref.closing_kmh_no_occlusion, ref.coast_decel_100kmh);

% 그림 1: 시간 응답 (B 가속도, B 간격, A 가속도)
show = [0 1 3]; col = [0.92 0.41 0.20; 0.16 0.47 0.84; 0.55 0.55 0.52];
f = figure('Visible', 'off', 'Position', [100 100 1150 900], 'Color', 'w');
tl = tiledlayout(3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, '레이더 가림으로 스마트 크루즈가 해제될 때 해제 방식 비교 (가정값 모델)');
ax = gobjects(3, 1); for q = 1:3, ax(q) = nexttile; hold on; grid on; end
names = cell(1, numel(show));
for q = 1:numel(show)
    rb = run_release(k1, k2, p, cB, dropB, rel_after, show(q));
    ra = run_release(k1, k2, p, cA, dropA, rel_after, show(q));
    plot(ax(1), rb.t, rb.a, 'Color', col(q, :), 'LineWidth', 2);
    plot(ax(2), rb.t, rb.gap, 'Color', col(q, :), 'LineWidth', 2);
    plot(ax(3), ra.t, ra.a, 'Color', col(q, :), 'LineWidth', 2);
    if show(q) == 0, names{q} = '즉시 타력'; else, names{q} = sprintf('램프 %.0f s', show(q)); end
end
plot(ax(1), rB0.t, rB0.a, 'k:', 'LineWidth', 1.2); plot(ax(2), rB0.t, rB0.gap, 'k:', 'LineWidth', 1.2);
tb = TB.t_release(1); ta = TA.t_release(1);
for q = 1:2, xline(ax(q), tb, '-', '해제'); xline(ax(q), tb + t_react, '-', '운전자 인계'); xlim(ax(q), [0 10]); end
ylim(ax(2), [0 60]);
xline(ax(3), ta, '-', '해제'); xline(ax(3), ta + t_react, '-', '운전자 인계'); xlim(ax(3), [5 20]);
title(ax(1), 'B. 앞차 감속 중 가림: 가속도'); ylabel(ax(1), '가속도 [m/s^2]');
title(ax(2), 'B. 앞차 감속 중 가림: 간격'); ylabel(ax(2), '간격 [m]');
title(ax(3), 'A. 정속 추종 중 가림: 가속도'); ylabel(ax(3), '가속도 [m/s^2]'); xlabel(ax(3), '시간 [s]');
legend(ax(1), [names {'가림 없음'}], 'Box', 'off', 'Location', 'southwest');
legend(ax(3), names, 'Box', 'off', 'Location', 'northeast');
exportgraphics(f, fullfile(out, 'fig7_3_release.png'), 'Resolution', 160);

% 해제 판정 시간 비교: 시나리오 B, 램프 1 s 고정. 가림 동안은 마지막 측정값을 유지한다
RA = [0.1 0.25 0.5 1.0]; H = {};
for q = 1:numel(RA)
    m = rel_metrics(run_release(k1, k2, p, cB, dropB, RA(q), 1), cB, t_react); m.release_after = RA(q); H{end+1} = m; %#ok<SAGROW>
end
H = struct2table([H{:}]);
H.closing_no_occlusion = arrayfun(@(th) interp1(rB0.t, (rB0.v - rB0.v_lead) * 3.6, th), H.t_release + t_react);
disp('해제 판정 시간 비교 (B, 램프 1 s)'); disp(H);

% 그림 2: 램프 시간과 해제 판정 시간의 대가
f2 = figure('Visible', 'off', 'Position', [100 100 1250 380], 'Color', 'w');
tiledlayout(1, 3, 'Padding', 'compact');
lb = {'-o', 'Color', [0.16 0.47 0.84], 'LineWidth', 2, 'MarkerFaceColor', 'w'};
lo = {'-o', 'Color', [0.92 0.41 0.20], 'LineWidth', 2, 'MarkerFaceColor', 'w'};
nexttile; hold on; grid on; plot(TB.ramp_s, TB.peak_jerk, lb{:}); plot(TA.ramp_s, TA.peak_jerk, lo{:});
xlabel('램프 시간 [s]'); ylabel('해제 후 최대 저크 [m/s^3]'); title('램프가 길수록 저크가 작음');
legend({'B. 앞차 감속 중', 'A. 정속 추종 중'}, 'Box', 'off', 'Location', 'northeast');
nexttile; hold on; grid on; plot(TB.ramp_s, TB.closing_kmh, lb{:});
yline(ref.closing_kmh_no_occlusion, 'k:', '가림 없음'); ylim([0 30]);
xlabel('램프 시간 [s]'); ylabel('인계 시점 접근 속도 [km/h]'); title('B. 램프는 인계 상태를 거의 못 바꿈');
nexttile; hold on; grid on; plot(H.release_after, H.closing_kmh, lb{:});
plot(H.release_after, H.closing_no_occlusion, 'k:', 'LineWidth', 1.2); ylim([0 30]);
legend({'가림', '가림 없음 (같은 시각)'}, 'Box', 'off', 'Location', 'southeast');
xlabel('가림 후 해제까지 [s]'); ylabel('인계 시점 접근 속도 [km/h]'); title('B. 해제 판정이 늦을수록 접근 속도 증가');
exportgraphics(f2, fullfile(out, 'fig7_3_ramp_tradeoff.png'), 'Resolution', 160);

res = struct('table', table2struct(T), 'release_after_sweep', table2struct(H), 'reference', ref, 'k1', k1, 'k2', k2, ...
    'release_after_s', rel_after, 'driver_takeover_s', t_react);
fid = fopen(fullfile(out, 's3_release.json'), 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(res, 'PrettyPrint', true)); fclose(fid);

function r = run_release(k1, k2, p, c, drop, rel_after, Tr)
cfg = struct('dt', c.dt, 'delay', 0, 'sg', 0, 'sv', 0, 'tf', 0, 'drop', drop, 'release_after', rel_after);
cfg.release_cmd = @(t, v, p, info) release_ramp(t, v, p, info, Tr);
r = simulate_acc(k1, k2, p, c, @(t, g, d, s) radar_model(t, g, d, s, cfg));
end

function a = release_ramp(t, v, p, info, Tr)
% 해제 직전 명령에서 타력 주행 가속도(구동력 0일 때의 주행 저항 감속)로 Tr 동안 선형 이동
a_coast = vehicle_long(v, 0, p);
if Tr <= 0, a = a_coast; return; end
w = min(1, (t - info.t_rel) / Tr);
a = info.a_last + (a_coast - info.a_last) * w;
end

function m = rel_metrics(r, c, t_react)
i_rel = find(~r.valid, 1); t_rel = r.t(i_rel);
win = r.t >= t_rel & r.t <= t_rel + t_react;
jerk = diff(r.a) / c.dt;
i_h = find(r.t >= t_rel + t_react, 1);
m.t_release = t_rel;
m.a_at_release = r.a(i_rel);
m.peak_decel = -min(r.a(win));
m.peak_jerk = max(abs(jerk(win(1:end-1))));
m.speed_drop_kmh = (r.v(i_rel) - r.v(i_h)) * 3.6;
m.gap_handover = r.gap(i_h);
m.closing_kmh = (r.v(i_h) - r.v_lead(i_h)) * 3.6;
% 인계 시점에서 충돌을 피하려면 필요한 감속도: 앞차가 그 순간 가속도를 유지한다고 가정
a_l = (r.v_lead(i_h + 1) - r.v_lead(i_h)) / c.dt;
vc = max(0, r.v(i_h) - r.v_lead(i_h));
m.req_decel = max(0, -a_l + vc^2 / (2 * r.gap(i_h)));
end
