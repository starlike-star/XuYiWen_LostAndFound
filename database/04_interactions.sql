USE lostfound;

-- Extend the existing schema for administrator authorization and reversible post deletion.
SET @add_admin_column = (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE users ADD COLUMN is_admin TINYINT(1) NOT NULL DEFAULT 0 AFTER email',
    'SELECT 1')
  FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'is_admin'
);
PREPARE add_admin_statement FROM @add_admin_column;
EXECUTE add_admin_statement;
DEALLOCATE PREPARE add_admin_statement;

ALTER TABLE posts MODIFY COLUMN status ENUM('ACTIVE','RESOLVED','CLOSED','DELETED') NOT NULL DEFAULT 'ACTIVE';

-- Development administrator. Change this password before any non-development deployment.
INSERT INTO users (id, nickname, real_name, identity_number, identity_role, department, grade, campus, phone, email, is_admin, status)
VALUES ('admin-1', 'System Admin', 'System Administrator', 'ADMIN-0001', 'STAFF', 'Administration', NULL,
  'Main Campus', '13900000000', 'admin@campus.edu.cn', 1, 'NORMAL')
ON DUPLICATE KEY UPDATE is_admin = 1, status = 'NORMAL';

INSERT INTO user_credentials (user_id, password_hash)
VALUES ('admin-1', '$2b$10$.E3Dy0o149Da.JoWz1FO/ebtIU.SkkrKLOsbyeRSUVdZtdpP.GTJe')
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);

-- Idempotent extension for persistent post likes and favorites.
CREATE TABLE IF NOT EXISTS post_likes (
  post_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id),
  CONSTRAINT fk_post_likes_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_post_likes_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX ix_post_likes_user (user_id),
  INDEX ix_post_likes_post (post_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS post_favorites (
  post_id CHAR(36) NOT NULL,
  user_id CHAR(36) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (post_id, user_id),
  CONSTRAINT fk_post_favorites_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_post_favorites_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX ix_post_favorites_user (user_id),
  INDEX ix_post_favorites_post (post_id)
) ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
