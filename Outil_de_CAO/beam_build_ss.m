function [A_ss,B_ss,C_ss,D_ss,beam_ss,info] = beam_build_ss(m_charge_kg)
%BEAM_BUILD_SS  Lame encastrée-libre (Euler–Bernoulli) -> state-space continu
%   Entrée : m_charge_kg [kg] (0 à 0.1 typ.)
%   Sorties : A_ss,B_ss,C_ss,D_ss pour bloc State-Space Simulink
%   y(1)=w(L,t) (bout), y(2)=w(a,t) (bobine)
%   u(t)=force au point a (N) (ex: u = Fb - P)

if nargin < 1 || isempty(m_charge_kg)
    m_charge_kg = 0;
end

%% Paramètres géométrie / matériau
b = 7.1e-2;         % [m]
h = 1.5e-3;         % [m]
L = 24.3e-2;        % [m]
J = b*h^3/12;       % [m^4]

dens = 1850;        % [kg/m^3]
mu0  = dens*b*h;    % [kg/m] masse linéique

Eeff = 24e9;        % [Pa]  <-- mets ici ton E_eff final

%% Amortissement depuis fit Ae^{-b t}
b_decay = 0.35443;      % [1/s]
alpha   = 2*b_decay;    % [1/s]  -> C = alpha*M

%% Discrétisation spatiale (style code prof)
nx_phys = 20;
dx = L/(nx_phys-1);

x_full  = -dx:dx:(L+dx);
nx_full = numel(x_full);

int_idx = 3:(nx_full-2);
N = numel(int_idx);

%% Position d'application / masses
a_pos = 0.146;     % [m]
m_act = 0.09;      % [kg]
m_tip = 1e-3;      % [kg]

[~, idx_force_full] = min(abs(x_full - a_pos));
k_force = find(int_idx == idx_force_full, 1);
if isempty(k_force)
    [~, k_force] = min(abs(x_full(int_idx) - a_pos));
    idx_force_full = int_idx(k_force);
end

mu_eff_full = mu0 * ones(1, nx_full);

% masse actionneur + masse déposée au point a
mu_eff_full(idx_force_full) = mu_eff_full(idx_force_full) + (m_act + m_charge_kg)/dx;

% masse au bout lumpée sur x=L-dx (dernier noeud dynamique)
idx_last_int_full = int_idx(end);
mu_eff_full(idx_last_int_full) = mu_eff_full(idx_last_int_full) + m_tip/dx;

mu_eff_int = mu_eff_full(int_idx);

%% Reconstruction points fantômes (BC comme code prof)
T = zeros(nx_full, N);
for k = 1:N
    T(int_idx(k), k) = 1;
end

idx_L_full  = nx_full-1;
idx_Lp_full = nx_full;

k_last   = N;
k_lastm1 = N-1;

T(idx_L_full,  k_last)   =  2;
T(idx_L_full,  k_lastm1) = -1;

T(idx_Lp_full, k_last)   =  3;
T(idx_Lp_full, k_lastm1) = -2;

%% D4 (stencil 5 points)
st = [1 -4 6 -4 1] / dx^4;

D4_rows = zeros(N, nx_full);
for k = 1:N
    i = int_idx(k);
    D4_rows(k, i-2:i+2) = st;
end
D4_int = D4_rows * T;

%% M, K, C
M = diag(mu_eff_int * dx);
K = (Eeff * J) * (D4_int * dx);
C = alpha * M;

%% Entrée force au point a
Bf = zeros(N,1);
Bf(k_force) = 1;

%% State-space continu
Z = zeros(N);
I = eye(N);

A_ss = [ Z,      I;
        -M\K,  -M\C ];

B_ss = [ zeros(N,1);
          M\Bf ];

%% Sorties : w(L,t) et w(a,t)
Cw_tip = zeros(1,N);
Cw_tip(1,k_last)   =  2;
Cw_tip(1,k_lastm1) = -1;

Cw_act = zeros(1,N);
Cw_act(1,k_force) = 1;

C_ss = [Cw_tip, zeros(1,N);
        Cw_act, zeros(1,N)];
D_ss = zeros(2,1);

beam_ss = ss(A_ss,B_ss,C_ss,D_ss);

info = struct();
info.dx = dx; info.L = L; info.N = N;
info.k_force = k_force; info.a_pos = a_pos;
info.m_charge_kg = m_charge_kg;
info.Eeff = Eeff; info.alpha = alpha;
end