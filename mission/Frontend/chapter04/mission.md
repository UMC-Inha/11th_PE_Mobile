이름 / 닉네임: 백권희/라얀
GitHub 저장소: qwedus
Pull Request: o
Loading 화면: success에 첨부
Empty 화면: success에 첨부
Error 및 재시도 영상: success에 첨부
Success 화면: [mission_video_week4.mp4](images/mission_video_week4.mp4)
Future를 생성한 위치: movielog/lib/screens/movies/movie_list_screen.dart 의 _MovieListScreenState.initState()
  - initState()에서 _initialDataFuture = _loadInitialData(mode: _loadMode) 로 한 번만 생성해 State 필드에 보관하고, build()의 FutureBuilder에는 이 필드를 전달합니다.
  loadInitialData()는 Future.wait로 FakeMovieService.fetchMovies()와 GenrePreference.read()를 함께 시작.
  - 재시도(_retry)와 Debug 메뉴(_reloadWith)에서만 setState 안에서 Future를 새로 만들어 교체.

사용한 SharedPreferences Key: selected_genre
  - movielog/lib/services/genre_preference.dart 의 GenrePreference._selectedGenreKey (SharedPreferencesAsync 사용)
  - 장르 Chip 선택 시 setString으로 저장하고, 화면 진입 시 getString으로 읽으며 값이 없으면 전체(allGenreLabel)로 대체. 
앱 재실행 후 복원 영상: [close.mp4](images/close.mp4)
발생한 오류와 해결 과정: empty및 error,success화면 별도의 버튼을 통한 토글 선택으로 만들어 보이게 함
4주차 회고: