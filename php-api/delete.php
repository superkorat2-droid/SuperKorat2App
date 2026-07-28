<?php
// Delete endpoint — ลบไฟล์ที่เคยอัปโหลดผ่าน upload.php
// ใช้คู่กับ src/composables/useExternalUpload.js (deleteUploadedFile)

require __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: X-Upload-Secret, X-Upload-Ticket, Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

header('Content-Type: application/json; charset=utf-8');

function fail(string $msg, int $code = 400): void {
    http_response_code($code);
    echo json_encode(['error' => $msg], JSON_UNESCAPED_UNICODE);
    exit;
}

// ── ตรวจ "ตั๋วอัปโหลด" ที่ออกโดย Edge Function media-upload ────────────────
// ทำไมต้องมี: Cloudflare หน้าโดเมนนี้บล็อกคำขอที่มาจากศูนย์ข้อมูล (Attention Required!)
// Edge Function จึงยิงตรงมาไม่ได้ ต้องให้เบราว์เซอร์ของผู้ใช้ยิงเองแทน
// แต่จะส่ง UPLOAD_SECRET ไปให้เบราว์เซอร์ไม่ได้ (เคยรั่วมาแล้ว) จึงส่ง "ตั๋ว" ที่
// เซ็นด้วย HMAC ของ UPLOAD_SECRET หมดอายุใน ~2 นาที และผูกกับ category ที่ขอไว้
//
// รูปแบบตั๋ว: purpose.category.exp.nonce.signature
function verify_ticket(string $ticket, string $purpose): ?string {
    $parts = explode('.', $ticket);
    if (count($parts) !== 5) return null;
    [$p, $cat, $exp, $nonce, $sig] = $parts;

    if ($p !== $purpose) return null;
    if (!ctype_digit($exp) || (int)$exp < time()) return null;   // หมดอายุแล้ว
    if (!preg_match('/^[a-z0-9_-]+$/i', $cat)) return null;

    $expected = hash_hmac('sha256', "$p.$cat.$exp.$nonce", UPLOAD_SECRET);
    if (!hash_equals($expected, $sig)) return null;

    return $cat;   // คืน category ที่ถูกเซ็นไว้ — ใช้ค่านี้แทนค่าที่ผู้ใช้ส่งมา
}

$ticket = $_SERVER['HTTP_X_UPLOAD_TICKET'] ?? '';
$secret = $_SERVER['HTTP_X_UPLOAD_SECRET'] ?? '';

if ($ticket !== '') {
    if (verify_ticket($ticket, 'delete') === null) {
        fail('Invalid or expired ticket', 401);
    }
} elseif (!hash_equals(UPLOAD_SECRET, $secret)) {
    fail('Unauthorized', 401);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    fail('Method not allowed', 405);
}

$body = json_decode(file_get_contents('php://input'), true);
$url = $body['url'] ?? '';
if ($url === '') {
    fail('Missing url');
}

// ตัด BASE_URL/uploads/ ออกจาก url ที่ได้รับมา
$prefix = rtrim(BASE_URL, '/') . '/uploads/';
if (strpos($url, $prefix) !== 0) {
    fail('Invalid url');
}
$relative = substr($url, strlen($prefix));

// ต้องตรงรูปแบบที่ upload.php สร้างเท่านั้น: category/category_YmdHis_hex.ext
// (กัน path traversal และกันลบไฟล์อื่นที่ไม่ใช่ของระบบนี้)
if (!preg_match('#^([a-z0-9_-]+)/\1_[0-9]{14}_[0-9a-f]{8}\.[a-z0-9]+$#i', $relative)) {
    fail('Invalid filename');
}

$path = __DIR__ . '/uploads/' . $relative;

if (!is_file($path)) {
    // ไฟล์ไม่อยู่แล้ว ถือว่าสำเร็จ (idempotent)
    echo json_encode(['ok' => true]);
    exit;
}

if (!unlink($path)) {
    fail('Failed to delete file', 500);
}

echo json_encode(['ok' => true]);
