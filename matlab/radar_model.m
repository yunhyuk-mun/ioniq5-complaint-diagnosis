function [gap_m, dv_m, ok, st] = radar_model(t, gap, dv, st, cfg)
%RADAR_MODEL 단순 레이더 오차 모델 (지능형자동차 강의자료 05 Perception의 오차 구분을 따름)
%   거리·상대속도 참값에 고정 지연, 무작위 잡음(정규분포), 끊김 구간을 넣고, 선택적으로 1차 저역 필터를 건다.
%   cfg 필드
%     dt        적분 간격 [s]
%     delay     측정 지연 [s]
%     sg, sv    거리·상대속도 잡음 표준편차 [m], [m/s]
%     tf        1차 필터 시정수 [s], 0이면 필터 없음
%     drop      끊김 구간 [시작 끝; ...] [s]. 끊긴 동안은 마지막 측정값을 유지
%     release_after  끊김이 이 시간보다 길면 "레이더 가림"으로 제어 해제 [s], Inf이면 해제 안 함
%     release_cmd    해제 후 가속도 명령 함수 @(t, v, p, info), info.t_rel 해제 시각, info.a_last 해제 직전 명령 (7-3단계)
if ~isfield(st, 'init')
    nb = max(1, round(cfg.delay / cfg.dt) + 1);
    st.init = true; st.buf = repmat([gap dv], nb, 1);
    st.last = [gap dv]; st.f = [gap dv]; st.drop_start = NaN;
    if isfield(cfg, 'release_cmd'), st.release_cmd = cfg.release_cmd; end
end
% 지연: 버퍼 맨 앞이 지연된 값
st.buf = [st.buf(2:end, :); gap dv];
meas = st.buf(1, :) + [cfg.sg * randn, cfg.sv * randn];
% 끊김
in_drop = ~isempty(cfg.drop) && any(t >= cfg.drop(:, 1) & t < cfg.drop(:, 2));
ok = true;
if in_drop
    if isnan(st.drop_start), st.drop_start = t; end
    meas = st.last;
    if t - st.drop_start >= cfg.release_after, ok = false; end
else
    st.drop_start = NaN; st.last = meas;
end
% 1차 저역 필터
if cfg.tf > 0
    st.f = st.f + cfg.dt / cfg.tf * (meas - st.f); meas = st.f;
end
gap_m = meas(1); dv_m = meas(2);
end
