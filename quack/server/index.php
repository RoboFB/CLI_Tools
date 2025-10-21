<?php
$store = __DIR__ . '/sessions';
@mkdir($store, 0700, true);

$CLIENT_ID     = getenv('FT_CLIENT_ID');
$CLIENT_SECRET = getenv('FT_CLIENT_SECRET');
$HOST = 'https://quack.moritzdiepgen.de';
$REDIRECT_URI  = "$HOST/42/callback";

/* --- helpers --- */
function j($x, $c=200){
    http_response_code($c);
    header('Content-Type: application/json');
    echo json_encode($x);
    exit;
}

function curl_json($url, $fields){
    $c = curl_init($url);
    curl_setopt_array($c, [
        CURLOPT_RETURNTRANSFER => 1,
        CURLOPT_POST => 1,
        CURLOPT_POSTFIELDS => http_build_query($fields),
        CURLOPT_HTTPHEADER => ['Accept: application/json']
    ]);
    $r = curl_exec($c);
    curl_close($c);
    return json_decode($r, true);
}

function save_json($file, $data){
    $tmp = $file . '.tmp';
    file_put_contents($tmp, json_encode($data));
    @chmod($tmp, 0600);
    @rename($tmp, $file);
}

function cleanup_sessions($store, $days = 30){
    $cut = time() - ($days * 86400);
    foreach (glob("$store/*.json") as $f){
        if (@filemtime($f) < $cut) @unlink($f);
    }
    // also clean ephemeral redirect tokens
    foreach (glob("$store/token_*.json") as $f){
        if (@filemtime($f) < $cut) @unlink($f);
    }
}

$p = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
cleanup_sessions($store);

/* 1️⃣ create new session (CLI only) */
if ($p === '/42/newsession') {
    $sid = bin2hex(random_bytes(16)); // internal session ID
    save_json("$store/$sid.json", [
        'stage' => 'pending',
        'created_at' => time()
    ]);

    // Generate an ephemeral redirect token (valid ~5 min)
    $token = bin2hex(random_bytes(8));
    save_json("$store/token_$token.json", [
        'sid' => $sid,
        'expires' => time() + 600
    ]);

    // Send private SID in header only (CLI reads it)
    header("Session: $sid");
    // Return safe browser link with ephemeral token only
    j(['login_url' => "$HOST/42/login?token=$token"]);
}

/* 2️⃣ redirect user to 42 OAuth */
if ($p === '/42/login') {
    $headers = array_change_key_case(getallheaders(), CASE_LOWER);
    $sid = $headers['session'] ?? '';

    // Fallback: resolve via ephemeral token (browser access)
    if (!$sid && isset($_GET['token'])) {
        $tokfile = "$store/token_" . basename($_GET['token']) . ".json";
        if (file_exists($tokfile)) {
            $tok = json_decode(file_get_contents($tokfile), true);
            if ($tok && ($tok['expires'] ?? 0) > time()) {
                $sid = $tok['sid'];
            }
            @unlink($tokfile); // one-time use
        }
    }

    if (!$sid) {
        echo "❌ Missing or invalid session token.";
        exit;
    }

    $file = "$store/$sid.json";
    if (!file_exists($file)) {
        echo "❌ Unknown or expired session.";
        exit;
    }

    // Generate new one-time public state
    $rec = json_decode(file_get_contents($file), true);
    $public_state = bin2hex(random_bytes(16));
    $rec['public_state'] = $public_state;
    save_json($file, $rec);

    // Redirect user to 42 OAuth (browser side)
    $auth = "https://api.intra.42.fr/oauth/authorize?" . http_build_query([
        'client_id' => $CLIENT_ID,
        'redirect_uri' => $REDIRECT_URI,
        'response_type' => 'code',
        'scope' => 'public',
        'state' => $public_state
    ]);

    header("Location: $auth");
    exit;
}

/* 3️⃣ handle OAuth callback */
if ($p === '/42/callback') {
    $code  = $_GET['code']  ?? '';
    $state = $_GET['state'] ?? '';

    if (!$state) { echo "❌ Missing state."; exit; }

    // Find session by matching stored public_state
    $sid = null;
    foreach (glob("$store/*.json") as $f) {
        $rec = json_decode(file_get_contents($f), true);
        if (($rec['public_state'] ?? '') === $state) {
            $sid = basename($f, '.json');
            break;
        }
    }
    if (!$sid) { echo "❌ Unknown or expired state."; exit; }

    // Exchange code for tokens
    $tok = curl_json('https://api.intra.42.fr/oauth/token', [
        'grant_type' => 'authorization_code',
        'client_id' => $CLIENT_ID,
        'client_secret' => $CLIENT_SECRET,
        'code' => $code,
        'redirect_uri' => $REDIRECT_URI
    ]);
    if (empty($tok['access_token'])) { echo "❌ Token exchange failed."; exit; }

    $tok['stage'] = 'authorized';
    $tok['created_at'] = time();
    save_json("$store/$sid.json", $tok);

    echo <<<HTML
    <!DOCTYPE html>
    <meta charset="utf-8">
    <title>🦆 quack authorized</title>
    <style>
    body
    {
        display: flex;
        justify-content: center;
        align-items: center;
        font-family: sans-serif;
    }
    </style>
    <h2>✅ Authorized! You can close this window.</h2>
    <script>history.replaceState(null, '', '/42');</script>
    HTML;
    exit;
}

/* 4️⃣ status check (CLI polls) */
if ($p === '/42/status') {
    $headers = array_change_key_case(getallheaders(), CASE_LOWER);
    $sid = '';

    if (!empty($headers['authorization']) && str_starts_with($headers['authorization'], 'Session ')) {
        $sid = substr($headers['authorization'], 8);
    } elseif (!empty($headers['session'])) {
        $sid = $headers['session'];
    } else {
        $sid = $_GET['session'] ?? '';
    }

    $f = "$store/$sid.json";
    if (!file_exists($f)) j(['error' => 'unknown'], 404);
    @touch($f);

    $d = json_decode(file_get_contents($f), true);
    if (($d['stage'] ?? '') !== 'authorized') j(['status' => 'pending']);
    j(['status' => 'authorized']);
}

/* 5️⃣ proxy API through this server */
if ($p === '/42/proxy') {
    $headers = array_change_key_case(getallheaders(), CASE_LOWER);
    $sid = '';

    if (!empty($headers['authorization']) && str_starts_with($headers['authorization'], 'Session ')) {
        $sid = substr($headers['authorization'], 8);
    } elseif (!empty($headers['session'])) {
        $sid = $headers['session'];
    } else {
        $sid = $_GET['session'] ?? '';
    }

    $api_path = $_GET['path'] ?? '';
    if (($q = $_SERVER['QUERY_STRING'] ?? '') && str_contains($q, '&path=')) {
        $raw = substr($q, strpos($q, '&path=') + 6);
        $api_path = urldecode($raw);
    }
    if (!$sid || !$api_path) j(['error' => 'missing params'], 400);

    $file = "$store/$sid.json";
    if (!file_exists($file)) j(['error' => 'unknown session'], 404);
    $data = json_decode(file_get_contents($file), true);
    if (($data['stage'] ?? '') !== 'authorized') j(['error' => 'not authorized'], 403);

    // Refresh token if expired
    $expires_in = $data['expires_in'] ?? 0;
    $created_at = $data['created_at'] ?? 0;
    if ($expires_in && time() > ($created_at + $expires_in - 30)) {
        $refresh = curl_json('https://api.intra.42.fr/oauth/token', [
            'grant_type' => 'refresh_token',
            'client_id' => $CLIENT_ID,
            'client_secret' => $CLIENT_SECRET,
            'refresh_token' => $data['refresh_token'] ?? ''
        ]);
        if (!empty($refresh['access_token'])) {
            $data = array_merge($data, $refresh);
            $data['stage'] = 'authorized';
            $data['created_at'] = time();
            save_json($file, $data);
        } else {
            @unlink($file);
            j(['error' => 'session_expired'], 401);
        }
    }

    // Proxy request
    $url = 'https://api.intra.42.fr' . $api_path;
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => 1,
        CURLOPT_HTTPHEADER => [
            'Accept: application/json',
            'Authorization: Bearer ' . $data['access_token']
        ]
    ]);
    $resp = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    @touch($file);
    http_response_code($code);
    header('Content-Type: application/json');
    echo $resp;
    exit;
}

/* fallback */
j(['error' => 'not found'], 404);