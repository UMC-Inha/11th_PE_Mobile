PR 링크:
TMDB Token 비노출 확인:Token은 .env에만 저장하고 .gitignore에 등록했으며, 저장소에는 빈 .env.example만 커밋함.
Popular 5개 화면: /movie/popular 응답의 results.take(5)로 홈에 5개를 표시하며, 5개 미만이어도 오류 없이 표시함.
  - [20261028-0741-57.7368768.mp4](images/20261028-0741-57.7368768.mp4)
Discover 최대 30개 화면과 실제 개수: TMDB id를 Map의 key로 써서 중복을 제거함.
  - [20261028-0747-27.8109526.mp4](images/20261028-0747-27.8109526.mp4)
Genre API 및 with_genres 요청 증거:
- 장르 Chip은 Genre API의 id와 name으로 구성하며, "전체"는 with_genres 없이 요청함.
- 장르 선택 시 page 1부터 다시 요청하며, 요청 중에는 장르를 바꿀 수 없음.
Loading / Empty / Error / Success:
- Provider 기반 ViewModel의 상태값에 따라 로딩 표시, 빈 목록 안내, 오류와 재시도 버튼, 영화 목록을 표시함.
- 재시도할 때 선택한 장르를 유지하며, 늦게 도착한 이전 응답은 무시함.
포스터 null·실패 처리: TmdbPosterImage가 poster_path로 이미지 URL을 만들고, 값이 null이거나 로드에 실패하면 placeholder를 표시함.
movie.id 전달 위치:
- tmdb_movie_card.dart, featured_movie_banner.dart에서 /movies/${movie.id}로 상세 화면에 이동함.
- movie_detail_screen.dart에서 RatingDialog(movieId: movie.id)로 평점 Dialog에 전달함.
트러블슈팅:
미검증 항목:
