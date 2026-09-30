-- UMC 11th PE Backend · Chapter 02
-- 제공된 온라인 도서 대여 기준 ERD를 MySQL DDL로 옮긴 파일

CREATE DATABASE IF NOT EXISTS umc_week02_library
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE umc_week02_library;

CREATE TABLE users (
  user_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  nickname VARCHAR(30) NOT NULL
);

CREATE TABLE category (
  category_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(50) NOT NULL
);

CREATE TABLE book (
  book_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id BIGINT NOT NULL,
  title VARCHAR(100) NOT NULL,
  description TEXT,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT fk_book_category
    FOREIGN KEY (category_id) REFERENCES category(category_id)
);

CREATE TABLE rental (
  rental_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  book_id BIGINT NOT NULL,
  rented_at DATETIME NOT NULL,
  due_at DATETIME NOT NULL,
  returned_at DATETIME NULL,
  CONSTRAINT fk_rental_user
    FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_rental_book
    FOREIGN KEY (book_id) REFERENCES book(book_id)
);

CREATE TABLE tag (
  tag_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(30) NOT NULL
);

CREATE TABLE book_tag (
  book_id BIGINT NOT NULL,
  tag_id BIGINT NOT NULL,
  PRIMARY KEY (book_id, tag_id),
  CONSTRAINT fk_book_tag_book
    FOREIGN KEY (book_id) REFERENCES book(book_id),
  CONSTRAINT fk_book_tag_tag
    FOREIGN KEY (tag_id) REFERENCES tag(tag_id)
);

CREATE TABLE book_like (
  user_id BIGINT NOT NULL,
  book_id BIGINT NOT NULL,
  PRIMARY KEY (user_id, book_id),
  CONSTRAINT fk_book_like_user
    FOREIGN KEY (user_id) REFERENCES users(user_id),
  CONSTRAINT fk_book_like_book
    FOREIGN KEY (book_id) REFERENCES book(book_id)
);

CREATE TABLE notification (
  notification_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT NOT NULL,
  type VARCHAR(30) NOT NULL,
  CONSTRAINT fk_notification_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);
