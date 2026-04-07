-- ============================================================
--  FEMM Lua 4.0  -  Test de linearite Phi_bi(x,I)=L(x)*I
--  Mode: magnétostatique, unités mm, axisymétrique
--
--  Balaye positions (pas 4 mm) et courants entre -2.9A et +2.9A
--  Déplace: bobine (groupe 3) + support (groupe 9)
--  Mesure: Phi = mo_getcircuitproperties (liaison de flux, Wb)
--
--  Sorties:
--   LIN_details.txt  : résultats détaillés (par position et par I)
--   LIN_summary.txt  : résumé (écarts max par position)
-- ============================================================

-- ===================== PARAMETRES A ADAPTER =====================
FEM_FILE      = "Femm actioneur lineaire node et segments initial.fem" -- .fem à position MIN
TEMP_FILE     = "temp_lin.fem"

CIRCUIT_NAME  = "Circuitbobine"

COIL_GROUP    = 3
SUPPORT_GROUP = 9

XMIN_MM = 0.0
XMAX_MM = 41.472
dx_mm   = 4.0         -- demandé: 4 mm

-- Liste des amplitudes de courant (A) à tester (symétrique +/-I)
-- (Tu peux en enlever pour aller plus vite)
I_list = {0.5, 1.0, 1.5, 2.0, 2.5, 2.9}

OUT_DETAILS = "LIN_details.txt"
OUT_SUMMARY = "LIN_summary.txt"
-- =================================================================

function table_len(t) return getn(t) end

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
    mi_modifycircprop(CIRCUIT_NAME, 1, i)
end

function solve_get_phi()
    mi_analyze()
    mi_loadsolution()
    i, v, phi = mo_getcircuitproperties(CIRCUIT_NAME)
    mo_close()
    return phi
end

function absval(a)
    if a < 0 then return -a else return a end
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
last = x_mm_arr[ table_len(x_mm_arr) ]
if last < XMAX_MM then
    x_mm_arr[k] = XMAX_MM
end
nSteps = table_len(x_mm_arr)

-- ===================== OUVERTURE FICHIER + TEMP =====================
open(FEM_FILE)
mi_saveas(TEMP_FILE)
open(TEMP_FILE)
mi_shownames(0)

current_offset_mm = 0.0

-- ===================== OUVERTURE FICHIERS SORTIE =====================
fDet = openfile(OUT_DETAILS, "w")
write(fDet, "x_mm x_m I_A Phi_plus(Wb) Phi_minus(Wb) Phi0(Wb) L_xI(H) Lref_1A(H) relDev_L(%) relErr_PhiPred(%)\n")

fSum = openfile(OUT_SUMMARY, "w")
write(fSum, "x_mm x_m Phi0(Wb) Lref_1A(H) maxRelDev_L(%) maxRelErr_PhiPred(%)\n")

-- ============================================================
--  BOUCLE POSITIONS
-- ============================================================
for idx=1, nSteps do
    x_mm = x_mm_arr[idx]
    x_m  = x_mm / 1000.0

    -- déplacement relatif
    dz = x_mm - current_offset_mm
    if dz ~= 0 then
        move_groups(dz)
        current_offset_mm = x_mm
    end

    -- Solve I=0 -> Phi0 (bias aimant)
    set_circuit_current(0.0)
    Phi0 = solve_get_phi()

    -- --- On prend Lref à 1A (doit exister dans I_list) ---
    -- Si 1.0A n'est pas dans la liste, on le calcule quand même.
    -- (Mais ici il est dans I_list par défaut.)
    set_circuit_current( 1.0)
    Phi_p1 = solve_get_phi()
    set_circuit_current(-1.0)
    Phi_m1 = solve_get_phi()
    Lref = (Phi_p1 - Phi_m1) / (2.0 * 1.0)

    maxDevL = 0.0
    maxErrPhi = 0.0

    -- Boucle sur amplitudes
    for j=1, table_len(I_list) do
        Iamp = I_list[j]

        -- Solve +I et -I
        set_circuit_current( Iamp)
        Phi_p = solve_get_phi()
        set_circuit_current(-Iamp)
        Phi_m = solve_get_phi()

        -- L(x,I) symétrique
        LxI = (Phi_p - Phi_m) / (2.0 * Iamp)

        -- Déviation relative de L vs Lref
        relDevL = 0.0
        if absval(Lref) > 0 then
            relDevL = 100.0 * (LxI - Lref) / Lref
        end
        if absval(relDevL) > maxDevL then maxDevL = absval(relDevL) end

        -- Erreur de prédiction flux (linéaire) : Phi_pred = Phi0 + Lref*I
        Phi_pred = Phi0 + Lref * Iamp
        relErrPhi = 0.0
        if absval(Phi_p) > 0 then
            relErrPhi = 100.0 * (Phi_p - Phi_pred) / Phi_p
        end
        if absval(relErrPhi) > maxErrPhi then maxErrPhi = absval(relErrPhi) end

        -- Ecriture détail
        write(fDet,
            x_mm, " ",
            x_m, " ",
            Iamp, " ",
            Phi_p, " ",
            Phi_m, " ",
            Phi0, " ",
            LxI, " ",
            Lref, " ",
            relDevL, " ",
            relErrPhi, "\n"
        )
    end

    -- Résumé par position
    write(fSum,
        x_mm, " ",
        x_m, " ",
        Phi0, " ",
        Lref, " ",
        maxDevL, " ",
        maxErrPhi, "\n"
    )

    print("OK pos x_mm=", x_mm, " Lref=", Lref, " maxDevL%=", maxDevL, " maxErrPhi%=", maxErrPhi)
end

closefile(fDet)
closefile(fSum)

print("FIN: fichiers ecrits -> ", OUT_DETAILS, " et ", OUT_SUMMARY)
