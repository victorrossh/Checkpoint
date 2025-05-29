#include <amxmodx>
#include <fun>
#include <cromchat2>

#define PLUGIN "Noclip - Godmode"
#define VERSION "1.0"
#define AUTHOR "ftl~"

#pragma semicolon 1

new bool:g_bNoclipGodmode[33];

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("say /noclip", "ToggleNoclipGodmode");
	register_clcmd("say /nc", "ToggleNoclipGodmode");

	// Chat prefix
	CC_SetPrefix("&x04[FWO]");
}

public client_putinserver(id) {
	g_bNoclipGodmode[id] = false;
	set_user_noclip(id, 0);
	set_user_godmode(id, 0);
}

public client_disconnected(id) {
	g_bNoclipGodmode[id] = false;
	set_user_noclip(id, 0);
	set_user_godmode(id, 0);
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