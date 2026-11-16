%S0_VEHICLE 7-0단계: 종방향 차량 모델을 손계산과 비교
here = fileparts(mfilename('fullpath')); addpath(here);
out = fullfile(here, '..', 'results', 'sim'); if ~exist(out, 'dir'), mkdir(out); end
p = params();
a = 0.5 * p.rho * p.Cd * p.A;   % 공기저항 계수 [N/(m/s)^2]
b = p.fr * p.m * p.g;           % 구름저항 [N]
v0 = 100/3.6;                   % 100 km/h

% (1) 정속 주행에 필요한 구동력: 손계산 vs 모델
F_hand = a*v0^2 + b;
[~, R] = vehicle_long(v0, 0, p); F_model = R.aero + R.roll;

% (2) 같은 구동력을 계속 줄 때 수렴 속도: 시뮬레이션
opt = odeset('RelTol', 1e-9, 'AbsTol', 1e-9);
[~, vs] = ode45(@(t, v) vehicle_long(v, F_hand, p), [0 600], 80/3.6, opt);
v_ss = vs(end);

% (3) 타력 주행: 100 km/h에서 정지까지 시간·거리 손계산 (m dv/dt = -(a v^2 + b) 적분)
t_stop_hand = p.m/sqrt(a*b) * atan(v0*sqrt(a/b));
x_stop_hand = p.m/(2*a) * log(1 + a*v0^2/b);
opt2 = odeset('RelTol', 1e-10, 'AbsTol', 1e-10, 'Events', @stopEvent);
[tc, yc] = ode45(@(t, y) [y(2); vehicle_long(y(2), 0, p)], [0 1000], [0; v0], opt2);
t_stop_sim = tc(end); x_stop_sim = yc(end, 1);
dec0 = -vehicle_long(v0, 0, p);   % 100 km/h에서 타력 감속도

err = @(x, ref) abs(x - ref)/ref*100;
fprintf('정속 100km/h 구동력  손계산 %.1f N, 모델 %.1f N (오차 %.2e%%)\n', F_hand, F_model, err(F_model, F_hand));
fprintf('그 힘으로 수렴한 속도  %.3f km/h (목표 100, 오차 %.2e%%)\n', v_ss*3.6, err(v_ss, v0));
fprintf('타력 정지 시간        손계산 %.2f s, 시뮬 %.2f s (오차 %.3f%%)\n', t_stop_hand, t_stop_sim, err(t_stop_sim, t_stop_hand));
fprintf('타력 정지 거리        손계산 %.1f m, 시뮬 %.1f m (오차 %.3f%%)\n', x_stop_hand, x_stop_sim, err(x_stop_sim, x_stop_hand));
fprintf('100km/h 타력 감속도   %.3f m/s^2 (%.3f g)\n', dec0, dec0/p.g);
pass = all([err(F_model, F_hand), err(v_ss, v0), err(t_stop_sim, t_stop_hand), err(x_stop_sim, x_stop_hand)] < 1);
fprintf('판정: %s\n', string(pass));

% 그림: 속도별 저항력, 타력 주행 속도
vv = linspace(0, 140/3.6, 200); [~, Rv] = vehicle_long(vv, 0, p);
tt = linspace(0, t_stop_hand, 300);
v_hand = sqrt(b/a) * tan(atan(v0*sqrt(a/b)) - sqrt(a*b)/p.m*tt);
f = figure('Visible', 'off', 'Position', [100 100 1100 400], 'Color', 'w');
tiledlayout(1, 2, 'Padding', 'compact');
nexttile; hold on; grid on;
plot(vv*3.6, Rv.aero, 'LineWidth', 2, 'Color', [0.16 0.47 0.84]);
plot(vv*3.6, Rv.roll, 'LineWidth', 2, 'Color', [0.92 0.41 0.20]);
plot(vv*3.6, Rv.aero + Rv.roll, 'k--', 'LineWidth', 1.5);
xlabel('속도 [km/h]'); ylabel('저항력 [N]'); title('속도별 주행 저항');
legend({'공기저항 ½ρC_DAv^2', '구름저항 f_rmg', '합계'}, 'Location', 'northwest', 'Box', 'off');
nexttile; hold on; grid on;
plot(tc, yc(:, 2)*3.6, 'LineWidth', 2.5, 'Color', [0.16 0.47 0.84]);
plot(tt, v_hand*3.6, 'k--', 'LineWidth', 1.5);
xlabel('시간 [s]'); ylabel('속도 [km/h]'); ylim([0 105]); title('100 km/h 타력 주행: 시뮬레이션 대 손계산');
legend({'시뮬레이션', '손계산 해'}, 'Box', 'off');
exportgraphics(f, fullfile(out, 'fig7_0_vehicle_model.png'), 'Resolution', 160);

r = struct('F_hand', F_hand, 'F_model', F_model, 'v_ss_kmh', v_ss*3.6, 't_stop_hand', t_stop_hand, ...
    't_stop_sim', t_stop_sim, 'x_stop_hand', x_stop_hand, 'x_stop_sim', x_stop_sim, 'coast_decel_100', dec0, 'pass', pass);
fid = fopen(fullfile(out, 's0_vehicle.json'), 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(r, 'PrettyPrint', true)); fclose(fid);

function [value, isterminal, direction] = stopEvent(~, y)
value = y(2); isterminal = 1; direction = -1;
end
