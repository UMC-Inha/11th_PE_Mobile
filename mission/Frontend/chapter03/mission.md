이름 / 닉네임: 백권희 / 라얀
GitHub 저장소: qwedus
Pull Request: o

사용한 go_router 버전:
go_router 18.0.1 

Route 목록: (lib/router/app_router.dart)
- /start            : 시작 화면
- /register         : 회원가입 화면
- ShellRoute 
  - /home           : 홈 화면
  - /movies         : 영화 목록 화면 
  - /my             : 마이페이지
- /movies/:movieId  : 영화 상세 화면 

go / push / pop 사용 위치:
[go] 현재 위치를 새 경로로 바꿔야 할 때
- 시작하기 버튼 → /register
- 회원가입 완료 → /home 
  → 두 경우 모두 이전 화면을 스택에 남기지 않아 회원가입·홈에서 뒤로 가기가 동작하지 않음
    
- NavigationBar 탭 전환 → /home, /movies, /my 
- 홈 '인기 영화'의 전체보기 → /movies
- 장르 Chip 선택 → /movies?genre=장르 
- 상세 화면에서 돌아갈 이전 화면이 없을 때 → /home

[push] 현재 화면을 유지하고 상세 화면을 위에 쌓을 때
- 홈 추천 카드, 상세보기 버튼 → /movies/:movieId
- 홈 가로 목록, 영화 목록 Grid의 영화 카드 → /movies/:movieId 

[pop] 상세 화면에서 이전 화면으로 돌아갈 때
- 상세 AppBar 뒤로가기 버튼 → context.pop()
- Dialog / BottomSheet 닫기 → Navigator.pop으로 선택한 결과 반환

Path Parameter 사용 위치:
- 이동: context.push('/movies/${movie.id}', extra: movie) (MovieCard, FeaturedMovieBanner)
- 읽기: GoRoute(path: '/movies/:movieId')에서
  int.tryParse(state.pathParameters['movieId'])로 영화 ID를 읽고
  findMovieById(movieId)로 Mock Data에서 영화를 찾아 상세 화면에 전달
- 없는 ID면 "영화를 찾을 수 없어요." 화면 표시

Query Parameter와 Extra 비교:

Dialog / BottomSheet / Snackbar 사용 위치:
- Dialog: 영화 상세의 '평점 남기기' 버튼
  → showDialog<double>로 커스텀 RatingDialog 표시
  → 별점 선택 전에는 확인 버튼 비활성화, 확인 시 Navigator.pop으로 별점 반환
- BottomSheet: 영화 상세 AppBar의 공유 아이콘
  → showModalBottomSheet<String>로 공유 방법 선택
- Snackbar: ScaffoldMessenger.of(context).showSnackBar
  → 즐겨찾기 추가/삭제 결과 
  → 평점 등록 결과 
  → BottomSheet에서 고른 공유 결과 
  → 홈·영화 목록의 검색 아이콘 

전체 사용자 흐름 영상:


[MissionVideo.mp4](images/MissionVideo.mp4)

트러블슈팅:
3주차 회고:
