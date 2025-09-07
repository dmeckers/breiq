<?php
/**
 * Direct Database Migration Runner for Laravel
 * This script connects directly to the AWS RDS database to run migrations
 */

// Database connection details from .env.production
$host = 'breiq-production-db.ck5yc4iwcs03.us-east-1.rds.amazonaws.com';
$port = '5432';
$dbname = 'breiq_production';
$user = 'breiq_admin';
$password = 'e-nTP5H2sqAtSS*<Ptl3';

echo "🔄 Connecting to database...\n";

try {
    $dsn = "pgsql:host=$host;port=$port;dbname=$dbname";
    $pdo = new PDO($dsn, $user, $password, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 10,
    ]);
    
    echo "✅ Connected successfully to PostgreSQL\n";
    
    // Check if migrations table exists
    $stmt = $pdo->query("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'migrations');");
    $migrationsTableExists = $stmt->fetchColumn();
    
    if (!$migrationsTableExists) {
        echo "📋 Creating migrations table...\n";
        $pdo->exec("
            CREATE TABLE migrations (
                id SERIAL PRIMARY KEY,
                migration VARCHAR(255) NOT NULL,
                batch INT NOT NULL
            );
        ");
        echo "✅ Migrations table created\n";
    } else {
        echo "✅ Migrations table already exists\n";
    }
    
    // Check current migration status
    $stmt = $pdo->query("SELECT COUNT(*) FROM migrations;");
    $migrationCount = $stmt->fetchColumn();
    
    echo "📊 Current migrations applied: $migrationCount\n";
    
    if ($migrationCount == 0) {
        echo "⚠️  No migrations have been applied yet\n";
        echo "🔧 This explains why the Laravel app is getting 500 errors\n";
        echo "💡 The startup script should handle this, but containers may be failing before migrations complete\n";
    } else {
        echo "✅ Database schema exists with $migrationCount migrations applied\n";
    }
    
    // Show recent migrations
    if ($migrationCount > 0) {
        echo "\n📋 Recent migrations:\n";
        $stmt = $pdo->query("SELECT migration, batch FROM migrations ORDER BY id DESC LIMIT 5;");
        while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
            echo "  - {$row['migration']} (batch {$row['batch']})\n";
        }
    }
    
} catch (PDOException $e) {
    echo "❌ Database connection failed: " . $e->getMessage() . "\n";
    exit(1);
}

echo "\n🏁 Migration check complete\n";
?>