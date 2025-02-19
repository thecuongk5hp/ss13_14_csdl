use ss_13;

-- 2) Tạo bảng bank để lưu thông tin ngân hàng.
create table banks(
	bank_id int primary key auto_increment,
    bank_name varchar(255) not null,
	status enum('ACTIVE','ERROR')
);

--   3) Thêm các bản ghi sau vào banks
INSERT INTO banks (bank_id, bank_name, status) VALUES 
(1,'VietinBank', 'ACTIVE'),   
(2,'Sacombank', 'ERROR'),    
(3, 'Agribank', 'ACTIVE');   

-- 4) Cập nhật bảng company_funds để thêm bank_id làm khóa ngoại liên kết với banks
alter table company_funds
add column bank_id int,
add constraint fk_bank_id foreign key(bank_id) references banks(bank_id);
-- 5) Tiến hành chạy câu lệnh sau
UPDATE company_funds SET bank_id = 1 WHERE balance = 50000.00;
INSERT INTO company_funds (balance, bank_id) VALUES (45000.00,2);
-- 6) Tạo một Trigger có tên CheckBankStatus để kiểm tra trạng thái ngân hàng trước khi thực hiện trả lương cho nhân viên.
DELIMITER &&
	create trigger CheckBankStatus
    before insert on payroll
	for each row
begin
    if (select b.status from banks b join company_funds c on b.bank_id = c.bank_id) = 'ERROR' then 
		signal sqlstate '45000' set message_text = 'Ngân hàng gặp lỗi';
    end if;
end &&
DELIMITER ;
/*
7) Sinh viên cần viết một Stored Procedure có tên TransferSalary, thực hiện quá trình chuyển lương cho nhân viên, 
đảm bảo tính toàn vẹn dữ liệu bằng transaction, và kiểm tra trạng thái ngân hàng trước khi thực hiện giao dịch
*/
set autocommit = 0; 
DELIMITER &&
	create procedure TransferSalary(p_emp_id int,fund_id_in int)
begin
	declare com_balance decimal(10,2);
	declare emp_salary decimal(10,2);
    declare exit handler for sqlexception
            begin
				insert into transaction_log(log_message)
				values('Ngân hàng lỗi');
                rollback;
            end;
	START TRANSACTION;
	if(select count(emp_id) from employees where emp_id = emp_id_in) = 0
    or (select count(fund_id) from company_funds where fund_id = fund_id_in ) = 0 then
		insert into transaction_log(log_message)
			values('Mã nhân viên hoặc mã công ty không tồn tại');
		rollback;
	else
		select balance into com_balance from company_funds where fund_id = fund_id_in;
		select salary into emp_salary from employees where emp_id = emp_id_in;
        if com_balance < emp_salary then
			insert into transaction_log(log_message)
				values('Số dư tài khoản công ty không đủ');
			rollback;
        else
			update company_funds
            set balance = balance - emp_salary
            where fund_id = fund_id_in;
            insert into transaction_log(log_message)
			values('Thanh toán lương thành công');
            insert into payroll(emp_id,salary,pay_date)
            values(emp_id_in,emp_salary,curdate());
            update employees
            set last_pay_date = curdate()
            where emp_id = p_emp_id;
            commit;
		end if;
	end if;
end &&
DELIMITER ;
--  8) Gọi store procedure với tham số tương ứng
call TransferSalary(3,2);