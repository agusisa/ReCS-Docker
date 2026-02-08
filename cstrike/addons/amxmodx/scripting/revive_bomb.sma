/**
 * Revive Bomb - Revivir aliado con E (3s) / Plantar bomba en enemigo
 * Al intentar revivir un cadáver con bomba: explosión, mueren revividor y cadáver (gibs).
 */
#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#pragma semicolon 1

#define PLUGIN  "Revive Bomb"
#define VERSION "1.0"
#define AUTHOR  "ReCS"

#define REVIVE_TIME    3.0
#define PLANT_TIME     1.5
#define CORPSE_RADIUS  70.0
#define TICK_INTERVAL  0.1

#define TASK_CORPSE       2000
#define TASK_PROGRESS     2001
#define TE_EXPLODEMODEL   107

#define CLASS_REVIVE_CORPSE "revive_corpse"
#define pev_corpse_team     pev_iuser1
#define pev_corpse_bomb     pev_iuser4

new g_msgBarTime;
new Float:g_progress[33];
new g_target_ent[33];
new bool:g_was_reviving[33];
new bool:g_was_planting[33];

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	g_msgBarTime = get_user_msgid("BarTime");
	RegisterHam(Ham_Killed, "player", "OnPlayerKilled", 1);
	register_forward(FM_PlayerPreThink, "OnPreThink");
}

public plugin_precache() {
	precache_model("models/player/arctic/arctic.mdl");
	precache_model("models/player/terror/terror.mdl");
	precache_model("models/player/leet/leet.mdl");
	precache_model("models/player/guerilla/guerilla.mdl");
	precache_model("models/player/gign/gign.mdl");
	precache_model("models/player/sas/sas.mdl");
	precache_model("models/player/gsg9/gsg9.mdl");
	precache_model("models/player/urban/urban.mdl");
	precache_model("models/player/vip/vip.mdl");
	precache_sound("weapons/c4_explode_01.wav");
	precache_model("models/hgibs.mdl");
}

public OnPlayerKilled(victim, killer, shouldgib) {
	if (!is_user_connected(victim))
		return;
	set_task(0.5, "TaskCreateCorpse", victim + TASK_CORPSE);
}

public TaskCreateCorpse(taskid) {
	new id = taskid - TASK_CORPSE;
	if (!is_user_connected(id) || is_user_alive(id))
		return;
	CreateReviveCorpse(id);
}

CreateReviveCorpse(id) {
	set_pev(id, pev_effects, EF_NODRAW);

	static model[32];
	cs_get_user_model(id, model, 31);
	static player_model[64];
	format(player_model, 63, "models/player/%s/%s.mdl", model, model);

	static Float:origin[3];
	pev(id, pev_origin, origin);

	static Float:mins[3], Float:maxs[3];
	xs_vec_set(mins, -16.0, -16.0, -34.0);
	xs_vec_set(maxs, 16.0, 16.0, 34.0);
	if (pev(id, pev_flags) & FL_DUCKING) {
		mins[2] /= 2.0;
		maxs[2] /= 2.0;
	}

	static Float:angles[3];
	pev(id, pev_angles, angles);
	angles[2] = 0.0;

	new sequence = pev(id, pev_sequence);
	new team = _:cs_get_user_team(id);

	new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	if (!pev_valid(ent))
		return;

	set_pev(ent, pev_classname, CLASS_REVIVE_CORPSE);
	engfunc(EngFunc_SetModel, ent, player_model);
	engfunc(EngFunc_SetOrigin, ent, origin);
	engfunc(EngFunc_SetSize, ent, mins, maxs);
	set_pev(ent, pev_solid, SOLID_TRIGGER);
	set_pev(ent, pev_movetype, MOVETYPE_TOSS);
	set_pev(ent, pev_owner, id);
	set_pev(ent, pev_angles, angles);
	set_pev(ent, pev_sequence, sequence);
	set_pev(ent, pev_frame, 9999.9);
	set_pev(ent, pev_corpse_team, team);
	set_pev(ent, pev_corpse_bomb, 0);
}

public OnPreThink(id) {
	if (!is_user_connected(id) || !is_user_alive(id))
		return FMRES_IGNORED;

	new buttons = pev(id, pev_button);
	if (!(buttons & IN_USE)) {
		if (g_was_reviving[id] || g_was_planting[id]) {
			g_progress[id] = 0.0;
			g_target_ent[id] = 0;
			g_was_reviving[id] = false;
			g_was_planting[id] = false;
			MsgBarTime(id, 0);
		}
		return FMRES_IGNORED;
	}

	new corpse = FindReviveCorpse(id);
	if (corpse <= 0) {
		if (g_was_reviving[id] || g_was_planting[id]) {
			g_progress[id] = 0.0;
			g_target_ent[id] = 0;
			g_was_reviving[id] = false;
			g_was_planting[id] = false;
			MsgBarTime(id, 0);
		}
		return FMRES_IGNORED;
	}

	new owner = pev(corpse, pev_owner);
	if (!is_user_connected(owner)) {
		RemoveCorpse(corpse);
		return FMRES_IGNORED;
	}

	new owner_team = pev(corpse, pev_corpse_team);
	new my_team = _:cs_get_user_team(id);
	new has_bomb = pev(corpse, pev_corpse_bomb);

	if (owner_team == my_team) {
		/* Aliado: revivir. Si tiene bomba, al completar explota. */
		if (has_bomb) {
			g_was_reviving[id] = true;
			g_was_planting[id] = false;
			g_target_ent[id] = corpse;
			g_progress[id] += TICK_INTERVAL;
			MsgBarTime(id, floatround(REVIVE_TIME - g_progress[id]));
			if (g_progress[id] >= REVIVE_TIME) {
				ExplodeCorpse(corpse, id, owner);
				ResetProgress(id);
				return FMRES_IGNORED;
			}
		} else {
			g_was_reviving[id] = true;
			g_was_planting[id] = false;
			g_target_ent[id] = corpse;
			g_progress[id] += TICK_INTERVAL;
			MsgBarTime(id, floatround(REVIVE_TIME - g_progress[id]));
			if (g_progress[id] >= REVIVE_TIME) {
				DoRevive(owner, corpse);
				ResetProgress(id);
			}
		}
	} else {
		/* Enemigo: plantar bomba */
		g_was_planting[id] = true;
		g_was_reviving[id] = false;
		g_target_ent[id] = corpse;
		g_progress[id] += TICK_INTERVAL;
		MsgBarTime(id, floatround(PLANT_TIME - g_progress[id]));
		if (g_progress[id] >= PLANT_TIME) {
			set_pev(corpse, pev_corpse_bomb, 1);
			ResetProgress(id);
		}
	}
	return FMRES_IGNORED;
}

FindReviveCorpse(id) {
	static Float:origin[3];
	pev(id, pev_origin, origin);
	new ent = 0;
	static classname[32];
	while ((ent = engfunc(EngFunc_FindEntityInSphere, ent, origin, CORPSE_RADIUS)) != 0) {
		pev(ent, pev_classname, classname, 31);
		if (equali(classname, CLASS_REVIVE_CORPSE) && IsVisible(id, ent))
			return ent;
	}
	return 0;
}

bool:IsVisible(id, entity) {
	static Float:start[3], Float:dest[3], Float:viewOfs[3];
	pev(id, pev_origin, start);
	pev(id, pev_view_ofs, viewOfs);
	xs_vec_add(start, viewOfs, start);
	pev(entity, pev_origin, dest);
	engfunc(EngFunc_TraceLine, start, dest, 0, id, 0);
	new Float:fraction;
	get_tr2(0, TR_flFraction, fraction);
	return (fraction >= 1.0 || get_tr2(0, TR_pHit) == entity);
}

DoRevive(id, corpse) {
	RemoveCorpse(corpse);
	if (!is_user_connected(id))
		return;
	set_pev(id, pev_deadflag, DEAD_RESPAWNABLE);
	dllfunc(DLLFunc_Spawn, id);
	set_pev(id, pev_iuser1, 0);
	set_task(0.1, "TaskCheckRespawn", id + TASK_PROGRESS);
}

public TaskCheckRespawn(taskid) {
	new id = taskid - TASK_PROGRESS;
	if (!is_user_connected(id))
		return;
	if (pev(id, pev_iuser1))
		set_task(0.1, "TaskRespawn", id + TASK_PROGRESS);
}

public TaskRespawn(taskid) {
	new id = taskid - TASK_PROGRESS;
	if (!is_user_connected(id))
		return;
	set_pev(id, pev_deadflag, DEAD_RESPAWNABLE);
	dllfunc(DLLFunc_Spawn, id);
}

ExplodeCorpse(corpse, reviver, corpse_owner) {
	static Float:origin[3];
	pev(corpse, pev_origin, origin);

	/* Efecto y sonido */
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, origin[0]);
	engfunc(EngFunc_WriteCoord, origin[1]);
	engfunc(EngFunc_WriteCoord, origin[2]);
	write_short(engfunc(EngFunc_ModelIndex, "sprites/zerogxplode.spr"));
	write_byte(30);
	write_byte(15);
	write_byte(TE_EXPLFLAG_NONE);
	message_end();

	emit_sound(0, CHAN_AUTO, "weapons/c4_explode_01.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);

	/* Gibs en posición del cadáver (cuerpo explota) - TE_EXPLODEMODEL */
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_EXPLODEMODEL);
	engfunc(EngFunc_WriteCoord, origin[0]);
	engfunc(EngFunc_WriteCoord, origin[1]);
	engfunc(EngFunc_WriteCoord, origin[2]);
	engfunc(EngFunc_WriteCoord, 100.0);
	write_short(engfunc(EngFunc_ModelIndex, "models/hgibs.mdl"));
	write_short(8);
	write_byte(10);
	message_end();

	/* Daño en radio: reviver muere con gibs; otros cerca también */
	new Float:radius = 120.0;
	new Float:damage = 200.0;
	new i;
	for (i = 1; i <= 32; i++) {
		if (!is_user_connected(i) || !is_user_alive(i))
			continue;
		static Float:pos[3];
		pev(i, pev_origin, pos);
		new Float:dist = vector_distance(origin, pos);
		if (dist > radius)
			continue;
		new Float:take = damage * (1.0 - (dist / radius) * 0.5);
		if (take < 10.0)
			continue;
		if (i == reviver)
			take = 9999.0; /* Muerte con gibs */
		ExecuteHamB(Ham_TakeDamage, i, 0, 0, take, DMG_BLAST);
	}

	RemoveCorpse(corpse);
}

RemoveCorpse(ent) {
	if (!pev_valid(ent))
		return;
	new flags = pev(ent, pev_flags);
	set_pev(ent, pev_flags, flags | FL_KILLME);
}

ResetProgress(id) {
	g_progress[id] = 0.0;
	g_target_ent[id] = 0;
	g_was_reviving[id] = false;
	g_was_planting[id] = false;
	MsgBarTime(id, 0);
}

MsgBarTime(id, seconds) {
	if (is_user_bot(id))
		return;
	message_begin(MSG_ONE, g_msgBarTime, _, id);
	write_byte(seconds);
	write_byte(0);
	message_end();
}
