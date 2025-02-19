use ss14_first;

-- 2) Hãy tạo một trigger BEFORE INSERT để kiểm tra giá trị thanh toán trước khi thêm vào bảng payments với yêu cầu sau:
-- Số tiền thanh toán (amount) phải đúng với tổng tiền của đơn hàng.
-- Nếu số tiền thanh toán nhỏ hơn tổng tiền đơn hàng, báo lỗi SQLSTATE '45000' với MESSAGE_TEXT = 'Số tiền thanh toán không khớp với tổng đơn hàng!'.
delimiter //
create trigger before_insert_check_payment
before insert on payments
for each row
begin
    declare order_total decimal(10,2);
    select total_amount into order_total from orders where order_id = new.order_id;
    if new.amount <> order_total then
        signal sqlstate '45000'
        set message_text = 'số tiền thanh toán không khớp với tổng đơn hàng!';
    end if;
end //
delimiter ;
-- 3 Tạo bảng lưu log thay đổi trạng thái đơn hàng
CREATE TABLE order_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    old_status ENUM('Pending', 'Completed', 'Cancelled'),
    new_status ENUM('Pending', 'Completed', 'Cancelled'),
    log_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- 4) Hãy tạo Trigger after_update_order_status: Trigger này sẽ được kích hoạt sau khi cập nhật trạng thái của đơn hàng trong bảng orders.
-- Kiểm tra nếu trạng thái đơn hàng có sự thay đổi, tức là giá trị OLD.status khác với NEW.status.
-- Nếu có sự thay đổi trạng thái, trigger sẽ thực hiện ghi log vào bảng order_logs với thông tin order_id, old_status, new_status, 
-- và thời gian thay đổi trạng thái (NOW()).
delimiter //
create trigger after_update_order_status
after update on orders
for each row
begin
    if old.status <> new.status then
        insert into order_logs (order_id, old_status, new_status, log_date)
        values (new.order_id, old.status, new.status, now());
    end if;
end //
delimiter ;

-- 5) Hãy tạo một Stored Procedure có tên sp_update_order_status_with_payment để xử lý việc cập nhật trạng thái đơn hàng và thanh toán bằng transaction. 
-- Transaction này sẽ kết hợp 2 trigger để đảm bảo tính toàn vẹn dữ liệu
delimiter //
create procedure sp_update_order_status_with_payment(
    p_order_id int,
    p_new_status enum('pending', 'completed', 'cancelled'),
    p_payment_amount decimal(10,2),
    p_payment_method enum('credit card', 'paypal', 'bank transfer', 'cash')
)
begin
    declare v_current_status enum('pending', 'completed', 'cancelled');
    declare v_total_amount decimal(10,2);
    start transaction;
    select status, total_amount into v_current_status, v_total_amount 
    from orders 
    where order_id = p_order_id;
    if v_current_status = p_new_status then
        rollback;
        signal sqlstate '45000'
        set message_text = 'đơn hàng đã có trạng thái này!';
    end if;
    if p_new_status = 'completed' then
        insert into payments (order_id, amount, payment_method, status)
        values (p_order_id, p_payment_amount, p_payment_method, 'completed');
    end if;
    update orders set status = p_new_status where order_id = p_order_id;
    commit;
end //
delimiter ;

-- 6) Hãy thêm các bản ghi cần thiết đồng thời hãy gọi STORE PROCEDURE trên với một tham số tương ứng
insert into customers (name, email, phone, address) 
values ('nguyễn văn a', 'nguyenvana@example.com', '0123456789', 'hà nội');
insert into products (name, price, description) 
values ('áo thun', 200000, 'áo thun cotton');
insert into orders (customer_id, total_amount, status) 
values (1, 200000, 'pending');
insert into order_items (order_id, product_id, quantity, price) 
values (1, 1, 1, 200000);
call sp_update_order_status_with_payment(1, 'completed', 200000, 'cash');
-- 7) Hiển thị lại order_logs để quan sát 
select * from order_logs;
-- 8) Hãy xóa tất cả các trigger và transaction trên
drop trigger if exists before_insert_check_payment;
drop trigger if exists after_update_order_status;
drop procedure if exists sp_update_order_status_with_payment;
