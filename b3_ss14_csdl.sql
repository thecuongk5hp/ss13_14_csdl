USE ss14_second;
-- 2) Hãy tạo một Stored Procedure có tên sp_create_order để xử lý việc đặt hàng với transaction.
DELIMITER &&
create procedure sp_create_order(
    in customer_id int,
    in product_id int,
    in quantity int,
    in price decimal(10,2)
)
begin
    declare stock_available int;
    declare new_order_id int;
    START TRANSACTION;
    select stock_quantity into stock_available
    from inventory
    where product_id = product_id;
    if stock_available < quantity then
        rollback;
        signal sqlstate '45000' set message_text = 'không đủ hàng trong kho!';
    else
        insert into orders (customer_id, order_date, total_amount, status)
        values (customer_id, now(), 0, 'Pending');
        set new_order_id = last_insert_id();
        insert into order_items (order_id, product_id, quantity, price)
        values (new_order_id, product_id, quantity, price);
        update inventory
        set stock_quantity = stock_quantity - quantity
        where product_id = product_id;
        commit;
    end if;
end &&
DELIMITER ;
-- 3) Hãy tạo một Stored Procedure có tên sp_cancel_order để xử lý việc hủy đơn hàng với transaction
DELIMITER &&
create procedure sp_pay_order(
    in order_id int,
    in payment_method varchar(20)
)
begin
    declare order_status enum('Pending', 'Completed', 'Cancelled');
    declare total_amount decimal(10,2);
   START TRANSACTION;
    select status, total_amount into order_status, total_amount
    from orders
    where order_id = order_id;
    if order_status != 'Pending' then
        rollback;
        signal sqlstate '45000' set message_text = 'chỉ có thể thanh toán đơn hàng ở trạng thái pending!';
    else
        insert into payments (order_id, payment_date, amount, payment_method, status)
        values (order_id, now(), total_amount, payment_method, 'Completed');
        update orders
        set status = 'Completed'
        where order_id = order_id;
        commit;
    end if;
end &&
DELIMITER ;
-- 4) Hãy tạo một Stored Procedure có tên sp_cancel_order để xử lý việc hủy đơn hàng với transaction. 
DELIMITER &&
create procedure sp_cancel_order(
    in order_id int
)
begin
    declare order_status enum('Pending', 'Completed', 'Cancelled');
    START TRANSACTION;
    select status into order_status
    from orders
    where order_id = order_id;
    if order_status != 'Pending' then
        rollback;
        signal sqlstate '45000' set message_text = 'chỉ có thể hủy đơn hàng ở trạng thái pending!';
    else
        update inventory i
        join order_items oi on i.product_id = oi.product_id
        set i.stock_quantity = i.stock_quantity + oi.quantity
        where oi.order_id = order_id;
        delete from order_items where order_id = order_id;
        update orders
        set status = 'Cancelled'
        where order_id = order_id;
        commit;
    end if;
end &&
DELIMITER ;
-- 6) Xóa tất cả các transaction trên 
drop procedure if exists sp_create_order;
drop procedure if exists sp_pay_order;
drop procedure if exists sp_cancel_order;