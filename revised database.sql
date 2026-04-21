DROP DATABASE IF EXISTS pvamu_registration;
CREATE DATABASE pvamu_registration;
USE pvamu_registration;

-- =========================================================
-- CLEANED DATABASE NOTES
-- standardized ID types so foreign keys match
-- removed invalid zero dates
-- split degree_plan into plan + course mapping
-- added term table for UI alignment
-- expanded section for registration display
-- fixed waitlist scoring logic
-- =========================================================


-- =======================
-- TERM TABLE (NEW)
-- supports dropdown + profile display
-- =======================
CREATE TABLE academic_term (
    term_id INT AUTO_INCREMENT PRIMARY KEY,
    term_code VARCHAR(20) UNIQUE,
    semester ENUM('Fall','Spring','Summer'),
    calendar_year SMALLINT,
    display_name VARCHAR(30)
);


-- =======================
-- MAJOR
-- =======================
CREATE TABLE major (
    major_id INT AUTO_INCREMENT PRIMARY KEY,
    major_name VARCHAR(100),
    total_credits_required INT,
    degree_type VARCHAR(10)
);

-- =======================
-- COURSE
-- code for display, id for joins
-- =======================
CREATE TABLE course (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(20) UNIQUE,
    course_name VARCHAR(100),
    credit_hours INT,
    department VARCHAR(50)
);


-- =======================
-- DEGREE PLAN (fixed structure)
-- =======================
CREATE TABLE degree_plan (
    degree_plan_id INT AUTO_INCREMENT PRIMARY KEY,
    major_id INT,
    plan_name VARCHAR(100),
    FOREIGN KEY (major_id) REFERENCES major(major_id)
);

-- =======================
-- STUDENT
-- TEXT -> VARCHAR + added profile fields
-- =======================
CREATE TABLE student (
    student_id INT PRIMARY KEY,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100) UNIQUE,
    classification VARCHAR(20),
    major_id INT,
    minor_id INT,
    total_credits_completed INT DEFAULT 0,
    graduation_month VARCHAR(15),
    graduation_year INT,
    first_term_id INT,
    current_term_id INT,
    sex char(1),
    degree_plan_id INT,
    FOREIGN KEY (major_id) REFERENCES major(major_id),
    FOREIGN KEY (minor_id) REFERENCES major(major_id),
    FOREIGN KEY (degree_plan_id) REFERENCES degree_plan(degree_plan_id)
);

-- =======================
-- DEGREE PLAN COURSE (NEW)
-- fixes redundancy issue
-- =======================
CREATE TABLE degree_plan_course (
    id INT AUTO_INCREMENT PRIMARY KEY,
    degree_plan_id INT,
    course_id INT,
    is_required BOOLEAN,
    recommended_semester INT,
    FOREIGN KEY (degree_plan_id) REFERENCES degree_plan(degree_plan_id),
    FOREIGN KEY (course_id) REFERENCES course(course_id)
);


-- =======================
-- SECTION (updated for UI)
-- =======================
CREATE TABLE section (
    section_id INT AUTO_INCREMENT PRIMARY KEY,
    term_id INT,
    course_id INT,
    crn VARCHAR(10),
    campus VARCHAR(50),
    day_of_class VARCHAR(10),
    start_time TIME,
    end_time TIME,
    modality VARCHAR(20),
    capacity INT,
    enrollment_count INT DEFAULT 0,
    FOREIGN KEY (course_id) REFERENCES course(course_id),
    FOREIGN KEY (term_id) REFERENCES academic_term(term_id)
);


-- =======================
-- ENROLLMENT
-- fixed PK + removed bad dates
-- =======================
CREATE TABLE enrollment (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT,
    section_id INT,
    status VARCHAR(20),
    grade VARCHAR(2),
    date_enrolled DATETIME DEFAULT CURRENT_TIMESTAMP,
    credits_earned INT DEFAULT 0,
    UNIQUE(student_id, section_id),
    FOREIGN KEY (student_id) REFERENCES student(student_id),
    FOREIGN KEY (section_id) REFERENCES section(section_id)
);


-- =======================
-- WAITLIST
-- =======================
CREATE TABLE waitlist (
    waitlist_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT,
    section_id INT,
    priority_score INT DEFAULT 0,
    timestamp_joined DATETIME DEFAULT CURRENT_TIMESTAMP,
    notification_sent BOOLEAN DEFAULT 0,
    expiration_time DATETIME,
    FOREIGN KEY (student_id) REFERENCES student(student_id),
    FOREIGN KEY (section_id) REFERENCES section(section_id)
);


-- =======================
-- FUNCTION FIXED
-- =======================
DELIMITER $$

CREATE FUNCTION calculate_priority_score (
    p_student_id INT,
    p_section_id INT,
    p_timestamp DATETIME
)
RETURNS INT
NOT DETERMINISTIC
BEGIN
    DECLARE score INT DEFAULT 0;
    DECLARE v_major_id INT;
    DECLARE v_course_id INT;
    DECLARE v_grad_month VARCHAR(15);
    DECLARE v_grad_year INT;
    DECLARE grad_date DATE;

    SELECT major_id, graduation_month, graduation_year
    INTO v_major_id, v_grad_month, v_grad_year
    FROM student WHERE student_id = p_student_id;

    SELECT course_id INTO v_course_id
    FROM section WHERE section_id = p_section_id;

    -- fixed date spacing
    SET grad_date = STR_TO_DATE(
        CONCAT('01 ', v_grad_month, ' ', v_grad_year),
        '%d %M %Y'
    );

    -- graduation priority
    IF TIMESTAMPDIFF(MONTH, CURDATE(), grad_date) <= 6 THEN
        SET score = score + 50;
    END IF;

    -- required course check (fixed structure)
    IF EXISTS (
        SELECT 1
        FROM degree_plan dp
        JOIN degree_plan_course dpc
            ON dp.degree_plan_id = dpc.degree_plan_id
        WHERE dp.major_id = v_major_id
        AND dpc.course_id = v_course_id
        AND dpc.is_required = TRUE
    ) THEN
        SET score = score + 30;
    END IF;

    -- wait time factor
    SET score = score + LEAST(TIMESTAMPDIFF(DAY, p_timestamp, NOW()) * 2, 20);

    RETURN score;
END$$

DELIMITER ;


-- =======================
-- TRIGGER
-- =======================
DELIMITER $$

CREATE TRIGGER trg_waitlist_score
BEFORE INSERT ON waitlist
FOR EACH ROW
BEGIN
    SET NEW.priority_score =
        calculate_priority_score(
            NEW.student_id,
            NEW.section_id,
            NEW.timestamp_joined
        );
END$$

DELIMITER ;


-- =======================
-- INSERT DATA (UPDATED)
-- =======================

INSERT INTO academic_term (term_code, semester, calendar_year, display_name) VALUES
('FALL2022','Fall',2022,'Fall 2022'),
('SPRING2023','Spring',2023,'Spring 2023'),
('FALL2023','Fall',2023,'Fall 2023'),
('SPRING2024','Spring',2024,'Spring 2024'),
('FALL2024','Fall',2024,'Fall 2024'),
('SPRING2025','Spring',2025,'Spring 2025'),
('FALL2025','Fall',2025,'Fall 2025'),
('SPRING2026','Spring',2026,'Spring 2026'),
('FALL2026','Fall',2026,'Fall 2026');

INSERT INTO major VALUES
(1,'Computer Science',120,'BS'),
(2,'Mathematics',120,'BS');

INSERT INTO course VALUES
(201,'COMP3395','Database Systems',3,'CS'),
(202,'COMP2336','Data Structures',3,'CS'),
(203,'COMP3305','Analysis of Algorithms',3,'CS'),
(204,'COMP3306','Operating Systems',3,'CS'),
(205,'COMP3322','Software Engineering',3,'CS');

INSERT INTO degree_plan VALUES
(1,1,'CS Plan');

INSERT INTO student VALUES
(101,'India','Hoover','india@email.com','Senior',1,NULL,105,'May',2026,1,1,'F',1),
(102,'Sarah','Obeng','sarah@email.com','Junior',1,NULL,75,'May',2027,1,1,'F',1),
(103,'Isaac','Florence','isaac@email.com','Junior','1','2',80,'May',2027,3,8,'M',1);

INSERT INTO degree_plan_course VALUES
(1,1,201,1,6),
(2,1,202,1,4);

INSERT INTO section VALUES
(1,1,201,'5000','MAIN','MWF','08:00:00','08:50:00','In Person',35,27),
(2,1,202,'2500','MAIN','TUTH','08:00:00','09:15:00','Synchronous',35,12),
(3,1,203,'3761','MAIN','TUTH','09:30:00','10:50:00','In Person',35,21),
(4,1,204,'3198','MAIN','MWF','13:00:00','13:50:00','In Person',35,31),
(4,1,205,'8163','MAIN','TUTH','15:30:00','16:50:00','In Person',35,19);

INSERT INTO enrollment (student_id, section_id, status)
VALUES
(101,1,'Completed'),
(102,2,'Enrolled');

INSERT INTO waitlist (student_id, section_id)
VALUES
(101,2),
(102,1);
