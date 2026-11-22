## Supabase REST backend for mobile cloud sync.
## Configure SUPABASE_URL and SUPABASE_ANON_KEY from your project dashboard.
## Auth: call set_user_id() after Supabase login so saves are tied to a user.
##
## Supabase table schema (run once in SQL editor):
##   create table if not exists saves (
##     user_id  text primary key,
##     data     jsonb not null,
##     updated_at timestamptz default now()
##   );
##   alter table saves enable row level security;
##   create policy "Users own their saves" on saves
##     using (auth.uid()::text = user_id);
class_name SupabaseBackend
extends SaveBackend

# ── Config ───────────────────────────────────────────────────────────────────
## Fill these in from your Supabase project → Settings → API
const SUPABASE_URL      := ""   # e.g. "https://abcdefgh.supabase.co"
const SUPABASE_ANON_KEY := ""   # public anon key — safe to ship in client

const TABLE := "saves"

# ── Internal ─────────────────────────────────────────────────────────────────
var _http: HTTPRequest
var _user_id: String = ""
var _pending: String = ""   # "save" | "load" | ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

# ── Public ───────────────────────────────────────────────────────────────────

func set_user_id(id: String) -> void:
	_user_id = id

func save(data: Dictionary) -> void:
	if not is_available():
		save_completed.emit(false)
		return

	_pending = "save"
	var payload := JSON.stringify({
		"user_id": _user_id,
		"data": data,
		"updated_at": Time.get_datetime_string_from_system(true),
	})

	_http.request(
		"%s/rest/v1/%s" % [SUPABASE_URL, TABLE],
		_headers(),
		HTTPClient.METHOD_POST,
		payload
	)

func load_data() -> void:
	if not is_available():
		load_completed.emit(false, {})
		return

	_pending = "load"
	var url := "%s/rest/v1/%s?user_id=eq.%s&select=data&order=updated_at.desc&limit=1" % [
		SUPABASE_URL, TABLE, _user_id
	]
	_http.request(url, _headers(), HTTPClient.METHOD_GET)

func is_available() -> bool:
	return (
		not SUPABASE_URL.is_empty()
		and not SUPABASE_ANON_KEY.is_empty()
		and not _user_id.is_empty()
	)

# ── Internals ─────────────────────────────────────────────────────────────────

func _headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + SUPABASE_ANON_KEY,
		"Authorization: Bearer " + SUPABASE_ANON_KEY,
		"Prefer: resolution=merge-duplicates",  # upsert on conflict
	])

func _on_request_completed(
	result: int,
	response_code: int,
	_headers_out: PackedStringArray,
	body: PackedByteArray
) -> void:
	var op := _pending
	_pending = ""

	if result != HTTPRequest.RESULT_SUCCESS or response_code >= 400:
		push_error("SupabaseBackend: HTTP error result=%d code=%d" % [result, response_code])
		if op == "save":
			save_completed.emit(false)
		else:
			load_completed.emit(false, {})
		return

	if op == "save":
		save_completed.emit(true)
		return

	# op == "load"
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		load_completed.emit(false, {})
		return

	var rows = json.get_data()
	if rows is Array and not rows.is_empty():
		load_completed.emit(true, rows[0].get("data", {}))
	else:
		# No cloud save yet — not an error, just no data
		load_completed.emit(false, {})
