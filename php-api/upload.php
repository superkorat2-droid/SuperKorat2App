<?php
// Image upload endpoint — เก็บไฟล์ภาพไว้ที่ host นี้แทน Supabase Storage
// ใช้คู่กับ src/composables/useExternalUpload.js

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

// รับได้ 2 แบบ: ตั๋วจากเบราว์เซอร์ (ปกติ) หรือความลับตรง ๆ (server-to-server)
$ticket_category = null;
$ticket = $_SERVER['HTTP_X_UPLOAD_TICKET'] ?? '';
$secret = $_SERVER['HTTP_X_UPLOAD_SECRET'] ?? '';

if ($ticket !== '') {
    $ticket_category = verify_ticket($ticket, 'upload');
    if ($ticket_category === null) {
        fail('Invalid or expired ticket', 401);
    }
} elseif (!hash_equals(UPLOAD_SECRET, $secret)) {
    fail('Unauthorized', 401);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    fail('Method not allowed', 405);
}

if (empty($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
    fail('No file uploaded');
}

$file = $_FILES['file'];

// ตรวจชนิดไฟล์จริงจากเนื้อไฟล์ (กัน spoof ผ่านชื่อไฟล์/Content-Type ที่ผู้ใช้ส่งมา)
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mime  = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

$imageMimeToExt = [
    'image/jpeg' => 'jpg',
    'image/png'  => 'png',
    'image/webp' => 'webp',
    'image/gif'  => 'gif',
];
$videoMimeToExt = [
    'video/mp4'       => 'mp4',
    'video/webm'      => 'webm',
    'video/quicktime' => 'mov',
];

if (isset($imageMimeToExt[$mime])) {
    $maxSize = 5 * 1024 * 1024; // 5MB
    if ($file['size'] > $maxSize) {
        fail('File too large (max 5MB for images)');
    }
    // ตรวจซ้ำว่าเป็นภาพจริง (กันอัปโหลดสคริปต์แอบมาเป็น .jpg)
    if (getimagesize($file['tmp_name']) === false) {
        fail('Invalid image file');
    }
    $ext = $imageMimeToExt[$mime];
} elseif (isset($videoMimeToExt[$mime])) {
    $maxSize = 50 * 1024 * 1024; // 50MB
    if ($file['size'] > $maxSize) {
        fail('File too large (max 50MB for videos)');
    }
    $ext = $videoMimeToExt[$mime];
} else {
    fail('Unsupported file type: ' . $mime);
}

// category = โฟลเดอร์ย่อยใต้ uploads/ (whitelist a-z 0-9 _ - เท่านั้น)
// ถ้ามาด้วยตั๋ว ให้ยึด category ที่ถูกเซ็นไว้ ไม่ใช่ค่าที่ส่งมากับ form
$category = $ticket_category !== null
    ? $ticket_category
    : preg_replace('/[^a-z0-9_-]/i', '', $_POST['category'] ?? 'misc');
if ($category === '') {
    $category = 'misc';
}

$dir = __DIR__ . '/uploads/' . $category;
if (!is_dir($dir) && !mkdir($dir, 0755, true)) {
    fail('Cannot create directory', 500);
}

$filename = $category . '_' . date('YmdHis') . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
$dest = $dir . '/' . $filename;

if (!move_uploaded_file($file['tmp_name'], $dest)) {
    fail('Failed to save file', 500);
}

echo json_encode([
    'url' => rtrim(BASE_URL, '/') . '/uploads/' . $category . '/' . $filename,
], JSON_UNESCAPED_UNICODE);
