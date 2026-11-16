%S4_SIMULINK 7-4단계: 스마트 크루즈 모델을 Simulink 블록도로 다시 만들고, 스크립트(simulate_acc) 결과와 교차 검증
%   블록도는 이 스크립트가 코드로 만든다 (acc_model.slx). 레이더 오차·해제는 넣지 않은 참값 센서 경우만 비교한다.
here = fileparts(mfilename('fullpath')); addpath(here);
out = fullfile(here, '..', 'results', 'sim'); if ~exist(out, 'dir'), mkdir(out); end
p = params(); c = acc_params();
k1 = 0.1; k2 = 0.6;                       % 7-1에서 선택한 이득
mdl = 'acc_model';
if bdIsLoaded(mdl), close_system(mdl, 0); end
if exist(fullfile(here, [mdl '.slx']), 'file'), delete(fullfile(here, [mdl '.slx'])); end
new_system(mdl); load_system(mdl);
set_param(mdl, 'Solver', 'ode4', 'FixedStep', num2str(c.dt), 'StopTime', num2str(c.T));

B = @(lib, name, varargin) add_block(lib, [mdl '/' name], varargin{:});
% 앞차
B('simulink/Sources/Ramp', 'Lead braking', 'slope', num2str(c.a_lead), 'start', num2str(c.t_brake), 'InitialOutput', num2str(c.v0, 10));
B('simulink/Discontinuities/Saturation', 'Lead speed', 'UpperLimit', num2str(c.v0, 10), 'LowerLimit', num2str(c.v_lead_2, 10));
B('simulink/Continuous/Integrator', 'Lead position', 'InitialCondition', num2str(c.d0 + c.h * c.v0, 10));
% 측정과 제어기
B('simulink/Math Operations/Sum', 'Gap', 'Inputs', '+-');
B('simulink/Math Operations/Sum', 'Relative speed', 'Inputs', '+-');
B('simulink/Math Operations/Gain', 'Time gap h', 'Gain', num2str(c.h));
B('simulink/Sources/Constant', 'Standstill gap d0', 'Value', num2str(c.d0));
B('simulink/Math Operations/Sum', 'Gap error', 'Inputs', '+--');
B('simulink/Math Operations/Gain', 'k1', 'Gain', num2str(k1));
B('simulink/Math Operations/Gain', 'k2', 'Gain', num2str(k2));
B('simulink/Math Operations/Sum', 'Accel command', 'Inputs', '++');
B('simulink/Discontinuities/Saturation', 'Accel limit', 'UpperLimit', num2str(c.a_max), 'LowerLimit', num2str(c.a_min));
B('simulink/Continuous/Transfer Fcn', 'Actuator lag', 'Numerator', '1', 'Denominator', sprintf('[%g 1]', c.tau));
% 차량: 구동력 = m a + 주행 저항, 가속도 = (구동력 - 주행 저항) / m
B('simulink/Math Operations/Gain', 'Mass m', 'Gain', num2str(p.m));
B('simulink/User-Defined Functions/Fcn', 'Road load R(v)', 'Expression', ...
  sprintf('0.5*%g*%g*%g*u^2 + %.6f', p.rho, p.Cd, p.A, p.fr * p.m * p.g * cos(p.theta) + p.m * p.g * sin(p.theta)));
B('simulink/Math Operations/Sum', 'Drive force', 'Inputs', '++');
B('simulink/Math Operations/Sum', 'Net force', 'Inputs', '+-');
B('simulink/Math Operations/Gain', 'Inverse mass', 'Gain', sprintf('1/%g', p.m));
B('simulink/Continuous/Integrator', 'Ego speed', 'InitialCondition', num2str(c.v0, 10), ...
  'LimitOutput', 'on', 'LowerSaturationLimit', '0');
B('simulink/Continuous/Integrator', 'Ego position', 'InitialCondition', '0');
% 기록
for nm = {'gap', 'v', 'a', 'v_lead'}
    B('simulink/Sinks/To Workspace', ['log ' nm{1}], 'VariableName', ['sl_' nm{1}], 'SaveFormat', 'Array');
end


% 배치: 왼쪽 앞차·측정 → 가운데 제어기·구동 지연 → 오른쪽 차량, 아래로 되먹임
P = @(name, x, y, w, h) set_param([mdl '/' name], 'Position', [x - w/2, y - h/2, x + w/2, y + h/2]);
P('Lead braking', 40, 60, 40, 30); P('Lead speed', 120, 60, 40, 30); P('Lead position', 210, 60, 30, 30);
P('log v_lead', 210, 0, 70, 24);
P('Gap', 300, 75, 20, 20); P('Relative speed', 300, 160, 20, 20);
P('Standstill gap d0', 300, 230, 30, 26); P('Time gap h', 300, 300, 40, 30);
P('Gap error', 400, 150, 20, 20);
P('k1', 480, 150, 40, 30); P('k2', 480, 220, 40, 30); P('Accel command', 560, 185, 20, 20);
P('Accel limit', 640, 185, 40, 30); P('Actuator lag', 740, 185, 70, 34); P('log a', 740, 110, 60, 24);
P('Mass m', 840, 185, 40, 30); P('Road load R(v)', 840, 300, 60, 30);
P('Drive force', 920, 200, 20, 20); P('Net force', 990, 240, 20, 20); P('Inverse mass', 1060, 240, 50, 30);
P('Ego speed', 1140, 240, 30, 30); P('Ego position', 1220, 240, 30, 30);
P('log gap', 400, 75, 60, 24); P('log v', 1220, 320, 60, 24);
L = @(a, b) add_line(mdl, a, b, 'autorouting', 'smart');
L('Lead braking/1', 'Lead speed/1'); L('Lead speed/1', 'Lead position/1');
L('Lead position/1', 'Gap/1'); L('Ego position/1', 'Gap/2');
L('Lead speed/1', 'Relative speed/1'); L('Ego speed/1', 'Relative speed/2');
L('Ego speed/1', 'Time gap h/1');
L('Gap/1', 'Gap error/1'); L('Standstill gap d0/1', 'Gap error/2'); L('Time gap h/1', 'Gap error/3');
L('Gap error/1', 'k1/1'); L('Relative speed/1', 'k2/1');
L('k1/1', 'Accel command/1'); L('k2/1', 'Accel command/2');
L('Accel command/1', 'Accel limit/1'); L('Accel limit/1', 'Actuator lag/1');
L('Actuator lag/1', 'Mass m/1'); L('Mass m/1', 'Drive force/1');
L('Ego speed/1', 'Road load R(v)/1'); L('Road load R(v)/1', 'Drive force/2');
L('Drive force/1', 'Net force/1'); L('Road load R(v)/1', 'Net force/2');
L('Net force/1', 'Inverse mass/1'); L('Inverse mass/1', 'Ego speed/1'); L('Ego speed/1', 'Ego position/1');
L('Gap/1', 'log gap/1'); L('Ego speed/1', 'log v/1'); L('Actuator lag/1', 'log a/1'); L('Lead speed/1', 'log v_lead/1');
save_system(mdl, fullfile(here, [mdl '.slx']));
print(['-s' mdl], '-dpng', '-r150', fullfile(out, 'fig7_4_simulink_model.png'));

% 실행과 교차 검증
so = sim(mdl);
ts = so.tout; sg = so.sl_gap; sv = so.sl_v; sa = so.sl_a;
r = simulate_acc(k1, k2, p, c);
gi = interp1(ts, sg, r.t); vi = interp1(ts, sv, r.t); ai = interp1(ts, sa, r.t);
after = r.t >= c.t_brake; after_s = ts >= c.t_brake;
M = @(gap, v, aa, af) [min(gap(af)), max(0, (c.v_lead_2 - min(v(af))) / (c.v0 - c.v_lead_2) * 100), -min(aa)];
ms = M(r.gap, r.v, r.a, after); mk = M(sg, sv, sa, after_s);
res = struct(); res.script = struct('min_gap', ms(1), 'undershoot_pct', ms(2), 'max_decel', ms(3));
res.simulink = struct('min_gap', mk(1), 'undershoot_pct', mk(2), 'max_decel', mk(3));
res.max_abs_gap_diff_m = max(abs(gi - r.gap));
res.max_abs_speed_diff_kmh = max(abs(vi - r.v)) * 3.6;
res.max_abs_accel_diff = max(abs(ai - r.a));
res.solver = 'Simulink ode4, 0.01 s / script Euler, 0.01 s';
disp(res.script); disp(res.simulink);
fprintf('최대 차이: 간격 %.3f m, 속도 %.3f km/h, 가속도 %.3f m/s^2\n', res.max_abs_gap_diff_m, res.max_abs_speed_diff_kmh, res.max_abs_accel_diff);

f = figure('Visible', 'off', 'Position', [100 100 1150 420], 'Color', 'w');
tl = tiledlayout(1, 2, 'Padding', 'compact');
title(tl, '같은 모델을 스크립트와 Simulink 블록도로 따로 만들어 비교 (k1 0.1, k2 0.6)');
nexttile; hold on; grid on;
plot(r.t, r.gap, 'Color', [0.16 0.47 0.84], 'LineWidth', 3);
plot(ts, sg, '--', 'Color', [0.92 0.41 0.20], 'LineWidth', 1.6);
ylabel('간격 [m]'); xlabel('시간 [s]'); legend({'MATLAB 스크립트', 'Simulink'}, 'Box', 'off', 'Location', 'northeast');
nexttile; hold on; grid on;
plot(r.t, r.a, 'Color', [0.16 0.47 0.84], 'LineWidth', 3);
plot(ts, sa, '--', 'Color', [0.92 0.41 0.20], 'LineWidth', 1.6);
ylabel('가속도 [m/s^2]'); xlabel('시간 [s]');
exportgraphics(f, fullfile(out, 'fig7_4_simulink_check.png'), 'Resolution', 160);

fid = fopen(fullfile(out, 's4_simulink.json'), 'w', 'n', 'UTF-8'); fprintf(fid, '%s', jsonencode(res, 'PrettyPrint', true)); fclose(fid);
close_system(mdl, 0);
