function out = simulate_acc(k1, k2, p, c, sensor)
%SIMULATE_ACC 앞차 추종 스마트 크루즈 시뮬레이션 (고정 간격 오일러 적분)
%   제어 법칙: a_cmd = k1 * (측정 간격 - d0 - h v) + k2 * (측정 상대속도)
%   a_cmd는 [a_min, a_max]로 자르고, 1차 지연(tau)을 거쳐 실제 가속도가 된다.
%   구동·제동 힘 F = m a + 주행 저항 (저항 보상) 을 vehicle_long에 넣어 속도를 적분한다.
%   sensor (선택): 7-2·7-3단계용 레이더 모델 함수 핸들. 없으면 참값을 그대로 쓴다.
if nargin < 5 || isempty(sensor), sensor = @truth_sensor; end
n = round(c.T / c.dt) + 1; t = (0:n-1)' * c.dt;
x_l = zeros(n, 1); v_l = zeros(n, 1); x = zeros(n, 1); v = zeros(n, 1);
a = zeros(n, 1); a_cmd = zeros(n, 1); gap_m = zeros(n, 1); valid = true(n, 1);
v_l(1) = c.v0; v(1) = c.v0; x(1) = 0; x_l(1) = c.d0 + c.h * c.v0;
st = struct(); last_cmd = 0; t_rel = NaN;   % 해제 직전 명령과 해제 시각 (7-3단계)
for i = 1:n-1
    % 앞차
    al = 0; if t(i) >= c.t_brake && v_l(i) > c.v_lead_2, al = c.a_lead; end
    v_l(i+1) = v_l(i) + al * c.dt;
    if t(i) >= c.t_brake, v_l(i+1) = max(v_l(i+1), c.v_lead_2); end
    x_l(i+1) = x_l(i) + v_l(i) * c.dt;
    % 센서와 제어
    gap = x_l(i) - x(i); dv = v_l(i) - v(i);
    [g_meas, dv_meas, ok, st] = sensor(t(i), gap, dv, st);
    gap_m(i) = g_meas; valid(i) = ok;
    if ok
        a_cmd(i) = k1 * (g_meas - c.d0 - c.h * v(i)) + k2 * dv_meas;
        a_cmd(i) = min(max(a_cmd(i), c.a_min), c.a_max);
        last_cmd = a_cmd(i);
    else
        a_cmd(i) = NaN;  % 제어 해제: 해제 방식은 7-3에서 sensor 쪽 상태로 처리
        if isnan(t_rel), t_rel = t(i); end
    end
    cmd = a_cmd(i);
    if isnan(cmd), cmd = st.release_cmd(t(i), v(i), p, struct('t_rel', t_rel, 'a_last', last_cmd)); end
    a(i+1) = a(i) + (cmd - a(i)) / c.tau * c.dt;
    % 차량: 원하는 가속도 a를 내도록 구동력 = m a + 저항
    [~, R] = vehicle_long(v(i), 0, p);
    F = p.m * a(i+1) + R.aero + R.roll + R.grade;
    v(i+1) = max(v(i) + vehicle_long(v(i), F, p) * c.dt, 0);
    x(i+1) = x(i) + v(i) * c.dt;
end
gap_m(end) = gap_m(end-1); a_cmd(end) = a_cmd(end-1); valid(end) = valid(end-1);
out = struct('t', t, 'gap', x_l - x, 'gap_meas', gap_m, 'v', v, 'v_lead', v_l, 'a', a, ...
    'a_cmd', a_cmd, 'valid', valid, 'gap_des', c.d0 + c.h * v);
end

function [gap_m, dv_m, ok, st] = truth_sensor(~, gap, dv, st)
%TRUTH_SENSOR 오차 없는 센서: 참값을 그대로 돌려준다
gap_m = gap; dv_m = dv; ok = true;
end
