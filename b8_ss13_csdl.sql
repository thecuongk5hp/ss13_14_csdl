use ss_13;
-- 2) Tạo bảng student_status để lưu trữ trạng thái học tập của sinh viên 
create table student_status(
	student_id int primary key,
    status enum('ACTIVE','GRADUATED','SUSPENED'),
    foreign key (student_id) references students(student_id)
);
-- 3) Thực hiện thêm 2 bản ghi sau:
INSERT INTO student_status (student_id, status) VALUES
(1, 'ACTIVE'), -- Nguyễn Văn An có thể đăng ký
(2, 'GRADUATED'); -- Trần Thị Ba đã tốt nghiệp, không thể đăng ký
-- 4) Viết một Stored Procedure trong MySQL để thực hiện transaction nhằm đăng ký học phần cho một sinh viên vào một môn học bất kỳ, thực hiện theo các bước sau:
DELIMITER &&
create procedure register_course(
    in p_student_name varchar(50),
    in p_course_name varchar(100)
)
begin
    declare v_student_id int;
    declare v_course_id int;
    declare v_available_seats int;
    declare v_student_status varchar(10);
    
    declare exit handler for sqlexception
    begin
        rollback;
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'FAILED: Transaction error', now());
        select 'Transaction error, rolled back' as message;
    end;
	START TRANSACTION;
    select student_id into v_student_id from students where student_name = p_student_name;
    if v_student_id is null then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (null, null, 'FAILED: Student does not exist', now());
        signal sqlstate '45000' set message_text = 'Student does not exist';
    end if;
    select course_id, available_seats into v_course_id, v_available_seats from courses where course_name = p_course_name;
    if v_course_id is null then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, null, 'FAILED: Course does not exist', now());
        signal sqlstate '45000' set message_text = 'Course does not exist';
    end if;
    if exists (select 1 from enrollments where student_id = v_student_id and course_id = v_course_id) then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'FAILED: Already enrolled', now());
        signal sqlstate '45000' set message_text = 'Already enrolled in this course';
    end if;
    select status into v_student_status from student_status where student_id = v_student_id;
    if v_student_status in ('GRADUATED', 'SUSPENDED') then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'FAILED: Student not eligible', now());
        signal sqlstate '45000' set message_text = 'Student is not eligible to enroll';
    end if;
    if v_available_seats > 0 then
        insert into enrollments (student_id, course_id) values (v_student_id, v_course_id);
        update courses set available_seats = available_seats - 1 where course_id = v_course_id;
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'REGISTERED', now());
        commit;
    else
        rollback;
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'FAILED: No available seats', now());
        signal sqlstate '45000' set message_text = 'No available seats';
    end if;
end &&
DELIMITER ;
-- 5) Gọi thủ tục với tham số tương ứng
call register_course('Nguyễn Văn An', 'Lập trình C');
call register_course('Trần Thị Ba', 'Cơ sở dữ liệu');
-- 6) Hiển thị lại các bảng enrollments, courses, enrollments_history để kiểm chúng
select * from enrollments;
select * from courses;
select * from enrollments_history;