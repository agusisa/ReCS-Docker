// Heal Potion - Pocion que cura (usa granada HE como base)
// /potion = te dan una. LClick = tirar (cura en area a compañeros). RClick = beber (cura solo).
// Autor: Gandármara | Ajustes: modelos opcionales, offset Linux

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <fun>
#include <cstrike>

#pragma semicolon 1

#define PLUGIN  "Heal Potion (Blue)"
#define VERSION "1.0"
#define AUTHOR  "Gandármara"

// Poner en 1 solo si tenes los .mdl en models/heal_potion/
#define USE_CUSTOM_MODELS 0

#define POTION_FLAG 1337

#if USE_CUSTOM_MODELS
new const V_MODEL[] = "models/heal_potion/v_heal_potion.mdl";
new const P_MODEL[] = "models/heal_potion/p_heal_potion.mdl";
new const W_MODEL[] = "models/heal_potion/w_heal_potion.mdl";
#endif
new const DEFAULT_W_HE[] = "models/w_hegrenade.mdl";

new gCvarDrinkHeal;
new gCvarAoEHeal;
new gCvarRadius;
new gCvarMaxHP;
new bool:gHasPotion[33];

// Linux server: m_pPlayer offset 5 (Windows 4)
#define OFFSET_WEAPON_PLAYER 5

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /potion", "CmdGivePotion");
	register_clcmd("say_team /potion", "CmdGivePotion");

	register_event("CurWeapon", "EvCurWeapon", "be", "1=1");
	register_forward(FM_SetModel, "FwSetModel");
	RegisterHam(Ham_Think, "grenade", "HamGrenadeThink");
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_hegrenade", "HamHeSecondary", false);

	register_event("DeathMsg", "EvDeath", "a");
	RegisterHam(Ham_Spawn, "player", "HamPlayerSpawn", true);

	gCvarDrinkHeal = register_cvar("potion_drink_heal", "60");
	gCvarAoEHeal   = register_cvar("potion_aoe_heal", "40");
	gCvarRadius    = register_cvar("potion_radius", "220.0");
	gCvarMaxHP     = register_cvar("potion_max_hp", "100");
}

public plugin_precache()
{
#if USE_CUSTOM_MODELS
	precache_model(V_MODEL);
	precache_model(P_MODEL);
	precache_model(W_MODEL);
#endif
	precache_sound("items/smallmedkit1.wav");
}

public client_connect(id) { gHasPotion[id] = false; }
public client_disconnected(id) { gHasPotion[id] = false; }

public HamPlayerSpawn(id)
{
	if (!is_user_alive(id)) return HAM_IGNORED;
	return HAM_IGNORED;
}

public EvDeath()
{
	new id = read_data(2);
	if (1 <= id <= 32) gHasPotion[id] = false;
}

public CmdGivePotion(id)
{
	if (!is_user_alive(id)) return PLUGIN_HANDLED;

	GivePotion(id);
	client_print(id, print_chat, "[Potion] Pocion azul (HE). LClick=tira (cura area), RClick=bebe (cura solo).");
	return PLUGIN_HANDLED;
}

stock GivePotion(id)
{
	new count = cs_get_user_bpammo(id, CSW_HEGRENADE);

	if (count <= 0)
	{
		give_item(id, "weapon_hegrenade");
		cs_set_user_bpammo(id, CSW_HEGRENADE, 1);
	}
	else
	{
		cs_set_user_bpammo(id, CSW_HEGRENADE, count + 1);
	}

	gHasPotion[id] = true;
	ApplyPotionModelsIfHolding(id);
}

public EvCurWeapon(id)
{
	if (!is_user_alive(id)) return;
	ApplyPotionModelsIfHolding(id);
}

stock ApplyPotionModelsIfHolding(id)
{
	if (!gHasPotion[id]) return;
	if (get_user_weapon(id) != CSW_HEGRENADE) return;

#if USE_CUSTOM_MODELS
	set_pev(id, pev_viewmodel2, V_MODEL);
	set_pev(id, pev_weaponmodel2, P_MODEL);
#endif
}

public FwSetModel(ent, const model[])
{
	if (!pev_valid(ent)) return FMRES_IGNORED;
	if (!equal(model, DEFAULT_W_HE)) return FMRES_IGNORED;

	static classname[16];
	pev(ent, pev_classname, classname, charsmax(classname));
	if (!equal(classname, "grenade")) return FMRES_IGNORED;

	new owner = pev(ent, pev_owner);
	if (!(1 <= owner <= 32)) return FMRES_IGNORED;
	if (!gHasPotion[owner]) return FMRES_IGNORED;

	set_pev(ent, pev_iuser4, POTION_FLAG);
	set_pev(ent, pev_iuser3, _:cs_get_user_team(owner));

#if USE_CUSTOM_MODELS
	engfunc(EngFunc_SetModel, ent, W_MODEL);
#endif

	new left = cs_get_user_bpammo(owner, CSW_HEGRENADE);
	if (left <= 0) gHasPotion[owner] = false;

	return FMRES_SUPERCEDE;
}

public HamHeSecondary(weaponEnt)
{
	new id = get_pdata_cbase(weaponEnt, 41, OFFSET_WEAPON_PLAYER);

	if (!(1 <= id <= 32)) return HAM_IGNORED;
	if (!is_user_alive(id)) return HAM_IGNORED;
	if (!gHasPotion[id]) return HAM_IGNORED;
	if (get_user_weapon(id) != CSW_HEGRENADE) return HAM_IGNORED;

	new ammo = cs_get_user_bpammo(id, CSW_HEGRENADE);
	if (ammo <= 0) { gHasPotion[id] = false; return HAM_SUPERCEDE; }

	cs_set_user_bpammo(id, CSW_HEGRENADE, ammo - 1);
	if (ammo - 1 <= 0) gHasPotion[id] = false;

	HealPlayer(id, get_pcvar_num(gCvarDrinkHeal));
	emit_sound(id, CHAN_ITEM, "items/smallmedkit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);

	return HAM_SUPERCEDE;
}

public HamGrenadeThink(ent)
{
	if (!pev_valid(ent)) return HAM_IGNORED;
	if (pev(ent, pev_iuser4) != POTION_FLAG) return HAM_IGNORED;

	new Float:dmgtime;
	pev(ent, pev_dmgtime, dmgtime);
	if (dmgtime > get_gametime()) return HAM_IGNORED;

	new Float:origin[3];
	pev(ent, pev_origin, origin);
	new throwerTeam = pev(ent, pev_iuser3);

	new heal = get_pcvar_num(gCvarAoEHeal);
	new Float:radius = get_pcvar_float(gCvarRadius);

	new victim = -1;
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, origin, radius)) != 0)
	{
		if (victim < 1 || victim > 32) continue;
		if (!is_user_alive(victim)) continue;
		if (_:cs_get_user_team(victim) != throwerTeam) continue;

		HealPlayer(victim, heal);
		emit_sound(victim, CHAN_ITEM, "items/smallmedkit1.wav", 0.6, ATTN_NORM, 0, PITCH_NORM);
	}

	engfunc(EngFunc_RemoveEntity, ent);
	return HAM_SUPERCEDE;
}

stock HealPlayer(id, amount)
{
	if (!is_user_alive(id)) return;

	new maxhp = get_pcvar_num(gCvarMaxHP);
	new Float:hp;
	pev(id, pev_health, hp);

	new newhp = floatround(hp) + amount;
	if (newhp > maxhp) newhp = maxhp;

	set_pev(id, pev_health, float(newhp));
}
