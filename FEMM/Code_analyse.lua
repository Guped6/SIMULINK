-- ============================================================
--  FEMM Lua 4.0  -  Analyse-only LUT (mm + axisymétrique)
--  Position min = celle du fichier .fem (bobine+support au plus bas)
--  Position max = min + 41.472 mm (translation verticale en +z)
--
--  Déplace: bobine (groupe 3) + support (groupe 9)
--  Mesure la force: Fz sur bobine uniquement (groupe 3)
--
--  LUT:
--   A) Phi_ba(x)
--   B) Lb(x)
--   C) Kb(x)
--   D) dLb/dx
--   E) dPhi_ba/dx
-- ============================================================

-- ===================== PARAMETRES =====================
FEM_FILE      = "Femm actioneur lineaire node et segments initial.fem"  -- .fem à la position MIN
TEMP_FILE     = "temp.fem"

CIRCUIT_NAME  = "Circuitbobine"     -- nom exact du circuit

COIL_GROUP    = 3                  -- bobine
SUPPORT_GROUP = 9                  -- support bobine

-- Course (mm)
XMIN_MM = 0.0
XMAX_MM = 41.472

-- Pas (mm)
dx_mm  = 1.0       -- 1 mm recommandé (mettre 2.0 si trop long)

-- Courant (A): on fera 0, +Iamp, -Iamp
Iamp   = 1.0

-- Phi_ba(x): 0 => Phi(x,0), 1 => (Phi(+I)+Phi(-I))/2
USE_PHI_AVG = 0

-- Force: 0 => signe FEMM, 1 => abs()
ABS_FORCE = 0

OUT_PREFIX = "LUT_"
-- ======================================================


-- ===================== OUTILS LUA 4.0 =====================
function table_len(t) return getn(t) end

function absval(a)
    if a < 0 then return -a else return a end
end

MOVE_GROUPS = {COIL_GROUP, SUPPORT_GROUP}

function move_groups(dz_mm)
    mi_seteditmode("group")
    for k=1, table_len(MOVE_GROUPS) do
        mi_selectgroup(MOVE_GROUPS[k])
    end
    -- En axi FEMM: x=r, y=z => translate en y pour déplacer en z
    mi_movetranslate(0, dz_mm)
    mi_clearselected()
end

function set_circuit_current(i)
    -- propnum=1 => courant
    mi_modifycircprop(CIRCUIT_NAME, 1, i)
end

function solve_get_flux_force()
    mi_analyze()
    mi_loadsolution()

    i, v, phi = mo_getcircuitproperties(CIRCUIT_NAME)

    mo_groupselectblock(COIL_GROUP)
    Fz = mo_blockintegral(12)   -- force en z (axi)
    mo_clearblock()

    if ABS_FORCE == 1 then
        Fz = absval(Fz)
    end

    mo_close()
    return i, v, phi, Fz
end


-- ===================== LISTE DES POSITIONS =====================
x_mm_arr = {}

k = 1
x = XMIN_MM
while x <= XMAX_MM do
    x_mm_arr[k] = x
    k = k + 1
    x = x + dx_mm
end

-- Ajoute XMAX si nécessaire (dernier pas éventuellement plus petit)
last = x_mm_arr[ table_len(x_mm_arr) ]
if last < XMAX_MM then
    x_mm_arr[k] = XMAX_MM
end

nSteps = table_len(x_mm_arr)


-- ===================== TABLES RESULTATS =====================
x_m_arr  = {}

Phi_ba = {}
Lb     = {}
Kb     = {}
dLdx   = {}
dPhidx = {}

-- Bruts pour debug
Phi0 = {}; Phip = {}; Phim = {}
F0   = {}; Fp   = {}; Fm   = {}


-- ============================================================
-- 1) Ouvrir le .fem MIN et sauvegarder temp
-- ============================================================
open(FEM_FILE)
mi_saveas(TEMP_FILE)
open(TEMP_FILE)
mi_shownames(0)

current_offset_mm = 0.0

-- ============================================================
-- 2) Boucle positions
-- ============================================================
for idx=1, nSteps do

    target_mm = x_mm_arr[idx]
    target_m  = target_mm / 1000.0
    x_m_arr[idx] = target_m

    -- Déplacement relatif
    dz = target_mm - current_offset_mm
    if dz ~= 0 then
        move_groups(dz)
        current_offset_mm = target_mm
    end

    -- ===== Solve I=0 =====
    set_circuit_current(0.0)
    i0, v0, phi0, f0 = solve_get_flux_force()

    -- ===== Solve I=+1 =====
    set_circuit_current(Iamp)
    ip, vp, phip, fp = solve_get_flux_force()

    -- ===== Solve I=-1 =====
    set_circuit_current(-Iamp)
    im, vm, phim, fm = solve_get_flux_force()

    -- Bruts
    Phi0[idx] = phi0; Phip[idx] = phip; Phim[idx] = phim
    F0[idx]   = f0;   Fp[idx]   = fp;   Fm[idx]   = fm

    -- A) Phi_ba(x)
    if USE_PHI_AVG == 1 then
        Phi_ba[idx] = 0.5*(phip + phim)
    else
        Phi_ba[idx] = phi0
    end

    -- B) Lb(x) = (Phi(+I)-Phi(-I))/(2I)
    Lb[idx] = (phip - phim) / (2.0*Iamp)

    -- C) Kb(x) = (F(+I)-F(-I))/(2I)
    Kb[idx] = (fp - fm) / (2.0*Iamp)

    -- D) dLb/dx = (F(+I)+F(-I)-2F(0))/I^2
    dLdx[idx] = (fp + fm - 2.0*f0) / (Iamp*Iamp)

    print("idx=",idx," x_mm=",target_mm," Phi_ba=",Phi_ba[idx]," Lb=",Lb[idx]," Kb=",Kb[idx]," dLdx=",dLdx[idx])
end


-- ============================================================
-- 3) E) dPhi_ba/dx par différence finie
-- (résultat en Wb/m)
-- ============================================================
for idx=1, nSteps do
    if idx == 1 then
        dx1_m = (x_mm_arr[idx+1] - x_mm_arr[idx]) / 1000.0
        dPhidx[idx] = (Phi_ba[idx+1] - Phi_ba[idx]) / dx1_m
    elseif idx == nSteps then
        dxn_m = (x_mm_arr[idx] - x_mm_arr[idx-1]) / 1000.0
        dPhidx[idx] = (Phi_ba[idx] - Phi_ba[idx-1]) / dxn_m
    else
        dxp_m = (x_mm_arr[idx+1] - x_mm_arr[idx-1]) / 1000.0
        dPhidx[idx] = (Phi_ba[idx+1] - Phi_ba[idx-1]) / dxp_m
    end
end


-- ============================================================
-- 4) Écriture LUT
-- ============================================================
fMain = openfile(OUT_PREFIX .. "main.txt","w")
write(fMain, "x_mm x_m Phi_ba(Wb) Lb(H) Kb(N/A) dLb_dx(H/m) dPhi_ba_dx(Wb/m)\n")
for idx=1, nSteps do
    write(fMain,
        x_mm_arr[idx]," ",
        x_m_arr[idx]," ",
        Phi_ba[idx]," ",
        Lb[idx]," ",
        Kb[idx]," ",
        dLdx[idx]," ",
        dPhidx[idx],"\n"
    )
end
closefile(fMain)

fRaw = openfile(OUT_PREFIX .. "raw.txt","w")
write(fRaw, "x_mm Phi0 Phip Phim F0 Fp Fm\n")
for idx=1, nSteps do
    write(fRaw,
        x_mm_arr[idx]," ",
        Phi0[idx]," ",
        Phip[idx]," ",
        Phim[idx]," ",
        F0[idx]," ",
        Fp[idx]," ",
        Fm[idx],"\n"
    )
end
closefile(fRaw)

print("OK: LUT écrites. Points=", nSteps, " de ", XMIN_MM, " à ", XMAX_MM, " mm")
