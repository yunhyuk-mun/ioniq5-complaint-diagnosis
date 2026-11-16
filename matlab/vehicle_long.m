function [dvdt, R] = vehicle_long(v, F, p)
%VEHICLE_LONG 차량 종방향 운동 (강의자료 차량동역학 식 2-10, 3-1, 4-4)
%   m dv/dt = F - 1/2 rho Cd A v^2 - fr m g cos(theta) - m g sin(theta)
%   v: 속도 [m/s], F: 구동(+)·제동(-) 힘 [N]
R.aero  = 0.5 * p.rho * p.Cd * p.A * v.^2;
R.roll  = p.fr * p.m * p.g * cos(p.theta) * ones(size(v));
R.grade = p.m * p.g * sin(p.theta) * ones(size(v));
dvdt = (F - R.aero - R.roll - R.grade) / p.m;
end
