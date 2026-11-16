%S1_GAP_CONTROL 7-1단계: 앞차 감속 시 간격 제어의 오버슈트·정착 시간, 이득 비교
here = fileparts(mfilename('fullpath')); addpath(here);
out = fullfile(here, '..', 'results', 'sim'); if ~exist(out, 'dir'), mkdir(out); end
p = params(); c = acc_params();

% 이득 선택 기준 (결과를 보기 전에 정함)
%  1) 최소 간격이 최종 목표 간격의 50% 이상
%  2) 속도 언더슈트(앞차 최종 속도보다 더 느려지는 정도)가 속도 변화량의 10% 이하
%  3) 위를 만족하는 것 중 정착 시간이 가장 짧은 이득
K1 = [0.1 0.2 0.4]; K2 = [0.3 0.6 1.2];
gap_final = c.d0 + c.h * c.v_lead_2;
C = {};
for i = 1:numel(K1)
    for j = 1:numel(K2)
        r = simulate_acc(K1(i), K2(j), p, c);
        s = struct('k1', K1(i), 'k2', K2(j));
        [s.zeta, s.wn] = lin_damping(K1(i), K2(j), c);
        C{end+1} = merge(s, metrics(r, c, gap_final)); %#ok<SAGROW>
    end
end
M = [C{:}];
T = struct2table(M);
ok = [M.min_gap] >= 0.5 * gap_final & [M.undershoot_pct] <= 10;
cand = find(ok); [~, b] = min([M(cand).settle_s]); best = cand(b);
disp(T);
fprintf('선택: k1 = %.1f, k2 = %.1f\n', M(best).k1, M(best).k2);

% 적분 간격 확인: 선택 이득을 dt = 0.001로 다시 계산
c2 = c; c2.dt = 0.001; m2 = metrics(simulate_acc(M(best).k1, M(best).k2, p, c2), c2, gap_final);
dterr = abs([m2.min_gap m2.settle_s m2.undershoot_pct] - [M(best).min_gap M(best).settle_s M(best).undershoot_pct]) ...
        ./ max(abs([M(best).min_gap M(best).settle_s M(best).undershoot_pct]), 1e-9) * 100;
fprintf('dt 0.01 대 0.001 지표 차이 [%%]: 최소 간격 %.2f, 정착 %.2f, 언더슈트 %.2f\n', dterr);

% 그림 1: 대표 이득 3개의 시간 응답
[~, lowz] = min([M.zeta]); slow = find([M.k1] == 0.1 & [M.k2] == 1.2);
pick = unique([lowz best slow], 'stable');
names = {sprintf('감쇠 작음 k1=%.1f, k2=%.1f (ζ=%.2f)', M(lowz).k1, M(lowz).k2, M(lowz).zeta), ...
         sprintf('선택 k1=%.1f, k2=%.1f (ζ=%.2f)', M(best).k1, M(best).k2, M(best).zeta), ...
         sprintf('느림 k1=%.1f, k2=%.1f (ζ=%.2f)', M(slow).k1, M(slow).k2, M(slow).zeta)};
col = [0.92 0.41 0.20; 0.16 0.47 0.84; 0.55 0.55 0.52];
f = figure('Visible', 'off', 'Position', [100 100 1150 820], 'Color', 'w');
tl = tiledlayout(3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
title(tl, '앞차가 100→60 km/h로 감속할 때 간격 제어 응답 (가정값 모델)');
ax = gobjects(3, 1); for q = 1:3, ax(q) = nexttile; hold on; grid on; end
for q = 1:numel(pick)
    r = simulate_acc(M(pick(q)).k1, M(pick(q)).k2, p, c);
    plot(ax(1), r.t, r.gap, 'Color', col(q, :), 'LineWidth', 2);
    plot(ax(2), r.t, r.v*3.6, 'Color', col(q, :), 'LineWidth', 2);
    plot(ax(3), r.t, r.a, 'Color', col(q, :), 'LineWidth', 2);
end
plot(ax(1), [0 c.T], [gap_final gap_final], 'k:', 'LineWidth', 1);
plot(ax(2), r.t, r.v_lead*3.6, 'k--', 'LineWidth', 1.2);
ylabel(ax(1), '간격 [m]'); ylabel(ax(2), '속도 [km/h]'); ylabel(ax(3), '가속도 [m/s^2]'); xlabel(ax(3), '시간 [s]');
legend(ax(1), [names(1:numel(pick)) {'최종 목표 간격'}], 'Location', 'northeast', 'Box', 'off');
legend(ax(2), [names(1:numel(pick)) {'앞차'}], 'Location', 'northeast', 'Box', 'off');
plot(ax(3), [0 c.T], [c.a_min c.a_min], 'k:'); text(ax(3), 0.5, c.a_min + 0.3, '제어기 감속 한계', 'FontSize', 9);
exportgraphics(f, fullfile(out, 'fig7_1_gap_response.png'), 'Resolution', 160);

% 그림 2: 이득별 언더슈트·정착 시간
f2 = figure('Visible', 'off', 'Position', [100 100 1100 380], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact');
U = reshape([M.undershoot_pct], numel(K2), numel(K1))'; S = reshape([M.settle_s], numel(K2), numel(K1))';
nexttile; heat(U, K1, K2, '속도 언더슈트 [%]', '%.1f');
nexttile; heat(S, K1, K2, '정착 시간 [s]', '%.1f');
exportgraphics(f2, fullfile(out, 'fig7_1_gain_sweep.png'), 'Resolution', 160);

res = struct('table', M, 'best', best, 'gap_final', gap_final, 'dt_check_pct', dterr);
fid = fopen(fullfile(out, 's1_gap_control.json'), 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(res, 'PrettyPrint', true)); fclose(fid);

function m = metrics(r, c, gap_final)
after = r.t >= c.t_brake;
m.min_gap = min(r.gap(after));
m.undershoot_pct = max(0, (c.v_lead_2 - min(r.v(after))) / (c.v0 - c.v_lead_2) * 100);
m.max_decel = -min(r.a);
jerk = diff(r.a) / (r.t(2) - r.t(1)); m.max_jerk = max(abs(jerk));
in = abs(r.gap - gap_final) <= 0.5 & abs(r.v - r.v_lead) * 3.6 <= 0.5;
last_out = find(~in & after, 1, 'last');
if isempty(last_out), m.settle_s = 0; elseif last_out == numel(r.t), m.settle_s = Inf;
else, m.settle_s = r.t(last_out + 1) - c.t_brake; end
end

function [zeta, wn] = lin_damping(k1, k2, c)
% 선형화: 상태 [간격 오차 e, 상대속도 dv, 가속도 a], 앞차 가속도 0
A = [0 1 -c.h; 0 0 -1; k1/c.tau k2/c.tau -1/c.tau];
[wn_all, z_all] = damp(ss(A, zeros(3, 1), eye(3), 0));
[zeta, i] = min(z_all); wn = wn_all(i);   % 가장 감쇠가 작은 극점
end

function s = merge(s, m)
fn = fieldnames(m); for q = 1:numel(fn), s.(fn{q}) = m.(fn{q}); end
end

function heat(Z, K1, K2, ttl, fmt)
imagesc(Z); colormap(gca, flipud(gray(64)) * 0.6 + 0.4); axis tight;
set(gca, 'XTick', 1:numel(K2), 'XTickLabel', string(K2), 'YTick', 1:numel(K1), 'YTickLabel', string(K1));
xlabel('k2 (상대속도 이득)'); ylabel('k1 (간격 이득)'); title(ttl);
for i = 1:size(Z, 1), for j = 1:size(Z, 2)
    text(j, i, sprintf(fmt, Z(i, j)), 'HorizontalAlignment', 'center', 'FontSize', 11);
end, end
end
