/**
 * Paracaídas: en el aire, mantén E (use) para abrirlo y bajar lento.
 * Sin comprar, disponible para todos.
 */
#include <amxmodx>
#include <fakemeta>
#include <engine>

#pragma semicolon 1

#define PLUGIN  "Parachute"
#define VERSION "1.0"
#define AUTHOR  "ReCS"

/* Velocidad de descenso con paracaídas abierto (negativo = hacia abajo) */
#define PARACHUTE_SPEED  -100.0

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	register_forward(FM_PlayerPreThink, "OnPreThink");
}

public OnPreThink(id) {
	if (!is_user_connected(id) || !is_user_alive(id))
		return FMRES_IGNORED;

	/* Solo en el aire */
	if (pev(id, pev_flags) & FL_ONGROUND)
		return FMRES_IGNORED;

	/* Abrir paracaídas con E */
	if (!(pev(id, pev_button) & IN_USE))
		return FMRES_IGNORED;

	static Float:vel[3];
	pev(id, pev_velocity, vel);
	if (vel[2] >= 0.0)
		return FMRES_IGNORED;

	vel[2] = PARACHUTE_SPEED;
	set_pev(id, pev_velocity, vel);
	return FMRES_IGNORED;
}
