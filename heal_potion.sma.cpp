#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <fun>
#include <cstrike>

#define PLUGIN  "Heal Potion (Blue)"
#define VERSION "1.0"
#define AUTHOR  "Gandármara"

#define POTION_FLAG 1337

// Models (placeholders). If you don’t add custom models, it will still work with default grenade models.
new const V_MODEL[] = "models/heal_potion/v_heal_potion.mdl";
new const P_MODEL[] = "models/heal_potion/p_heal_potion.mdl";
new const W_MODEL[] = "models/heal_potion/w_heal_potion.mdl";

new const DEFAULT_W_HE[] = "models/w_hegrenade.mdl";

// CVARs
new gCvarDrinkHeal;
new gCvarAoEHeal;
new gCvarRadius;
new gCvarMaxHP;

// Per-player: do they currently have “potion mode” HE grenades?
new bool:gHasPotion[33];

public plugin_init()
{
  register_plugin(PLUGIN, VERSION, AUTHOR);

  // Give command (for testing)
  register_clcmd("say /potion", "CmdGivePotion");
  register_clcmd("say_team /potion", "CmdGivePotion");

  // When player switches weapons, apply v/p models if holding potion
  register_event("CurWeapon", "EvCurWeapon", "be", "1=1");

  // Detect grenade entity being created & set model -> mark as potion
  register_forward(FM_SetModel, "FwSetModel");

  // Intercept grenade think (detonation time)
  RegisterHam(Ham_Think, "grenade", "HamGrenadeThink");

  // Right click drink: weapon_hegrenade SecondaryAttack
  RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_hegrenade", "HamHeSecondary", false);

  // Reset on spawn/death connect
  register_event("DeathMsg", "EvDeath", "a");
  RegisterHam(Ham_Spawn, "player", "HamPlayerSpawn", true);

  gCvarDrinkHeal = register_cvar("potion_drink_heal", "60");
  gCvarAoEHeal   = register_cvar("potion_aoe_heal", "40");
  gCvarRadius    = register_cvar("potion_radius", "220.0");
  gCvarMaxHP     = register_cvar("potion_max_hp", "100");
}

public plugin_precache()
{
  // If you don't have custom models, comment these 3 lines out
  precache_model(V_MODEL);
  precache_model(P_MODEL);
  precache_model(W_MODEL);

  // Optional: sound feedback
  precache_sound("items/smallmedkit1.wav");
}

public client_connect(id) { gHasPotion[id] = false; }
public client_disconnected(id) { gHasPotion[id] = false; }

public HamPlayerSpawn(id)
{
  if (!is_user_alive(id)) return HAM_IGNORED;
  // Optional: you can auto-give a potion each spawn by uncommenting:
  // GivePotion(id);
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
  client_print(id, print_chat, "[Potion] Te di una pocion azul (HE). LClick=tira (cura en area), RClick=bebe (cura solo).");
  return PLUGIN_HANDLED;
}

stock GivePotion(id)
{
  // Give one HE grenade and mark it as potion
  // If already has HE, we just add +1
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

  // Must be holding HE grenade
  new weapon = get_user_weapon(id);
  if (weapon != CSW_HEGRENADE) return;

  // Apply custom v/p models (if you don’t have them, comment these 2 lines)
  set_pev(id, pev_viewmodel2, V_MODEL);
  set_pev(id, pev_weaponmodel2, P_MODEL);
}

// When server sets entity model, we detect thrown HE grenade world model
public FwSetModel(ent, const model[])
{
  if (!pev_valid(ent)) return FMRES_IGNORED;

  // Only when a grenade entity gets the default HE world model
  if (!equal(model, DEFAULT_W_HE)) return FMRES_IGNORED;

  // Check entity classname
  static classname[16];
  pev(ent, pev_classname, classname, charsmax(classname));
  if (!equal(classname, "grenade")) return FMRES_IGNORED;

  // Owner
  new owner = pev(ent, pev_owner);
  if (!(1 <= owner <= 32)) return FMRES_IGNORED;

  // Only mark as potion if owner has potion flag and is on same weapon
  if (!gHasPotion[owner]) return FMRES_IGNORED;

  // Mark grenade as potion
  set_pev(ent, pev_iuser4, POTION_FLAG);

  // Save team at throw time (so it heals teammates correctly)
  set_pev(ent, pev_iuser3, _:cs_get_user_team(owner));

  // Set custom world model (optional; if you don’t have it, comment this line)
  engfunc(EngFunc_SetModel, ent, W_MODEL);

  // After throw, update owner potion status if they ran out
  new left = cs_get_user_bpammo(owner, CSW_HEGRENADE);
  if (left <= 0) gHasPotion[owner] = false;

  return FMRES_SUPERCEDE;
}

// Right click drink
public HamHeSecondary(weaponEnt)
{
  new id = get_pdata_cbase(weaponEnt, 41, 4); // m_pPlayer (offset for CS 1.6; common in AMXX examples)

  if (!(1 <= id <= 32)) return HAM_IGNORED;
  if (!is_user_alive(id)) return HAM_IGNORED;
  if (!gHasPotion[id]) return HAM_IGNORED;
  if (get_user_weapon(id) != CSW_HEGRENADE) return HAM_IGNORED;

  new ammo = cs_get_user_bpammo(id, CSW_HEGRENADE);
  if (ammo <= 0) { gHasPotion[id] = false; return HAM_SUPERCEDE; }

  // Consume 1 potion
  cs_set_user_bpammo(id, CSW_HEGRENADE, ammo - 1);
  if (ammo - 1 <= 0) gHasPotion[id] = false;

  // Heal self +60 (capped)
  HealPlayer(id, get_pcvar_num(gCvarDrinkHeal));

  // Feedback
  emit_sound(id, CHAN_ITEM, "items/smallmedkit1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);

  return HAM_SUPERCEDE; // prevent normal secondary behavior
}

// AoE heal on detonation
public HamGrenadeThink(ent)
{
  if (!pev_valid(ent)) return HAM_IGNORED;

  if (pev(ent, pev_iuser4) != POTION_FLAG) return HAM_IGNORED;

  // Check if it's time to “explode”
  new Float:dmgtime;
  pev(ent, pev_dmgtime, dmgtime);

  new Float:now = get_gametime();
  if (dmgtime > now) return HAM_IGNORED;

  new Float:origin[3];
  pev(ent, pev_origin, origin);

  new throwerTeam = pev(ent, pev_iuser3); // CsTeams enum int

  new heal = get_pcvar_num(gCvarAoEHeal);
  new Float:radius = get_pcvar_float(gCvarRadius);

  // Heal teammates in radius
  new victim = -1;
  while ((victim = engfunc(EngFunc_FindEntityInSphere, victim, origin, radius)) != 0)
  {
    if (victim < 1 || victim > 32) continue;
    if (!is_user_alive(victim)) continue;

    if (_:cs_get_user_team(victim) != throwerTeam) continue;

    HealPlayer(victim, heal);
    emit_sound(victim, CHAN_ITEM, "items/smallmedkit1.wav", 0.6, ATTN_NORM, 0, PITCH_NORM);
  }

  // Remove entity so no damage/explosion happens
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