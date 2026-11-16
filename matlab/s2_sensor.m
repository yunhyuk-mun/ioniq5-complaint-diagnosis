%S2_SENSOR 7-2단계: 레이더 잡음·지연·끊김과 필터가 간격 제어에 주는 영향
here = fileparts(mfilename('fullpath')); addpath(here);
out = fullfile(here, '..', 'results', 'sim'); if ~exist(out, 'dir'), mkdir(out); end
p = params(); c = acc_params();
k1 = 0.1; k2 = 0.6;                 % 7-1에서 선택한 이득
gap_final = c.d0 + c.h * c.v_lead_2;
N = 20;                             % 잡음이 있는 경우 반복 횟수 (시드 1~20)
base = struct('dt', c.dt, 'delay', 0, 'sg', 0, 'sv', 0, 'tf', 0, 'drop', [], 'release_after', Inf);
run1 = @(cfg, seed) run_case(k1, k2, p, c, cfg, seed, gap_final);

% (a) 잡음 크기: 거리 잡음 σ와 상대속도 잡음 σ를 함께 키움
SG = [0 0.25 0.5 1.0]; SV = [0 0.1 0.2 0.4];
A = {};
for q = 1:numel(SG)
    for tf = [0 0.5]
        cfg = base; cfg.sg = SG(q); cfg.sv = SV(q); cfg.tf = tf;
        m = avg_cases(run1, cfg, N, SG(q) == 0); m.sg = SG(q); m.sv = SV(q); m.tf = tf; A{end+1} = m; %#ok<SAGROW>
    end
end
A = struct2table([A{:}]);
% (b) 지연
D = [0 0.1 0.3 0.5]; B = {};
for q = 1:numel(D)
    cfg = base; cfg.delay = D(q); m = avg_cases(run1, cfg, 1, true); m.delay = D(q); B{end+1} = m; %#ok<SAGROW>
end
B = struct2table([B{:}]);
% (c) 필터 시정수: 중간 잡음에서 흔들림 감소와 지연 비용
TF = [0 0.2 0.5 1.0]; F = {};
for q = 1:numel(TF)
    cfg = base; cfg.sg = 0.5; cfg.sv = 0.2; cfg.tf = TF(q);
    m = avg_cases(run1, cfg, N, false); m.tf = TF(q); F{end+1} = m; %#ok<SAGROW>
end
F = struct2table([F{:}]);
% (d) 짧은 끊김: 앞차 감속 중 0.5 s, 1.0 s 동안 마지막 값 유지 (해제 없음)
Ddrop = [0 0.5 1.0]; E = {};
for q = 1:numel(Ddrop)
    cfg = base; if Ddrop(q) > 0, cfg.drop = [6 6 + Ddrop(q)]; end
    m = avg_cases(run1, cfg, 1, true); m.drop_s = Ddrop(q); E{end+1} = m; %#ok<SAGROW>
end
E = struct2table([E{:}]);
disp('(a) 잡음'); disp(A); disp('(b) 지연'); disp(B); disp('(c) 필터'); disp(F); disp('(d) 짧은 끊김'); disp(E);

% 그림 1: 측정값 대 참값, 필터 유무에 따른 가속도
cfg = base; cfg.sg = 0.5; cfg.sv = 0.2;
rng(1); r0 = simulate_acc(k1, k2, p, c, @(t, g, d, s) radar_model(t, g, d, s, cfg));
cfgf = cfg; cfgf.tf = 0.5;
rng(1); rf = simulate_acc(k1, k2, p, c, @(t, g, d, s) radar_model(t, g, d, s, cfgf));
f = figure('Visible', 'off', 'Position', [100 100 1150 640], 'Color', 'w');
tl = tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, '레이더 잡음(거리 σ 0.5 m, 상대속도 σ 0.2 m/s)이 있을 때');
nexttile; hold on; grid on;
plot(r0.t, r0.gap_meas, 'Color', [0.75 0.75 0.72], 'LineWidth', 0.8);
plot(rf.t, rf.gap_meas, 'Color', [0.16 0.47 0.84], 'LineWidth', 1.5);
plot(r0.t, r0.gap, 'k', 'LineWidth', 1.5);
ylabel('간격 [m]'); legend({'레이더 측정값', '필터 후 (τ_f 0.5 s)', '참값'}, 'Box', 'off', 'Location', 'northeast');
nexttile; hold on; grid on;
plot(r0.t, r0.a, 'Color', [0.92 0.41 0.20], 'LineWidth', 1.2);
plot(rf.t, rf.a, 'Color', [0.16 0.47 0.84], 'LineWidth', 1.8);
ylabel('가속도 [m/s^2]'); xlabel('시간 [s]'); legend({'필터 없음', '필터 τ_f 0.5 s'}, 'Box', 'off', 'Location', 'southeast');
exportgraphics(f, fullfile(out, 'fig7_2_noise_filter.png'), 'Resolution', 160);

% 그림 2: 잡음·지연·필터의 대가
f2 = figure('Visible', 'off', 'Position', [100 100 1250 380], 'Color', 'w');
tiledlayout(1, 3, 'Padding', 'compact');
nexttile; hold on; grid on;
a0 = A(A.tf == 0, :); a5 = A(A.tf == 0.5, :);
plot(a0.sg, a0.jerk_rms, '-o', 'Color', [0.92 0.41 0.20], 'LineWidth', 2, 'MarkerFaceColor', 'w');
plot(a5.sg, a5.jerk_rms, '-o', 'Color', [0.16 0.47 0.84], 'LineWidth', 2, 'MarkerFaceColor', 'w');
xlabel('거리 잡음 σ [m]'); ylabel('정속 추종 중 저크 RMS [m/s^3]'); title('잡음이 클수록 저크가 커짐');
legend({'필터 없음', '필터 τ_f 0.5 s'}, 'Box', 'off', 'Location', 'northwest');
nexttile; hold on; grid on;
plot(F.undershoot_pct, F.jerk_rms, '-o', 'Color', [0.16 0.47 0.84], 'LineWidth', 2, 'MarkerFaceColor', 'w');
for q = 1:height(F), text(F.undershoot_pct(q) + 0.3, F.jerk_rms(q) + 0.02, sprintf('τ_f %.1f s', F.tf(q)), 'FontSize', 9); end
xlabel('속도 언더슈트 [%]'); ylabel('정속 추종 중 저크 RMS [m/s^3]'); ylim([0 0.52]); title('필터: 저크는 줄지만 응답이 늦어짐');
nexttile; hold on; grid on;
plot(B.delay, B.min_gap, '-o', 'Color', [0.16 0.47 0.84], 'LineWidth', 2, 'MarkerFaceColor', 'w');
plot([0 0.5], [gap_final gap_final], 'k:');
xlabel('측정 지연 [s]'); ylabel('최소 간격 [m]'); title('지연이 길수록 간격이 좁아짐');
exportgraphics(f2, fullfile(out, 'fig7_2_tradeoffs.png'), 'Resolution', 160);

res = struct('noise', table2struct(A), 'delay', table2struct(B), 'filter', table2struct(F), 'dropout', table2struct(E), 'k1', k1, 'k2', k2, 'repeats', N);
fid = fopen(fullfile(out, 's2_sensor.json'), 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(res, 'PrettyPrint', true)); fclose(fid);

function m = run_case(k1, k2, p, c, cfg, seed, gap_final)
rng(seed);
r = simulate_acc(k1, k2, p, c, @(t, g, d, s) radar_model(t, g, d, s, cfg));
after = r.t >= c.t_brake; steady = r.t >= 25;
m.min_gap = min(r.gap(after));
m.undershoot_pct = max(0, (c.v_lead_2 - min(r.v(after))) / (c.v0 - c.v_lead_2) * 100);
m.max_decel = -min(r.a);
m.a_jitter = std(r.a(steady));
jerk = diff(r.a) / c.dt; m.jerk_rms = rms(jerk(steady(1:end-1)));
m.final_gap_err = mean(r.gap(steady)) - gap_final;
end

function m = avg_cases(run1, cfg, N, deterministic)
% 잡음이 있으면 시드 1~N 평균, 없으면 1회
if deterministic, N = 1; end
ms = arrayfun(@(s) run1(cfg, s), 1:N);
fn = fieldnames(ms); m = struct();
for q = 1:numel(fn), m.(fn{q}) = mean([ms.(fn{q})]); end
end
