-- データベース初期化スクリプト

USE niigata_kaigo;

-- テーブル作成 (Entity Framework Coreのマイグレーションでも作成されますが、手動でも作成可能)

-- 事業所テーブル
CREATE TABLE IF NOT EXISTS offices (
    id INT AUTO_INCREMENT PRIMARY KEY,
    office_code VARCHAR(100) NOT NULL UNIQUE,
    office_name VARCHAR(200) NOT NULL,
    office_type VARCHAR(50),
    postal_code VARCHAR(10),
    address VARCHAR(500),
    phone VARCHAR(20),
    representative_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_office_code (office_code),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ユーザーテーブル
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    office_id INT,
    role VARCHAR(20) NOT NULL DEFAULT 'staff',
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (office_id) REFERENCES offices(id) ON DELETE SET NULL,
    INDEX idx_email (email),
    INDEX idx_office_id (office_id),
    INDEX idx_role (role),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 申請テーブル
CREATE TABLE IF NOT EXISTS applications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    application_number VARCHAR(50) NOT NULL UNIQUE,
    office_id INT NOT NULL,
    user_id INT NOT NULL,
    application_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    submitted_at DATETIME,
    reviewed_at DATETIME,
    reviewed_by INT,
    review_comment VARCHAR(500),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (office_id) REFERENCES offices(id) ON DELETE RESTRICT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (reviewed_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_application_number (application_number),
    INDEX idx_office_id (office_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status),
    INDEX idx_submitted_at (submitted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 添付ファイルテーブル
CREATE TABLE IF NOT EXISTS application_files (
    id INT AUTO_INCREMENT PRIMARY KEY,
    application_id INT NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(100),
    file_size BIGINT NOT NULL,
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
    INDEX idx_application_id (application_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- サンプルデータ挿入

-- サンプル事業所
INSERT INTO offices (office_code, office_name, office_type, postal_code, address, phone, representative_name) VALUES
('OFF001', 'サンプル訪問介護事業所', '訪問介護', '950-0000', '新潟県新潟市中央区サンプル町1-1-1', '025-123-4567', '山田太郎'),
('OFF002', 'サンプル通所介護事業所', '通所介護', '950-0001', '新潟県新潟市中央区サンプル町2-2-2', '025-123-4568', '佐藤花子'),
('OFF003', '新潟市役所福祉部', '行政', '951-8550', '新潟県新潟市中央区学校町通1番町602番地1', '025-226-1269', '鈴木一郎');

-- サンプルユーザー (パスワード: password123)
-- BCrypt ハッシュ: $2a$11$... は "password123" のハッシュ
INSERT INTO users (email, password_hash, name, office_id, role) VALUES
('staff1@example.com', '$2a$11$3Kk7lY3B5J8XJ8XJ8XJ8XOqQJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8', '事業所職員1', 1, 'staff'),
('staff2@example.com', '$2a$11$3Kk7lY3B5J8XJ8XJ8XJ8XOqQJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8', '事業所職員2', 2, 'staff'),
('admin@example.com', '$2a$11$3Kk7lY3B5J8XJ8XJ8XJ8XOqQJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8', '管理者', NULL, 'admin'),
('city@example.com', '$2a$11$3Kk7lY3B5J8XJ8XJ8XJ8XOqQJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8XJ8', '市役所職員', 3, 'city_staff');

-- サンプル申請データ
INSERT INTO applications (application_number, office_id, user_id, application_type, title, content, status) VALUES
('APP202501010001', 1, 1, '新規申請', '訪問介護サービス新規申請', '新たに訪問介護サービスの提供を開始したいため、申請いたします。', 'submitted'),
('APP202501010002', 2, 2, '変更申請', '事業所所在地変更申請', '事業所の移転に伴い、所在地の変更申請を行います。', 'draft'),
('APP202501010003', 1, 1, '新規申請', '通所介護サービス追加申請', '既存の訪問介護に加えて、通所介護サービスも提供したいため申請します。', 'approved');

-- 初期化完了メッセージ
SELECT 'Database initialization completed successfully!' AS message;
