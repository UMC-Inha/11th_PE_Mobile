# 4주차 백엔드 핵심 키워드

## JPA / Hibernate / TypeORM

ORM은 객체와 테이블을 매핑하고 CRUD SQL 생성을 돕는다. JPA는 Java 영속성 규격이고 Hibernate는 그 구현체다. Spring Data JPA는 Repository 추상화를 더한다. TypeORM은 TypeScript/JavaScript ORM 라이브러리이며 이번 NestJS 코드에서는 `@nestjs/typeorm`으로 DataSource와 Repository를 주입한다. 기본 CRUD는 간결해지지만 관계·SQL·실행 계획을 이해해야 하고 복잡한 조회의 성능이 자동으로 해결되지는 않는다. [Hibernate 공식 가이드](https://docs.hibernate.org/orm/6.6/userguide/html_single/), [NestJS Database](https://docs.nestjs.com/techniques/database)

## Entity Lifecycle와 Persistence Context

JPA의 엔티티는 transient(새 객체), managed(영속성 컨텍스트가 관리), detached(관리에서 분리), removed(삭제 예정) 상태를 가진다. 영속성 컨텍스트는 엔티티 동일성과 변경 추적을 관리하고 SQL을 flush 시점까지 모을 수 있다. 따라서 persist 직후 항상 INSERT가 실행된다고 볼 수 없으며 ID 생성 전략 등에 따라 즉시 실행될 수도 있다.

TypeORM의 `repository.create()`는 객체 생성이며 저장하지 않는다. `await repository.save()`는 실제 저장 결과를 기다린다. 일반 객체 필드를 바꾸기만 하면 자동 반영되는 JPA식 dirty checking을 TypeORM에 그대로 가정하면 안 된다. 이번 등록은 Category 조회 → create → await save → DTO 변환 순서다. [Hibernate 영속성 컨텍스트](https://docs.hibernate.org/orm/6.6/userguide/html_single/#pc), [TypeORM Repository API](https://typeorm.io/docs/working-with-entity-manager/repository-api/)

## DTO와 API Contract

Entity는 DB 구조·관계를 표현하고 DTO는 클라이언트 요청·응답의 약속을 표현한다. Entity 전체를 반환하면 내부 컬럼, 관계 객체, 불필요한 정보와 DB 변경이 API에 노출된다. 요청 DTO는 categoryId·title·선택 description만 받고 응답 DTO는 bookId·title·description·categoryName·isAvailable만 반환한다. DB의 `book_id`와 `is_available`은 외부에 camelCase와 boolean으로 전달한다. BIGINT ID는 JavaScript 정밀도를 보존하기 위해 문자열로 명시했다.

## Validation

입력 검증은 Service에 잘못된 타입과 누락값이 도달하기 전에 수행한다. NestJS 전역 ValidationPipe의 transform은 DTO 인스턴스를 만들고 whitelist는 선언된 속성만 허용하며 forbidNonWhitelisted는 다른 속성을 오류로 거른다. 필수 제목을 trim한 뒤 비어 있지 않은 문자열·최대100자로 검증하고 categoryId는 양의 안전한 정수로 검증한다. 문자열 `"1"`을 숫자로 자동 허용하지 않는다. 카테고리가 DB에 존재하는지는 Service의 업무 검증으로 별도 확인한다. [NestJS Validation](https://docs.nestjs.com/techniques/validation), [class-validator](https://github.com/typestack/class-validator)

## N+1 Query

도서 N개를 조회한 뒤 각 도서의 카테고리를 따로 조회하면 최초 조회1번+카테고리N번이 된다. 관계를 join으로 함께 읽거나 필요한 관계를 일괄 조회해 줄일 수 있다. 이번 find 옵션의 `relations: { category: true }`는 카테고리를 함께 가져온다. 목록 크기가 커지면 실제 SQL·쿼리 수를 확인하고 페이지네이션, 인덱스, 선택 컬럼도 점검해야 한다. ORM을 사용했다고 N+1이 자동으로 없어지는 것은 아니다. [TypeORM 성능 문서](https://typeorm.io/docs/advanced-topics/performance-optimizing/)

## Migration과 synchronize

Migration은 스키마 변경을 버전이 있는 up/down 코드로 기록한다. synchronize는 엔티티에 맞춰 스키마를 자동 변경하므로 기존 데이터와 운영 스키마에 예기치 않은 영향을 줄 수 있다. 이번 기존 DB 매핑은 synchronize:false로 두고 title UNIQUE만 명시적 Migration으로 추가했다. 중복 행이 이미 있으면 실패하게 하며 임의 삭제하지 않는다. 실행한 변경을 검토·재현할 수 있다는 장점이 있지만 down 실행이 데이터 손실을 완전히 복구하는 백업은 아니다. [TypeORM Migrations](https://typeorm.io/docs/advanced-topics/migrations/)
