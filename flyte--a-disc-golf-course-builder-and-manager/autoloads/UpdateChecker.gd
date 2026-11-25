## Checks GitHub for a newer public release of Flyte.
## Auto-checks once per launch (Settings → Updates can turn that off) and on
## demand. It never downloads or runs anything: "Download" opens the release
## page in the browser. Only an anonymous GET to the public GitHub API is sent.
extends Node

signal status_changed(status: String)   # idle | checking | up_to_date | available | error

const RELEASES_API  := "https://api.github.com/repos/ktraab/flyte/releases/latest"
const RELEASES_PAGE := "https://github.com/ktraab/flyte/releases/latest"
const _CFG_PATH     := "user://updates.cfg"
const _TIMEOUT_S    := 10.0

var auto_check: bool = true
var status: String = "idle"
var latest_version: String = ""
var release_url: String = RELEASES_PAGE
var _http: HTTPRequest = null
var _manual: bool = false

func _ready() -> void:
	_load_settings()
	if auto_check and _auto_allowed():
		check_now.call_deferred(false)

## No automatic network calls headless (tests, CI) or from the editor.
func _auto_allowed() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("editor") \
		and not OS.get_user_data_dir().contains("flyte_test_home")

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## True when version string `a` is newer than `b` ("v1.2.0" > "1.1.9"; missing parts = 0).
static func is_newer(a: String, b: String) -> bool:
	var pa := _parts(a)
	var pb := _parts(b)
	for i in maxi(pa.size(), pb.size()):
		var x: int = pa[i] if i < pa.size() else 0
		var y: int = pb[i] if i < pb.size() else 0
		if x != y:
			return x > y
	return false

static func _parts(v: String) -> Array:
	var s := v.strip_edges().trim_prefix("v").trim_prefix("V")
	s = s.split("-")[0]   # ignore "-beta" style suffixes
	var out: Array = []
	for p in s.split("."):
		out.append(int(p) if p.is_valid_int() else 0)
	return out

func check_now(manual: bool = true) -> void:
	if status == "checking":
		return
	_manual = manual
	if _http == null:
		_http = HTTPRequest.new()
		_http.timeout = _TIMEOUT_S
		_http.request_completed.connect(_on_request_completed)
		add_child(_http)
	var err := _http.request(RELEASES_API, PackedStringArray([
		"User-Agent: Flyte-Update-Check", "Accept: application/vnd.github+json"]))
	if err != OK:
		_set_status("error")
		return
	_set_status("checking")

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_set_status("error")
		if _manual:
			EventBus.notification_requested.emit("Couldn't check for updates (offline?).", "warning")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not (data as Dictionary).has("tag_name"):
		_set_status("error")
		return
	apply_release(str(data["tag_name"]), str((data as Dictionary).get("html_url", "")))

## Record the latest release and notify. Split out so tests can feed a release.
func apply_release(tag: String, url: String) -> void:
	latest_version = tag.trim_prefix("v")
	# Only ever open the project's own release pages.
	release_url = url if url.begins_with("https://github.com/ktraab/flyte/releases/") else RELEASES_PAGE
	if is_newer(tag, current_version()):
		_set_status("available")
		EventBus.notification_requested.emit(
			"Flyte v%s is out — Settings → Updates to download." % latest_version, "info")
	else:
		_set_status("up_to_date")
		if _manual:
			EventBus.notification_requested.emit("You're on the latest version (v%s)." % current_version(), "info")

func open_download() -> void:
	OS.shell_open(release_url)

func set_auto_check(on: bool) -> void:
	auto_check = on
	var cfg := ConfigFile.new()
	cfg.load(_CFG_PATH)
	cfg.set_value("updates", "auto", on)
	cfg.save(_CFG_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_CFG_PATH) == OK:
		auto_check = bool(cfg.get_value("updates", "auto", true))

func _set_status(s: String) -> void:
	status = s
	status_changed.emit(s)

## One line for the Settings tab / menu banner.
func status_text() -> String:
	match status:
		"checking":   return "Checking…"
		"up_to_date": return "Up to date (v%s)." % current_version()
		"available":  return "Version %s is available." % latest_version
		"error":      return "Couldn't reach GitHub — try again later."
	return "Not checked yet."
