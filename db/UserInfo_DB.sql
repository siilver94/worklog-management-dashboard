-- UserInfo_DB 테이블 생성 스크립트 (앱이 참조하는 컬럼만 공개)
CREATE TABLE UserInfo_DB (
    이름_한글 VARCHAR(100),
    이름_영문 VARCHAR(100),
    e_mail VARCHAR(100),
    부문 VARCHAR(50),
    팀 VARCHAR(50),
    직급 VARCHAR(50),
    직급2 VARCHAR(20),   -- 팀원 / 팀장 / 부문장 / 소장
    사번 INT PRIMARY KEY
);
