-- Development-only seed. Do not import into production.
USE lostfound;

INSERT INTO users (id, nickname, real_name, identity_number, identity_role, department, grade, campus, phone, email, status)
VALUES
  ('student-1', 'Student One', 'Lin Xiao', '20240001', 'STUDENT', 'Computer Science', '2024', 'Main Campus', '13800000001', 'lin@campus.edu.cn', 'NORMAL'),
  ('teacher-1', 'Teacher Wang', 'Wang Min', 'T202001', 'TEACHER', 'Computer Science', NULL, 'Main Campus', '13800000002', 'wang@campus.edu.cn', 'NORMAL')
ON DUPLICATE KEY UPDATE nickname = VALUES(nickname), status = VALUES(status);

/* The legacy localized seed below is retained for history but not executed. */
/*
INSERT INTO users (id, nickname, real_name, identity_number, identity_role, department, grade, campus, phone, email, status)
VALUES
  ('student-1', '小林同学', '林晓', '20240001', 'STUDENT', '计算机学院', '2024级', '主校区', '13800000001', 'lin@campus.edu.cn', 'NORMAL'),
  ('teacher-1', '王老师', '王敏', 'T202001', 'TEACHER', '计算机学院', NULL, '主校区', '13800000002', 'wang@campus.edu.cn', 'NORMAL')
ON DUPLICATE KEY UPDATE nickname = VALUES(nickname), status = VALUES(status);

-- Both development accounts use Campus123. Change or remove them before any non-development deployment.
*/
INSERT INTO user_credentials (user_id, password_hash)
VALUES
  ('student-1', '$2b$10$KMcYISZMv3H6LoZ0fhk8QuqYM74FGpU50W/YEHAc3Ccu/rpOCTQhO'),
  ('teacher-1', '$2b$10$KMcYISZMv3H6LoZ0fhk8QuqYM74FGpU50W/YEHAc3Ccu/rpOCTQhO')
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash);
