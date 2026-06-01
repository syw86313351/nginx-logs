<?php
/**
 * RackTables Auto-Initializer
 *
 * Runs at container startup (CLI mode) to:
 *   1. Write inc/secret.php with correct variable names ($pdo_dsn etc.)
 *   2. Initialize the database schema if tables don't exist yet
 *   3. Create the default admin account
 *
 * This bypasses the web-based installer so the container is ready
 * immediately after `docker compose up`.
 */

$db_host = getenv('DB_HOST') ?: 'db';
$db_port = getenv('DB_PORT') ?: '3306';
$db_name = getenv('DB_NAME') ?: 'racktables';
$db_user = getenv('DB_USER') ?: 'racktables';
$db_pass = getenv('DB_PASS') ?: 'racktables_pass';

$admin_pass = getenv('RACKTABLES_ADMIN_PASS') ?: 'admin';

// ── 1. Write secret.php ───────────────────────────────────────────────────────
$secret_path = '/var/www/html/inc/secret.php';
$secret = <<<PHP
<?php
\$pdo_dsn      = 'mysql:host={$db_host};port={$db_port};dbname={$db_name}';
\$db_username  = '{$db_user}';
\$db_password  = '{$db_pass}';
\$user_auth_src     = 'database';
\$require_valid_user = TRUE;
PHP;

file_put_contents($secret_path, $secret . "\n");
echo "[init] secret.php written to {$secret_path}\n";

// ── 2. Connect to database ────────────────────────────────────────────────────
$dsn = "mysql:host={$db_host};port={$db_port};dbname={$db_name};charset=utf8";
$retries = 10;
$pdo = null;
while ($retries-- > 0) {
    try {
        $pdo = new PDO($dsn, $db_user, $db_pass, [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        break;
    } catch (PDOException $e) {
        echo "[init] DB not ready yet ({$e->getMessage()}), retrying...\n";
        sleep(2);
    }
}
if (!$pdo) {
    echo "[init] ERROR: Could not connect to database after retries.\n";
    exit(1);
}
echo "[init] Connected to database.\n";

// ── 3. Check if already initialized ──────────────────────────────────────────
$tables = $pdo->query('SHOW TABLES')->fetchAll(PDO::FETCH_NUM);
if (count($tables) > 0) {
    echo "[init] Database already has " . count($tables) . " tables — skipping init.\n";
    exit(0);
}

echo "[init] Database is empty, initializing schema...\n";

// ── 4. Load get_pseudo_file() from install.php ───────────────────────────────
// config.php must be loaded first — it defines CODE_VERSION ('0.22.0').
// install.php uses CODE_VERSION inside get_pseudo_file('dictbase') to set
// the DB_VERSION row. Without it the constant resolves to the literal string
// "CODE_VERSION" and RackTables shows an upgrade-required error on every load.
ob_start();
chdir('/var/www/html');
require_once 'inc/config.php';   // defines CODE_VERSION
require_once 'inc/install.php';  // defines get_pseudo_file()
ob_end_clean();

// ── 5. Run structure + dictbase SQL ──────────────────────────────────────────
$pdo->exec("ALTER DATABASE CHARACTER SET utf8 COLLATE utf8_unicode_ci");
$pdo->exec("SET NAMES 'utf8'");
$pdo->exec("SET FOREIGN_KEY_CHECKS=0");

$total_errors = 0;
foreach (['structure', 'dictbase'] as $part) {
    $ok = $err = 0;
    foreach (get_pseudo_file($part) as $q) {
        $q = trim($q);
        if ($q === '') continue;
        try {
            $pdo->exec($q);
            $ok++;
        } catch (PDOException $e) {
            // Many statements are "IF NOT EXISTS"-style; treat warnings as non-fatal
            echo "[init] warn ({$part}): " . $e->getMessage() . "\n";
            $err++;
            $total_errors++;
        }
    }
    echo "[init] {$part}: {$ok} OK, {$err} errors\n";
}

$pdo->exec("SET FOREIGN_KEY_CHECKS=1");

if ($total_errors > 20) {
    echo "[init] ERROR: Too many errors during schema init ({$total_errors}). Check logs.\n";
    exit(1);
}

// ── 6. Create admin account ───────────────────────────────────────────────────
$hash = sha1($admin_pass);
$stmt = $pdo->prepare(
    "INSERT IGNORE INTO UserAccount (user_id, user_name, user_password_hash, user_realname)
     VALUES (1, 'admin', ?, 'RackTables Administrator')"
);
$stmt->execute([$hash]);
echo "[init] Admin account created (password: '{$admin_pass}').\n";

echo "[init] Initialization complete.\n";
exit(0);
