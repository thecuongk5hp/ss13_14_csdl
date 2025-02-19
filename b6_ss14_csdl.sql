USE ss14_second;
/*
2) Công ty muốn đảm bảo rằng số điện thoại của nhân viên luôn có đúng 10 chữ số. 
Nếu một nhân viên cập nhật số điện thoại không đủ hoặc nhiều hơn 10 chữ số, hệ thống sẽ từ chối cập nhật.
Hãy viết một Trigger BEFORE UPDATE để kiểm soát điều này.
*/
DELIMITER &&
create trigger before_update_phone
before update on employees
for each row
begin
    if length(new.phone) <> 10 or new.phone not regexp '^[0-9]+$' then
        signal sqlstate '45000' set message_text = 'số điện thoại phải có đúng 10 chữ số!';
    end if;
end &&
DELIMITER ;
-- 3) Tạo bảng notifications theo đoạn code dưới đây
CREATE TABLE notifications (

    notification_id INT PRIMARY KEY AUTO_INCREMENT,

    employee_id INT NOT NULL,

    message TEXT NOT NULL,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

 FOREIGN KEY (employee_id) REFERENCES employees(employee_id) ON DELETE CASCADE

);
/*
4) Mỗi khi một nhân viên mới được thêm vào bảng employees, hệ thống cần tự động tạo một thông báo chào mừng cho họ trong bảng 
notifications tương ứng với employee đã được thêm và message là “Chào mừng”
*/
DELIMITER &&
create trigger after_insert_employee
after insert on employees
for each row
begin
    insert into notifications (employee_id, message)
    values (new.employee_id, 'chào mừng');
end &&
DELIMITER ;
/*
5) Khi công ty tuyển dụng một nhân viên mới, hệ thống sẽ thực hiện các thao tác kiểm tra email, số điện thoại, 
thêm mới nhân viên và tiến hành cập nhật nhân viên đó nếu hợp lệ đồng thời ghi lại thông tin vào bảng notifications.
*/
DELIMITER &&
create procedure AddNewEmployeeWithPhone(
    in emp_name varchar(255),
    in emp_email varchar(255),
    in emp_phone varchar(20),
    in emp_hire_date date,
    in emp_department_id int
)
begin
    declare emp_id int;
    declare emp_exists int default 0;
    if length(emp_phone) <> 10 or emp_phone not regexp '^[0-9]+$' then
        signal sqlstate '45000' set message_text = 'số điện thoại phải có đúng 10 chữ số!';
    end if;
    select count(*) into emp_exists from employees where email = emp_email;
    if emp_exists > 0 then
        signal sqlstate '45000' set message_text = 'email đã tồn tại, không thể thêm nhân viên mới!';
    end if;
	START TRANSACTION;
    insert into employees (name, email, phone, hire_date, department_id)
    values (emp_name, emp_email, emp_phone, emp_hire_date, emp_department_id);
    set emp_id = last_insert_id();
    commit;
end &&
DELIMITER ;