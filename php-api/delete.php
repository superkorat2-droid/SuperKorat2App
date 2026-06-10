<?php
// Delete endpoint — ลบไฟล์ที่เคยอัปโหลดผ่าน upload.php
// ใช้คู่กับ src/composables/useExternalUpload.js (deleteUploadedFile)

require __DIR__ . '/config.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: X-Upload-Secret, Content-Type');

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

$secret = $_SERVER['HTTP_X_UPLOAD_SECRET'] ?? '';
if (!hash_equals(UPLOAD_SECRET, $secret)) {
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
