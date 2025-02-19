use ss_13;

create table account (
    acc_id int primary key auto_increment,
    emp_id int not null,
    bank_id int not null,
    amount_added decimal(15,2) not null,
    total_amount decimal(15,2) not null,
    foreign key (emp_id) references employees(emp_id),
    foreign key (bank_id) references banks(bank_id)
);
-- 3) Thêm các bản ghi sau:
INSERT INTO account (emp_id, bank_id, amount_added, total_amount) VALUES
(1, 1, 0.00, 12500.00),  
(2, 1, 0.00, 8900.00),   
(3, 1, 0.00, 10200.00),  
(4, 1, 0.00, 15000.00),  
(5, 1, 0.00, 7600.00);
-- 4) Viết một Stored Procedure TransferSalaryAll để tự động trả lương cho tất cả nhân viên mà không cần phải chỉ định một nhân viên cụ thể, đồng thời cập nhật bảng account, 
DELIMITER &&
create procedure TransferSalaryAll()
begin
    declare done int default 0;
    declare v_emp_id int;
    declare v_salary decimal(10,2);
    declare v_balance decimal(15,2);
    declare v_bank_id int;
    declare v_total_employees int default 0;
    declare exit handler for sqlexception 
    begin
        rollback;
        insert into transaction_log (log_message) values ('Lỗi xảy ra trong quá trình chuyển lương.');
    end;
    select balance, bank_id into v_balance, v_bank_id from company_funds limit 1;
    if v_balance < (select sum(salary) from employees) then
        insert into transaction_log (log_message) values ('Lỗi: Quỹ công ty không đủ tiền để trả lương.');
        leave;
    end if;
    declare cur cursor for select emp_id, salary from employees;
    declare continue handler for not found set done = 1;
    START TRANSACTION;
    open cur;
    read_loop: loop
        fetch cur into v_emp_id, v_salary;
        if done then
            leave read_loop;
        end if;
        update company_funds set balance = balance - v_salary where bank_id = v_bank_id;
        insert into payroll (emp_id, salary, pay_date) values (v_emp_id, v_salary, curdate());
        update employees set last_pay_date = curdate() where emp_id = v_emp_id;
        update account 
        set amount_added = v_salary, total_amount = total_amount + v_salary
        where emp_id = v_emp_id;
        set v_total_employees = v_total_employees + 1;
    end loop;
    close cur;
    insert into transaction_log (log_message) values (concat('Đã chuyển lương cho ', v_total_employees, ' nhân viên.'));
    commit;
end &&
DELIMITER ;
-- 5) Gọi lại thủ tục trên
call TransferSalaryAll();
-- 6) Hiển thị lại các bảng company_funds, payroll, account, transaction_log để quan sát sự thay đổi sau khi chuyển tiền
select * from company_funds;
select * from payroll;
select * from account;
select * from transaction_log;