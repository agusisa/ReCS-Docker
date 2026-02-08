// Heal Potion v2 - Pocion como 4ta "granada". Todos tienen 1 al spawn (una sola por ronda).
// Bind g +potion, tecla 4, mantén G: LClick=tirar (cura area, onda azul), RClick=beber.

#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <fun>
#include <cstrike>

#pragma semicolon 1

#define PLUGIN   "Heal Potion (Blue)"
#define VERSION  "2.0"
#define AUTHOR   "Gandármara"

#define POTION_CLASSNAME "heal_potion_ent"
#define TASK_POTION_EXPLODE 9000

// Modelos: poción distinta a HE (usamos flash como base visual; se puede cambiar por custom)
new const V_MODEL[] = "models/v_flashbang.mdl";   // en mano (azul se puede con custom)
new const P_MODEL[] = "models/p_flashbang.mdl";
new const W_MODEL[] = "models/w_flashbang.mdl";   // en el mundo al tirar

new const SOUND_DRINK[] = "items/smallmedkit1.wav";
new const SPRITE_RING[] = "sprites/white.spr";    // para la onda azul

new gCvarDrinkHeal, gCvarAoEHeal, gCvarRadius, gCvarMaxHP;
new g_PotionCount[33];
new bool:g_InPotionMode[33];
new g_spriteRing;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /potion", "CmdGivePotion");
	register_clcmd("say_team /potion", "CmdGivePotion");
	register_clcmd("+potion", "CmdPotionModeOn");
	register_clcmd("-potion", "CmdPotionModeOff");
	register_clcmd("potion", "CmdPotionToggle");

	RegisterHam(Ham_Spawn, "player", "HamPlayerSpawn", true);
	RegisterHam(Ham_Touch, POTION_CLASSNAME, "HamPotionTouch", false);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_flashbang", "HamFlashPrimary", false);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_flashbang", "HamFlashSecondary", false);
	register_event("DeathMsg", "EvDeath", "a");
	register_event("CurWeapon", "EvCurWeapon", "be", "1=1");

	gCvarDrinkHeal  = register_cvar("potion_drink_heal", "60");
	gCvarAoEHeal    = register_cvar("potion_aoe_heal", "40");
	gCvarRadius     = register_cvar("potion_radius", "220.0");
	gCvarMaxHP      = register_cvar("potion_max_hp", "100");
}

public plugin_precache()
{
	precache_model(V_MODEL);
	precache_model(P_MODEL);
	precache_model(W_MODEL);
	precache_sound(SOUND_DRINK);
	g_spriteRing = precache_model(SPRITE_RING);
}

public client_connect(id)
{
	g_PotionCount[id] = 0;
	g_InPotionMode[id] = false;
}

public client_disconnected(id)
{
	g_PotionCount[id] = 0;
	g_InPotionMode[id] = false;
}

public EvDeath()
{
	new id = read_data(2);
	if (id >= 1 && id <= 32)
		g_InPotionMode[id] = false;
}

public HamPlayerSpawn(id)
{
	if (!is_user_alive(id)) return HAM_IGNORED;
	g_InPotionMode[id] = false;
	// Todos tienen 1 poción al comenzar la partida (una sola)
	g_PotionCount[id] = 1;
	// Dar flashbang para que la poción figure en el slot 4 (lista de granadas)
	set_task(0.2, "TaskGivePotionWeapon", id);
	return HAM_IGNORED;
}

public TaskGivePotionWeapon(id)
{
	if (!is_user_alive(id)) return;
	if (g_PotionCount[id] <= 0) return;
	// Una flashbang = representa la poción en el slot de granadas
	if (cs_get_user_bpammo(id, CSW_FLASHBANG) < 1)
		give_item(id, "weapon_flashbang");
}

public CmdGivePotion(id)
{
	if (!is_user_alive(id)) return PLUGIN_HANDLED;
	// Máximo 1 poción; si ya tiene, no sumar
	if (g_PotionCount[id] >= 1)
	{
		client_print(id, print_chat, "[Potion] Solo podés tener 1 poción. Bind: bind g +potion, tecla 4, mantén G: LClick=tirar, RClick=beber.");
		return PLUGIN_HANDLED;
	}
	g_PotionCount[id] = 1;
	client_print(id, print_chat, "[Potion] +1 poción. Bind g +potion, tecla 4, mantén G: LClick=tirar, RClick=beber.");
	return PLUGIN_HANDLED;
}

public CmdPotionModeOn(id)
{
	if (!is_user_alive(id) || g_PotionCount[id] <= 0) return PLUGIN_HANDLED;
	g_InPotionMode[id] = true;
	// Cambiar a slot 4 (flash) para que se vea la "poción" en mano con nuestro modelo
	if (get_user_weapon(id) != CSW_FLASHBANG)
		client_cmd(id, "weapon_flashbang");
	return PLUGIN_HANDLED;
}
public CmdPotionModeOff(id) { g_InPotionMode[id] = false; return PLUGIN_HANDLED; }

public CmdPotionToggle(id)
{
	if (g_InPotionMode[id])
		g_InPotionMode[id] = false;
	else
		g_InPotionMode[id] = true;
	return PLUGIN_HANDLED;
}

public EvCurWeapon(id)
{
	if (!is_user_alive(id)) return;
	if (g_InPotionMode[id] && g_PotionCount[id] > 0 && get_user_weapon(id) == CSW_FLASHBANG)
	{
		set_pev(id, pev_viewmodel2, V_MODEL);
		set_pev(id, pev_weaponmodel2, P_MODEL);
	}
}

public HamFlashPrimary(weaponEnt)
{
	new id = get_pdata_cbase(weaponEnt, 41, 5);
	if (id < 1 || id > 32) return HAM_IGNORED;
	if (g_InPotionMode[id] && g_PotionCount[id] > 0)
	{
		ThrowPotion(id);
		cs_set_user_bpammo(id, CSW_FLASHBANG, 0);
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

public HamFlashSecondary(weaponEnt)
{
	new id = get_pdata_cbase(weaponEnt, 41, 5);
	if (id < 1 || id > 32) return HAM_IGNORED;
	if (g_InPotionMode[id] && g_PotionCount[id] > 0)
	{
		DrinkPotion(id);
		cs_set_user_bpammo(id, CSW_FLASHBANG, 0);
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

stock DrinkPotion(id)
{
	if (g_PotionCount[id] <= 0) return;
	g_PotionCount[id]--;
	g_InPotionMode[id] = false;
	HealPlayer(id, get_pcvar_num(gCvarDrinkHeal));
	emit_sound(id, CHAN_ITEM, SOUND_DRINK, 1.0, ATTN_NORM, 0, PITCH_NORM);
	client_print(id, print_chat, "[Potion] Bebiste la poción. Pociones restantes: %d", g_PotionCount[id]);
}

stock ThrowPotion(id)
{
	if (g_PotionCount[id] <= 0) return;
	g_PotionCount[id]--;
	g_InPotionMode[id] = false;

	new Float:origin[3], Float:velocity[3], Float:angles[3];
	pev(id, pev_origin, origin);
	pev(id, pev_v_angle, angles);
	velocity_by_aim(id, 800, velocity);
	origin[2] += 20.0;

	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	if (!pev_valid(ent)) return;

	set_pev(ent, pev_classname, POTION_CLASSNAME);
	engfunc(EngFunc_SetModel, ent, W_MODEL);
	engfunc(EngFunc_SetOrigin, ent, origin);
	set_pev(ent, pev_velocity, velocity);
	set_pev(ent, pev_angles, angles);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_solid, SOLID_BBOX);
	set_pev(ent, pev_owner, id);
	set_pev(ent, pev_iuser3, _:cs_get_user_team(id));
	set_pev(ent, pev_gravity, 0.5);
	/* Guardar task id para cancelar si explota al tocar */
	new tid = set_task(2.0, "TaskPotionExplode", ent);
	set_pev(ent, pev_iuser2, tid);

	client_print(id, print_chat, "[Potion] Tiraste la poción. Pociones restantes: %d", g_PotionCount[id]);
}

public HamPotionTouch(ent, other)
{
	if (!pev_valid(ent)) return HAM_IGNORED;
	static classname[24];
	pev(ent, pev_classname, classname, charsmax(classname));
	if (!equal(classname, POTION_CLASSNAME)) return HAM_IGNORED;
	/* Al tocar suelo o cualquier superficie: explotar/romperse (no rebotar) */
	remove_task(pev(ent, pev_iuser2));
	DoPotionExplode(ent);
	return HAM_IGNORED;
}

public TaskPotionExplode(ent)
{
	if (!pev_valid(ent)) return;
	static classname[24];
	pev(ent, pev_classname, classname, charsmax(classname));
	if (!equal(classname, POTION_CLASSNAME)) return;
	DoPotionExplode(ent);
}

stock DoPotionExplode(ent)
{
	if (!pev_valid(ent)) return;
	static classname[24];
	pev(ent, pev_classname, classname, charsmax(classname));
	if (!equal(classname, POTION_CLASSNAME)) return;

	new Float:origin[3];
	pev(ent, pev_origin, origin);
	new throwerTeam = pev(ent, pev_iuser3);
	new heal = get_pcvar_num(gCvarAoEHeal);
	new Float:radius = get_pcvar_float(gCvarRadius);

	PotionBlueEffect(origin, radius);

	new victim = -1;
	while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, origin, radius)) != 0)
	{
		if (victim < 1 || victim > 32) continue;
		if (!is_user_alive(victim)) continue;
		if (_:cs_get_user_team(victim) != throwerTeam) continue;

		HealPlayer(victim, heal);
		emit_sound(victim, CHAN_ITEM, SOUND_DRINK, 0.6, ATTN_NORM, 0, PITCH_NORM);
	}

	engfunc(EngFunc_RemoveEntity, ent);
}

stock PotionBlueEffect(Float:origin[3], Float:radius)
{
	new x = floatround(origin[0]);
	new y = floatround(origin[1]);
	new z = floatround(origin[2]);
	new h = floatround(radius * 1.2);

	// Cilindro azul (onda expansiva visible)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMCYLINDER);
	write_coord(x);
	write_coord(y);
	write_coord(z + 16);
	write_coord(x);
	write_coord(y);
	write_coord(z + h);
	write_short(g_spriteRing);
	write_byte(0);
	write_byte(0);
	write_byte(3);
	write_byte(30);
	write_byte(0);
	write_byte(50);
	write_byte(120);
	write_byte(255);
	write_byte(220);
	write_byte(0);
	message_end();
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
