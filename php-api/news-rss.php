<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Content-Type: application/rss+xml; charset=utf-8');
header('Cache-Control: public, max-age=900');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$url = 'https://news.google.com/rss/search?q=%E0%B8%82%E0%B9%88%E0%B8%B2%E0%B8%A7%E0%B8%81%E0%B8%B2%E0%B8%A3%E0%B8%A8%E0%B8%B6%E0%B8%81%E0%B8%A9%E0%B8%B2&hl=th&gl=TH&ceid=TH:th';

$context = stream_context_create([
    'http' => [
        'method'  => 'GET',
        'header'  => implode("\r\n", [
            'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
            'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language: th-TH,th;q=0.9,en;q=0.8',
        ]),
        'timeout' => 10,
    ],
]);

$content = @file_get_contents($url, false, $context);

if ($content === false) {
    http_response_code(502);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Failed to fetch RSS feed']);
    exit;
}

echo $content;
