<?php
// Image upload endpoint — เก็บไฟล์ภาพไว้ที่ host นี้แทน Supabase Storage
// ใช้คู่กับ src/composables/useExternalUpload.js

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
$category = preg_replace('/[^a-z0-9_-]/i', '', $_POST['category'] ?? 'misc');
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
