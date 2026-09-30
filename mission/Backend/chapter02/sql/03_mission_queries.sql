-- 공통 실습 미션 1~3

USE umc_week02_library;

-- 미션 1. 문학 카테고리에서 대여 가능한 도서를 최신순으로 최대 10개 조회한다.
SELECT
  b.title,
  b.description,
  c.name AS category_name
FROM book AS b
JOIN category AS c
  ON b.category_id = c.category_id
WHERE c.name = '문학'
  AND b.is_available = TRUE
ORDER BY b.book_id DESC
LIMIT 10;

-- 미션 2. 사용자 1(민서)이 아직 반납하지 않은 책을 반납 예정일 순으로 조회한다.
SET @target_user_id = 1;

SELECT
  b.title,
  r.rented_at,
  r.due_at
FROM rental AS r
JOIN book AS b
  ON r.book_id = b.book_id
WHERE r.user_id = @target_user_id
  AND r.returned_at IS NULL
ORDER BY r.due_at ASC;

-- 미션 3. 책 1의 태그 목록과 사용자 1의 좋아요 여부를 조회한다.
SET @target_book_id = 1;

SELECT
  b.title,
  t.name AS tag_name,
  EXISTS (
    SELECT 1
    FROM book_like AS bl
    WHERE bl.book_id = b.book_id
      AND bl.user_id = @target_user_id
  ) AS is_liked
FROM book AS b
LEFT JOIN book_tag AS bt
  ON b.book_id = bt.book_id
LEFT JOIN tag AS t
  ON bt.tag_id = t.tag_id
WHERE b.book_id = @target_book_id
ORDER BY t.tag_id ASC;
