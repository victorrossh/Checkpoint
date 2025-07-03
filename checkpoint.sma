#include <amxmodx>
#include <fun>
#include <cromchat2>
#include <engine>
#include <timer>

#define PLUGIN "Checkpoint System"
#define VERSION "1.0"
#define AUTHOR "ftl~"

#pragma semicolon 1

#define MAX_PLAYERS 32

enum _:CheckpointData {
	Float:cp_origin[3],
	Float:cp_angles[3],
	Float:cp_velocity[3]
}

new Array:g_aPlayerCheckpoints[33];
new g_CheckpointCount[33];
new g_ActiveCheckpoints[33]; // Tracks the number of checkpoints currently available for use
new g_GocheckCount[33];
new bool:g_bNoclipGodmode[33];
new g_LastCheckpointIndex[33]; // Stores the index of the last checkpoint accessed by LastCheckpoint

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /checkpointmenu", "ShowMenu");
	register_clcmd("say /cpmenu", "ShowMenu");

	register_clcmd("say /check", "Checkpoint");
	register_clcmd("say /checkpoint", "Checkpoint");
	register_clcmd("say /cp", "Checkpoint");

	register_clcmd("say /gocheck", "CheckpointTeleport");
	register_clcmd("say /gc", "CheckpointTeleport");
	register_clcmd("say /teleport", "CheckpointTeleport");
	register_clcmd("say /tp", "CheckpointTeleport");

	register_clcmd("say /stuck", "LastCheckpoint");
	register_clcmd("say /lastcheckpoint", "LastCheckpoint");
	register_clcmd("say /lastcp", "LastCheckpoint");
	register_clcmd("say /lcp", "LastCheckpoint");
	
	register_clcmd("say /noclip", "ToggleNoclipGodmode");
	register_clcmd("say /nc", "ToggleNoclipGodmode");

	// Chat prefix
	CC_SetPrefix("&x04[FWO]");
}

public client_putinserver(id) {
	g_bNoclipGodmode[id] = false;
	g_CheckpointCount[id] = 0;
	g_ActiveCheckpoints[id] = 0;
	g_GocheckCount[id] = 0;
	g_aPlayerCheckpoints[id] = ArrayCreate(CheckpointData);
	g_LastCheckpointIndex[id] = -1;
}

public ShowMenu(id) {
	g_bNoclipGodmode[id] = get_user_noclip(id) || get_user_godmode(id);
	
	new menu = menu_create("\r[FWO] \d- \wCheckpoint Menu:", "MenuHandler");
	new szItem[64];

	formatex(szItem, charsmax(szItem), "Checkpoint #%d", g_CheckpointCount[id]);
	menu_additem(menu, szItem, "1");

	formatex(szItem, charsmax(szItem), "GoCheck #%d^n", g_GocheckCount[id]);
	menu_additem(menu, szItem, "2");

	menu_additem(menu, "LastCP", "3");

	menu_additem(menu, "Reset^n", "4");

	formatex(szItem, charsmax(szItem), "Noclip %s", g_bNoclipGodmode[id] ? "\y[ON]" : "\r[OFF]");
	menu_additem(menu, szItem, "5");

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public MenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	// Resets the player's timer when using any menu item
	if (is_timer_active(id)) 
		reset_player_timer(id);

	switch(item) {
		case 0: Checkpoint(id);
		case 1: CheckpointTeleport(id);
		case 2: LastCheckpoint(id);
		case 3: ResetCheckpoint(id);
		case 4: ToggleNoclipGodmode(id);
	}

	ShowMenu(id);
	menu_destroy(menu);
	return PLUGIN_HANDLED;
} 

public Checkpoint(id) {
	if (!is_user_alive(id)) {
		CC_SendMessage(id, "You must be alive to create a checkpoint.");
		return PLUGIN_HANDLED;
	}

	if (get_user_noclip(id)) {
		CC_SendMessage(id, "Cannot create checkpoint while noclip is active.");
		return PLUGIN_HANDLED;
	}

	new data[CheckpointData];
	new Float:origin[3], Float:angles[3], Float:velocity[3];
	
	// Get player vectors into temporary arrays
	entity_get_vector(id, EV_VEC_origin, origin);
	entity_get_vector(id, EV_VEC_v_angle, angles);
	entity_get_vector(id, EV_VEC_velocity, velocity);
	
	// Copy vectors to data structure
	for (new i = 0; i < 3; i++) {
		data[cp_origin][i] = origin[i];
		data[cp_angles][i] = angles[i];
		data[cp_velocity][i] = velocity[i];
	}
	
	ArrayPushArray(g_aPlayerCheckpoints[id], data);
	g_CheckpointCount[id]++;
	g_ActiveCheckpoints[id]++;
	g_LastCheckpointIndex[id] = -1;
	CC_SendMessage(id, "Checkpoint saved.");

	return PLUGIN_HANDLED;
}

public CheckpointTeleport(id) {
	if (!is_user_alive(id)) {
		CC_SendMessage(id, "You must be alive to teleport.");
		return PLUGIN_HANDLED;
	}

	if (g_ActiveCheckpoints[id] == 0) {
		CC_SendMessage(id, "No checkpoints available.");
		return PLUGIN_HANDLED;
	}

	if (get_user_noclip(id)) {
		CC_SendMessage(id, "Cannot teleport while noclip is active.");
		return PLUGIN_HANDLED;
	}

	new data[CheckpointData];
	ArrayGetArray(g_aPlayerCheckpoints[id], g_ActiveCheckpoints[id] - 1, data);
	
	// Use temporary arrays to set vectors
	new Float:origin[3], Float:angles[3], Float:velocity[3];
	for (new i = 0; i < 3; i++) {
		origin[i] = data[cp_origin][i];
		angles[i] = data[cp_angles][i];
		velocity[i] = data[cp_velocity][i];
	}
	
	// Set player position and angles
	entity_set_vector(id, EV_VEC_origin, origin);
	SetUserAgl(id, angles);
	entity_set_vector(id, EV_VEC_velocity, velocity);

	g_GocheckCount[id]++;
	CC_SendMessage(id, "Teleported to checkpoint.");

	return PLUGIN_HANDLED;
}

public LastCheckpoint(id) {
	if (!is_user_alive(id)) {
		CC_SendMessage(id, "You must be alive to use /lastcp.");
		return PLUGIN_HANDLED;
	}

	if (g_ActiveCheckpoints[id] <= 1) { // Check if there is only one or no active checkpoints left
		CC_SendMessage(id, "No more checkpoints to delete.");
		return PLUGIN_HANDLED;
	}

	if (get_user_noclip(id)) {
		CC_SendMessage(id, "Cannot use /lastcp while noclip is active.");
		return PLUGIN_HANDLED;
	}

	// If no previous checkpoint index is set or the current index is at the latest, set to the second-to-last active checkpoint
	if (g_LastCheckpointIndex[id] == -1 || g_LastCheckpointIndex[id] >= g_ActiveCheckpoints[id] - 1) {
		g_LastCheckpointIndex[id] = g_ActiveCheckpoints[id] - 2;
	} else {
		g_LastCheckpointIndex[id]--;
	}

	if (g_LastCheckpointIndex[id] < 0) {
		g_LastCheckpointIndex[id] = -1;
		CC_SendMessage(id, "No more checkpoints to delete.");
		return PLUGIN_HANDLED;
	}

	new data[CheckpointData];
	ArrayGetArray(g_aPlayerCheckpoints[id], g_LastCheckpointIndex[id], data);
	
	new Float:origin[3], Float:angles[3], Float:velocity[3];
	for (new i = 0; i < 3; i++) {
		origin[i] = data[cp_origin][i];
		angles[i] = data[cp_angles][i];
		velocity[i] = data[cp_velocity][i];
	}
	
	ArrayDeleteItem(g_aPlayerCheckpoints[id], g_ActiveCheckpoints[id] - 1); // Delete the most recent checkpoint
	g_ActiveCheckpoints[id]--; // Decrease the count of active checkpoints

	entity_set_vector(id, EV_VEC_origin, origin);
	SetUserAgl(id, angles);
	entity_set_vector(id, EV_VEC_velocity, velocity);

	CC_SendMessage(id, "Teleported to last checkpoint.");
	return PLUGIN_HANDLED;
}

public ResetCheckpoint(id) {
	ArrayClear(g_aPlayerCheckpoints[id]);
	g_CheckpointCount[id] = 0;
	g_ActiveCheckpoints[id] = 0;
	g_GocheckCount[id] = 0;
	g_LastCheckpointIndex[id] = -1;
	CC_SendMessage(id, "All checkpoints reset.");
}

public ToggleNoclipGodmode(id) {
	if (!is_user_alive(id)) {
		return PLUGIN_HANDLED;
	}

	g_bNoclipGodmode[id] = get_user_noclip(id) || get_user_godmode(id);
	g_bNoclipGodmode[id] = !g_bNoclipGodmode[id];
	set_user_noclip(id, g_bNoclipGodmode[id]);
	set_user_godmode(id, g_bNoclipGodmode[id]);
	CC_SendMessage(id, "Noclip: %s", g_bNoclipGodmode[id] ? "&x06ON" : "&x07OFF");

	return PLUGIN_HANDLED;
}

stock SetUserAgl(id, Float:agl[3]) {
	entity_set_vector(id, EV_VEC_angles, agl);
	entity_set_int(id, EV_INT_fixangle, 1);
}