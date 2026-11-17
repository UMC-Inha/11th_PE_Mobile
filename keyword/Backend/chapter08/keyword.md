# Chapter 08 키워드 정리

## 1. 트랜잭션(Transaction)

DB에서 하나의 논리적 작업 단위로 묶인 연산들의 집합으로, 묶인 연산은 모두 성공하거나 모두 실패해야 함. Spring에서는 `@Transactional`을 붙이면 메서드 시작 시 트랜잭션이 열림. 메서드가 정상 종료되면 commit, 예외가 발생하면 rollback됨.

---

## 2. commit / rollback

commit은 트랜잭션 안에서 일어난 변경을 DB에 확정해 영구 반영하는 것이고, rollback은 변경을 모두 취소해 트랜잭션 시작 전 상태로 되돌리는 것임. Spring은 기본적으로 `RuntimeException`이 발생하면 rollback하고 checked 예외는 commit함. 이 동작은 `rollbackFor` 옵션으로 변경할 수 있음.

---

## 3. 원자성(Atomicity)

트랜잭션 안의 연산들을 더 이상 쪼갤 수 없는 하나로 취급하는 성질로, 흔히 “**All or Nothing**”이라고 표현함. 중간에 하나라도 실패하면 이미 실행된 연산까지 모두 취소됨. DB는 undo 로그에 이전 상태를 기록해 두는 방식으로 이를 보장함.

---

## 4. ACID

트랜잭션이 안전하게 수행되기 위한 네 가지 성질의 약자임.

- **원자성(Atomicity)**: 전부 반영되거나 전혀 반영되지 않는 것
- **일관성(Consistency)**: 트랜잭션 전후로 DB 규칙과 제약이 지켜지는 것
- **격리성(Isolation)**: 동시에 실행되는 트랜잭션끼리 서로 간섭하지 않는 것
- **지속성(Durability)**: commit된 결과가 장애가 나도 유지되는 것

---

## 5. UNIQUE 제약 조건

특정 컬럼이나 컬럼 조합에 중복 값이 들어가지 못하도록 DB가 강제하는 규칙으로, 위반하면 INSERT나 UPDATE가 실패함. JPA에서는 `@Column(unique = true)`나 `@Table(uniqueConstraints = ...)`로 선언함. 예를 들어 `(member_id, movie_id)` 조합에 걸면 같은 회원이 같은 영화를 두 번 즐겨찾기하는 것을 막을 수 있음.

---

## 6. 낙관적 잠금(Optimistic Locking)

충돌이 드물다고 가정하고, 락을 걸지 않은 채 데이터를 읽은 뒤 수정 시점에 버전을 비교해 충돌을 감지하는 방식임. JPA에서는 `@Version` 필드를 두면 수정할 때 버전을 함께 비교하고, 그 사이 다른 트랜잭션이 먼저 수정했다면 `OptimisticLockException`이 발생함. 이 예외를 잡아 재시도하거나 사용자에게 알리는 방식으로 처리함.
