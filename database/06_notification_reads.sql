USE lostfound;

-- Persist per-user read state for generated notification cards.
CREATE TABLE IF NOT EXISTS notification_reads (
  user_id CHAR(36) NOT NULL,
  notification_id VARCHAR(160) NOT NULL,
  read_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, notification_id),
  CONSTRAINT fk_notification_reads_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX ix_notification_reads_user_read (user_id, read_at)
) ENGINE=InnoDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
