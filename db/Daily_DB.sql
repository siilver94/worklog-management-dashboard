-- Daily_DB 테이블 생성 스크립트
CREATE TABLE Daily_DB (
    ID INT PRIMARY KEY,
    작성일자 VARCHAR(10),
    팀 VARCHAR(50),
    상태 VARCHAR(50),
    업무_계정 VARCHAR(100),
    프로젝트명 VARCHAR(100),
    업무_시작일자 VARCHAR(10),
    업무_종료일자 VARCHAR(10),
    업무제목 VARCHAR(255),
    상세_업무내용 VARCHAR(1000),
    작업내용 VARCHAR(1000),
    작업시간 INT,
    작성자 VARCHAR(100),
    작업_분류 VARCHAR(100),
    피드백 VARCHAR(1000)
);
