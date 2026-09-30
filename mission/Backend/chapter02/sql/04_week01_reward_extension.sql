-- 1주차에 설계한 지역별 가게 방문 리워드 서비스 ERD 확장 실습
-- 독립 실행이 가능하도록 최소 스키마와 더미 데이터를 함께 둔다.

CREATE DATABASE IF NOT EXISTS umc_week02_reward
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE umc_week02_reward;

CREATE TABLE member (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  nickname VARCHAR(30) NOT NULL
);

CREATE TABLE region (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL
);

CREATE TABLE food_category (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL
);

CREATE TABLE store (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  region_id BIGINT NOT NULL,
  food_category_id BIGINT NOT NULL,
  name VARCHAR(100) NOT NULL,
  CONSTRAINT fk_store_region
    FOREIGN KEY (region_id) REFERENCES region(id),
  CONSTRAINT fk_store_food_category
    FOREIGN KEY (food_category_id) REFERENCES food_category(id)
);

CREATE TABLE mission (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  store_id BIGINT NOT NULL,
  content VARCHAR(255) NOT NULL,
  reward_point INT NOT NULL,
  CONSTRAINT fk_mission_store
    FOREIGN KEY (store_id) REFERENCES store(id)
);

CREATE TABLE member_mission (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  member_id BIGINT NOT NULL,
  mission_id BIGINT NOT NULL,
  status ENUM('IN_PROGRESS', 'COMPLETED') NOT NULL,
  started_at DATETIME NOT NULL,
  completed_at DATETIME NULL,
  CONSTRAINT uq_member_mission UNIQUE (member_id, mission_id),
  CONSTRAINT fk_member_mission_member
    FOREIGN KEY (member_id) REFERENCES member(id),
  CONSTRAINT fk_member_mission_mission
    FOREIGN KEY (mission_id) REFERENCES mission(id)
);

INSERT INTO member (nickname) VALUES ('혁진');
INSERT INTO region (name) VALUES ('인하대 후문'), ('송도');
INSERT INTO food_category (name) VALUES ('카페'), ('한식');
INSERT INTO store (region_id, food_category_id, name) VALUES
  (1, 1, '캠퍼스 커피'),
  (1, 2, '든든한 식당'),
  (2, 1, '송도 로스터리');
INSERT INTO mission (store_id, content, reward_point) VALUES
  (1, '아메리카노를 주문하고 사진 인증하기', 100),
  (2, '점심 메뉴를 주문하고 영수증 인증하기', 150),
  (3, '신메뉴를 주문하고 후기 남기기', 200);
INSERT INTO member_mission (member_id, mission_id, status, started_at, completed_at) VALUES
  (1, 1, 'IN_PROGRESS', '2026-09-22 10:00:00', NULL),
  (1, 2, 'COMPLETED', '2026-09-21 12:00:00', '2026-09-21 13:00:00');

-- 확장 요구사항: 인하대 후문 지역에서 로그인 회원이 진행 중인 미션을 보여 준다.
SET @target_member_id = 1;
SET @target_region_id = 1;

SELECT
  s.name AS store_name,
  m.content AS mission_content,
  m.reward_point,
  mm.status,
  mm.started_at
FROM member_mission AS mm
JOIN mission AS m
  ON mm.mission_id = m.id
JOIN store AS s
  ON m.store_id = s.id
JOIN region AS r
  ON s.region_id = r.id
WHERE mm.member_id = @target_member_id
  AND r.id = @target_region_id
  AND mm.status = 'IN_PROGRESS'
ORDER BY mm.started_at DESC
LIMIT 10;
