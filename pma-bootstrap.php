<?php
/**
 * Creates the phpMyAdmin configuration storage database, loads its schema and
 * grants a dedicated control user. Idempotent: safe to run on every boot.
 */
$host = getenv('PMA_HOST') ?: 'mysql';
$port = (int) (getenv('PMA_PORT') ?: 3306);
$root = getenv('MYSQL_ROOT_USER') ?: 'root';
$pass = getenv('MYSQL_ROOT_PASSWORD');
$db   = getenv('PMA_PMADB') ?: 'phpmyadmin';
$cuser = getenv('PMA_CONTROLUSER') ?: 'pma';
$cpass = getenv('PMA_CONTROLPASS');

mysqli_report(MYSQLI_REPORT_OFF);

$conn = null;
for ($i = 0; $i < 60; $i++) {
    $conn = @new mysqli($host, $root, $pass, '', $port);
    if (!$conn->connect_error) {
        break;
    }
    $conn = null;
    sleep(2);
}
if ($conn === null) {
    fwrite(STDERR, "[bootstrap] could not reach MySQL at {$host}:{$port}\n");
    exit(1);
}

$sql = file_get_contents('/var/www/html/sql/create_tables.sql');
$sql = str_replace('`phpmyadmin`', '`' . $conn->real_escape_string($db) . '`', $sql);

if (!$conn->multi_query($sql)) {
    fwrite(STDERR, '[bootstrap] schema load failed: ' . $conn->error . "\n");
    exit(1);
}
while ($conn->more_results() && $conn->next_result()) {
    // drain
}
if ($conn->errno) {
    fwrite(STDERR, '[bootstrap] schema load failed: ' . $conn->error . "\n");
    exit(1);
}

$quoted = "'" . $conn->real_escape_string($cuser) . "'@'%'";
$stmts = [
    "CREATE USER IF NOT EXISTS {$quoted} IDENTIFIED BY '" . $conn->real_escape_string($cpass) . "'",
    "ALTER USER {$quoted} IDENTIFIED BY '" . $conn->real_escape_string($cpass) . "'",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON `" . $conn->real_escape_string($db) . "`.* TO {$quoted}",
    'FLUSH PRIVILEGES',
];
foreach ($stmts as $stmt) {
    if (!$conn->query($stmt)) {
        fwrite(STDERR, '[bootstrap] ' . $conn->error . "\n");
        exit(1);
    }
}
exit(0);
