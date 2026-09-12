# :leaves: PE Mobile

INHA UMC 11th PE Mobile 미션, 키워드 인증 리포지토리입니다!

## 📁 디렉토리 구조

```bash
.
├── README.md
├── keyword
│   └── README.md
└── mission
    └── README.md
```

### keyword 폴더

키워드와 주차마다 선택적으로 있는 실습 내용을
정리한 파일을 올리는 폴더입니다.

### mission 폴더

미션을 진행하신 내용을 정리한 파일을 올리는
폴더입니다.

## 🌳 branch 규칙

```bash
├─main
    ├─evan/main
	...
```

1. `닉네임/main`이 자신의 기본 브랜치로, pr 보내실 때는 `main`이 아닌 `닉네임/main` 브랜치로 올립니다.
2. 매주 워크북, 실습, 그리고 미션은 각자의 `닉네임/main` 브랜치를 base로 삼아, fork한 리포지토리에서 자신의 `닉네임/main`에 pull request를 생성합니다.
3. 교육국장의 approve를 받으면, pr을 머지하고 이때, pr 제목은
   `[n주차/닉네임] 워크북 제출합니다` 형식으로 작성합니다.

## 🔖 커밋 컨벤션

예시 ) `mission: 0주차 미션 인증`
| Message | 설명 |
| :------: | :------------------------------------------------ |
| mission | 미션 수행 |
| practice | 실습 수행 |
| keyword | 키워드 정리 |
| workbook | 워크북 정리 |
| fix | 버그 수정 |
| docs | 문서 수정 |
| comment | 주석 추가 및 변경 |
| test | 테스트 코드 추가 |
| rename | 파일 혹은 폴더명 수정 |
| remove | 파일 혹은 폴더 삭제 |
| chore | 기타 변경사항 |