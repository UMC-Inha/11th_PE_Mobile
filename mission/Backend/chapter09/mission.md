## Week 9 Mission

![Bm1](images/Bm1.jpeg)

![스크린샷 2026-11-25 181940](<images/스크린샷 2026-11-25 181940.png>)

### RatingApiTest.java

```java
package com.umc.movie.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.umc.movie.dto.CreateRatingRequest;
import com.umc.movie.entity.Member;
import com.umc.movie.repository.MemberRepository;
import com.umc.movie.repository.RatingRepository;
import com.umc.movie.util.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class RatingApiTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private RatingRepository ratingRepository;

    @Autowired
    private JwtUtil jwtUtil;

    private Member member;
    private String authorizationHeader;

    @BeforeEach
    void setUp() {
        member = memberRepository.save(Member.builder()
                .email("challenger@umc.com")
                .password("$2a$10$abcdefghijklmnopqrstuv") // 로그인 API를 거치지 않으므로 아무 값이나 괜찮습니다
                .nickname("영화조아")
                .build());

        authorizationHeader = "Bearer " + jwtUtil.createAccessToken(member.getMemberId(), member.getEmail());
    }

    @Test
    @DisplayName("토큰 없이 평점을 등록하면 401과 AUTH401_2를 응답하고 평점은 저장되지 않는다")
    void createRatingWithoutToken() throws Exception {
        long before = ratingRepository.count();

        mockMvc.perform(post("/ratings")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateRatingRequest(550L, 5, "최고의 영화"))))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.isSuccess").value(false))
                .andExpect(jsonPath("$.code").value("AUTH401_2"));

        assertThat(ratingRepository.count()).isEqualTo(before);
    }

    @Test
    @DisplayName("토큰을 담아 평점을 등록하면 201과 COMMON201, 저장된 평점 정보를 응답한다")
    void createRating() throws Exception {
        mockMvc.perform(post("/ratings")
                        .header(HttpHeaders.AUTHORIZATION, authorizationHeader)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateRatingRequest(550L, 5, "최고의 영화"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.isSuccess").value(true))
                .andExpect(jsonPath("$.code").value("COMMON201"))
                .andExpect(jsonPath("$.result.ratingId").isNumber())
                .andExpect(jsonPath("$.result.movieId").value(550))
                .andExpect(jsonPath("$.result.score").value(5))
                .andExpect(jsonPath("$.result.comment").value("최고의 영화"));

        // 응답만 믿지 않고, 토큰 주인의 평점으로 DB에 실제 저장됐는지도 확인합니다
        assertThat(ratingRepository.existsByMember_MemberIdAndMovieId(member.getMemberId(), 550L)).isTrue();
    }
}
```

### RatingServiceTest.java

```java
package com.umc.movie.service;

import com.umc.movie.dto.CreateRatingRequest;
import com.umc.movie.dto.UpdateRatingRequest;
import com.umc.movie.entity.Member;
import com.umc.movie.entity.Rating;
import com.umc.movie.exception.ApiException;
import com.umc.movie.repository.MemberRepository;
import com.umc.movie.repository.RatingRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class RatingServiceTest {

    @Mock
    private RatingRepository ratingRepository;

    @Mock
    private MemberRepository memberRepository;

    @InjectMocks
    private RatingService ratingService;

    // memberId는 DB가 채워주는 값이라 setter가 없습니다. 테스트에서만 리플렉션으로 넣어줍니다.
    private Member createMember(Long memberId, String email, String nickname) {
        Member member = Member.builder()
                .email(email)
                .password("암호화된비밀번호")
                .nickname(nickname)
                .build();
        ReflectionTestUtils.setField(member, "memberId", memberId);
        return member;
    }

    @Test
    @DisplayName("같은 영화에 평점을 중복 등록하면 409 RATING409_1 예외를 던지고 저장하지 않는다")
    void createRatingWhenDuplicated() {
        // given: 회원은 존재하고, 이미 이 영화에 평점을 남긴 상황
        Member me = createMember(1L, "challenger@umc.com", "영화조아");
        given(memberRepository.findById(1L)).willReturn(Optional.of(me));
        given(ratingRepository.existsByMember_MemberIdAndMovieId(1L, 550L)).willReturn(true);

        // when & then: RATING409_1 예외가 나고, 저장은 시도조차 하지 않는다
        assertThatThrownBy(() -> ratingService.create(1L, new CreateRatingRequest(550L, 5, "또 남기기")))
                .isInstanceOf(ApiException.class)
                .hasMessage("이미 이 영화에 평점을 남기셨습니다.")
                .satisfies(e -> {
                    ApiException exception = (ApiException) e;
                    assertThat(exception.getStatus()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(exception.getCode()).isEqualTo("RATING409_1");
                });

        verify(ratingRepository, never()).save(any(Rating.class));
    }

    @Test
    @DisplayName("남의 평점을 수정하려 하면 403 RATING403_1 예외를 던지고 평점은 바뀌지 않는다")
    void updateOthersRating() {
        // given: 10번 평점은 2번 회원(다른 사람)의 것인데, 1번 회원이 수정하려는 상황
        Member other = createMember(2L, "other@umc.com", "남의평점");
        Rating othersRating = Rating.builder()
                .member(other)
                .movieId(550L)
                .score(3)
                .comment("원래 후기")
                .build();
        given(ratingRepository.findById(10L)).willReturn(Optional.of(othersRating));

        // when & then: RATING403_1 예외가 난다
        assertThatThrownBy(() -> ratingService.update(1L, 10L, new UpdateRatingRequest(1, "몰래 수정")))
                .isInstanceOf(ApiException.class)
                .hasMessage("본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.")
                .satisfies(e -> {
                    ApiException exception = (ApiException) e;
                    assertThat(exception.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(exception.getCode()).isEqualTo("RATING403_1");
                });

        // then: 원래 평점 내용은 그대로이고, 저장도 호출되지 않는다
        assertThat(othersRating.getScore()).isEqualTo(3);
        assertThat(othersRating.getComment()).isEqualTo("원래 후기");
        verify(ratingRepository, never()).saveAndFlush(any(Rating.class));
    }
}
```
