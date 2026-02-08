// AMXX Heal - Item curativo por comando
// Uso: say /heal o say !heal. Cooldown configurable.
// Requiere: amxmodx, fun

#include <amxmodx>
#include <fun>

#pragma semicolon 1

#define PLUGIN "AMXX Heal"
#define VERSION "1.0"
#define AUTHOR "cs-server"

new g_cooldown_until[33];
new cvar_heal_amount;
new cvar_heal_cooldown;
new cvar_heal_max;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /heal", "cmd_heal");
	register_clcmd("say !heal", "cmd_heal");

	cvar_heal_amount  = register_cvar("amx_heal_amount", "50");
	cvar_heal_cooldown = register_cvar("amx_heal_cooldown", "30");
	cvar_heal_max     = register_cvar("amx_heal_max", "100");
}

public client_connect(id)
{
	g_cooldown_until[id] = 0;
}

public cmd_heal(id)
{
	if (!is_user_alive(id))
	{
		client_print(id, print_chat, "[Heal] Tenes que estar vivo.");
		return PLUGIN_HANDLED;
	}

	new now = get_systime();
	if (g_cooldown_until[id] > now)
	{
		client_print(id, print_chat, "[Heal] Espera %d segundos.", g_cooldown_until[id] - now);
		return PLUGIN_HANDLED;
	}

	new health = get_user_health(id);
	new max_hp = get_pcvar_num(cvar_heal_max);
	if (health >= max_hp)
	{
		client_print(id, print_chat, "[Heal] Ya tenes vida maxima.");
		return PLUGIN_HANDLED;
	}

	new add = get_pcvar_num(cvar_heal_amount);
	new new_health = health + add;
	if (new_health > max_hp)
		new_health = max_hp;

	set_user_health(id, new_health);
	g_cooldown_until[id] = now + get_pcvar_num(cvar_heal_cooldown);

	client_print(id, print_chat, "[Heal] +%d vida. Proximo en %d seg.", add, get_pcvar_num(cvar_heal_cooldown));
	return PLUGIN_HANDLED;
}
