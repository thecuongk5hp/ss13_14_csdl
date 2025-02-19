use ss_13;

-- 2) Tạo bảng course_fees và bảng student_wallets để lưu học phí của từng môn và quản lý số dư tài khoản của từng sinh viên. Tiến hành chạy đoạn code sau:
CREATE TABLE course_fees (
    course_id INT PRIMARY KEY,
    fee DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (course_id) REFERENCES courses(course_id) ON DELETE CASCADE
);

CREATE TABLE student_wallets (
    student_id INT PRIMARY KEY,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0,
    FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
);

-- 3) Tiến hành thêm lần lượt các bản ghi sau:
INSERT INTO course_fees (course_id, fee) VALUES
(1, 100.00), -- Lập trình C: 100$
(2, 150.00); -- Cơ sở dữ liệu: 150$

INSERT INTO student_wallets (student_id, balance) VALUES
(1, 200.00), -- Nguyễn Văn An có 200$
(2, 50.00);  -- Trần Thị Ba chỉ có 50$

-- 4) Viết một Stored Procedure trong MySQL để thực hiện transaction nhằm đăng ký học phần cho một sinh viên vào một môn học bất kỳ, 
-- đồng thời xử lý thanh toán học phí và kiểm tra các điều kiện liên quan.

DELIMITER &&
create procedure register_course(
    in p_student_name varchar(50),
    in p_course_name varchar(100)
)
begin
    declare v_student_id int;
    declare v_course_id int;
    declare v_available_seats int;
    declare v_fee decimal(10,2);
    declare v_balance decimal(10,2);
    declare exit handler for sqlexception
    begin
        rollback;
        signal sqlstate '45000' set message_text = 'transaction rolled back due to an error';
    end;
    START TRANSACTION;
    select student_id into v_student_id from students where student_name = p_student_name;
    if v_student_id is null then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (null, null, 'failed: student does not exist', now());
        rollback;
        signal sqlstate '45000' set message_text = 'error: student does not exist';
    end if;
    select course_id, available_seats into v_course_id, v_available_seats from courses where course_name = p_course_name;
    if v_course_id is null then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, null, 'failed: course does not exist', now());
        rollback;
        signal sqlstate '45000' set message_text = 'error: course does not exist';
    end if;
    if exists (select 1 from enrollments where student_id = v_student_id and course_id = v_course_id) then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'failed: already enrolled', now());
        rollback;
        signal sqlstate '45000' set message_text = 'error: already enrolled in this course';
    end if;
    if v_available_seats <= 0 then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'failed: no available seats', now());
        rollback;
        signal sqlstate '45000' set message_text = 'error: no available seats';
    end if;
    select balance into v_balance from student_wallets where student_id = v_student_id;
    select fee into v_fee from course_fees where course_id = v_course_id;
    if v_balance < v_fee then
        insert into enrollments_history (student_id, course_id, action, time_stamp) 
        values (v_student_id, v_course_id, 'failed: insufficient balance', now());
        rollback;
        signal sqlstate '45000' set message_text = 'error: insufficient balance';
    end if;
    insert into enrollments (student_id, course_id) values (v_student_id, v_course_id);
    update student_wallets set balance = balance - v_fee where student_id = v_student_id;
    update courses set available_seats = available_seats - 1 where course_id = v_course_id;
    insert into enrollments_history (student_id, course_id, action, time_stamp) 
    values (v_student_id, v_course_id, 'registered', now());
    commit;
    select 'success: enrollment completed' as message;
end &&
DELIMITER ;
-- 5) Tiến hành gọi thủ tục trên với tham số tương ứng.
call register_course('Nguyễn Văn An', 'Lập trình C');
-- 6) Kiểm tra lại tiền của sinh viên sau khi đăng ký thành công
select * from student_wallets;
