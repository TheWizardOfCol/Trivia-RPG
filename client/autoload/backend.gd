extends Node

## Where the game's Elements backend lives.
##
## Switch environments WITHOUT rebuilding the game — first match wins:
##   1. Launch argument:  godot -- --backend-url=https://example.com
##   2. res://backend.txt — first non-comment, non-empty line
##   3. The production URL below (fallback)

const PRODUCTION_URL := "https://oatymilkgames.cloud.namazustudios.com"
const CONFIG_PATH := "res://backend.txt"

func base_url() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--backend-url="):
			return arg.trim_prefix("--backend-url=").strip_edges().trim_suffix("/")

	if FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			while not file.eof_reached():
				var line := file.get_line().strip_edges()
				if line != "" and not line.begins_with("#"):
					return line.trim_suffix("/")

	return PRODUCTION_URL

func vote_url() -> String:
	return base_url() + "/trivia-rpg/vote"

## Game mode for answer timers and (later) voting overlays: "solo" (local
## play, 25s answers) or "twitch" (chat answers, 35s answers). First match
## wins: launch arg --mode=twitch, then a "mode=twitch" line in backend.txt,
## then solo. Anything other than "twitch" counts as solo.
func mode() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			return arg.trim_prefix("--mode=").strip_edges().to_lower()

	if FileAccess.file_exists(CONFIG_PATH):
		var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
		if file:
			while not file.eof_reached():
				var line := file.get_line().strip_edges()
				if line.to_lower().begins_with("mode="):
					return line.substr(5).strip_edges().to_lower()

	return "solo"
