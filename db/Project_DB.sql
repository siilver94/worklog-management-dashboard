-- Project_DB 테이블 생성 스크립트
CREATE TABLE Project_DB (
    ID INT PRIMARY KEY,
    상태 VARCHAR(50),
    연구비_계정 VARCHAR(100),
    업무_계정 INT,
    프로젝트명 VARCHAR(255),
    PM VARCHAR(100),
    관련기종명 VARCHAR(100),
    시작날짜 DATE,
    종료날짜 DATE,
    비고 VARCHAR(500),
    금액_항목1 INT,   -- 예산 항목별 금액 컬럼 (공개용으로 항목명 생략)
    금액_항목2 INT
);
