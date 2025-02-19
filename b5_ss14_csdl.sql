USE ss14_second;
-- 2) Hãy tạo một trigger BEFORE INSERT để kiểm tra giá trị thanh toán trước khi thêm vào bảng payments
DELIMITER &&
create trigger before_insert_check_payment
before insert on payments
for each row
begin
    declare order_total decimal(10,2);
    select total_amount into order_total
    from orders
    where order_id = new.order_id;
    if new.amount < order_total then
        signal sqlstate '45000' set message_text = 'số tiền thanh toán không khớp với tổng đơn hàng!';
    end if;
end &&
DELIMITER ;
--  3) Tiến hành tạo bảng order_logs để lưu lịch sử đơn hàng
CREATE TABLE order_logs (

    log_id INT PRIMARY KEY AUTO_INCREMENT,

    order_id INT NOT NULL,

    old_status ENUM('Pending', 'Completed', 'Cancelled'),

    new_status ENUM('Pending', 'Completed', 'Cancelled'),

    log_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE

);
-- 4) Hãy tạo Trigger after_update_order_status: Trigger này sẽ được kích hoạt sau khi cập nhật trạng thái của đơn hàng trong bảng orders.
DELIMITER &&
create trigger after_update_order_status
after update on orders
for each row
begin
    if old.status <> new.status then
        insert into order_logs (order_id, old_status, new_status, log_date)
        values (new.order_id, old.status, new.status, now());
    end if;
end &&
DELIMITER ;
-- 5) Hãy tạo một Stored Procedure có tên sp_update_order_status_with_payment để xử lý việc cập nhật trạng thái đơn hàng và thanh toán bằng transaction.
DELIMITER &&
create procedure sp_update_order_status_with_payment(
    in order_id int,
    in new_status enum('Pending', 'Completed', 'Cancelled'),
    in amount decimal(10,2),
    in payment_method varchar(20)
)
begin
    declare current_status enum('Pending', 'Completed', 'Cancelled');
    START TRANSACTION;
    select status into current_status
    from orders
    where order_id = order_id;
    if current_status = new_status then
        rollback;
        signal sqlstate '45000' set message_text = 'đơn hàng đã có trạng thái này!';
    else
        if new_status = 'Completed' then
            insert into payments (order_id, payment_date, amount, payment_method, status)
            values (order_id, now(), amount, payment_method, 'Completed');
        end if;
        update orders
        set status = new_status
        where order_id = order_id;
        commit;
    end if;
end &&
DELIMITER ;
-- 6) Hãy thêm các bản ghi cần thiết đồng thời hãy gọi STORE PROCEDURE trên với một tham số tương ứng

insert into customers (name, email, phone, address) 
values ('Nguyễn Văn A', 'nguyenvana@example.com', '0123456789', 'Hà Nội');

insert into products (name, price, description) 
values ('Laptop Dell', 15000000, 'Laptop cao cấp');

insert into inventory (product_id, stock_quantity) 
values (1, 10);

insert into orders (customer_id, order_date, total_amount, status)
values (1, now(), 15000000, 'Pending');

insert into order_items (order_id, product_id, quantity, price)
values (1, 1, 1, 15000000);

call sp_update_order_status_with_payment(1, 'Completed', 15000000, 'Credit Card');
-- 7) Hiển thị lại order_logs để quan sát 
select * from order_logs;
-- 8) Hãy xóa tất cả các trigger và transaction trên
drop trigger if exists before_insert_check_payment;
drop trigger if exists after_update_order_status;
drop procedure if exists sp_update_order_status_with_payment;