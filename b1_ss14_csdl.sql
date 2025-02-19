CREATE DATABASE ss14_first;
USE ss14_first;
-- 1. Bảng customers (Khách hàng)
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Bảng orders (Đơn hàng)
CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10,2) DEFAULT 0,
    status ENUM('Pending', 'Completed', 'Cancelled') DEFAULT 'Pending',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

-- 3. Bảng products (Sản phẩm)
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Bảng order_items (Chi tiết đơn hàng)
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- 5. Bảng inventory (Kho hàng)
CREATE TABLE inventory (
    product_id INT PRIMARY KEY,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE CASCADE
);

-- 6. Bảng payments (Thanh toán)
CREATE TABLE payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(10,2) NOT NULL,
    payment_method ENUM('Credit Card', 'PayPal', 'Bank Transfer', 'Cash') NOT NULL,
    status ENUM('Pending', 'Completed', 'Failed') DEFAULT 'Pending',
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- 2) Hãy tạo một trigger BEFORE INSERT để kiểm tra đơn hàng trước khi thêm vào order_items
DELIMITER &&
create trigger before_insert_order_items
before insert on order_items
for each row
begin
    declare stock_qty int;
    select stock_quantity into stock_qty
    from inventory
    where product_id = new.product_id;
    if stock_qty is null or stock_qty < new.quantity then
        signal sqlstate '45000'
        set message_text = 'Không đủ hàng trong kho!';
    end if;
end &&
DELIMITER ;
-- 3) Hãy tạo một trigger AFTER INSERT để cập nhật tổng tiền của đơn hàng sau khi thêm sản phẩm vào order_items
DELIMITER &&
create trigger after_insert_order_items
after insert on order_items
for each row
begin
    update orders
    set total_amount = total_amount + (new.price * new.quantity)
    where order_id = new.order_id;
end &&
DELIMITER ;
-- 4) Hãy tạo một trigger BEFORE UPDATE để kiểm tra số lượng hàng tồn kho trước khi cập nhật số lượng sản phẩm trong order_items
DELIMITER &&
create trigger before_update_order_items
before update on order_items
for each row
begin
    declare stock_qty int;
    select stock_quantity into stock_qty
    from inventory
    where product_id = new.product_id;
    if stock_qty is null or stock_qty < new.quantity then
        signal sqlstate '45000'
        set message_text = 'Không đủ hàng trong kho để cập nhật số lượng!';
    end if;
end &&
DELIMITER ;
-- 5) Hãy tạo một trigger AFTER UPDATE để cập nhật lại tổng tiền (total_amount) của đơn hàng khi một sản phẩm trong order_items
DELIMITER &&
create trigger after_update_order_items
after update on order_items
for each row
begin
    update orders
    set total_amount = total_amount - (old.price * old.quantity) + (new.price * new.quantity)
    where order_id = new.order_id;
end &&
DELIMITER ;
-- 6) Hãy tạo một trigger BEFORE DELETE để ngăn chặn việc xóa đơn hàng đã được thanh toán trong bảng orders
DELIMITER &&
create trigger before_delete_orders
before delete on orders
for each row
begin
    if old.status = 'Completed' then
        signal sqlstate '45000'
        set message_text = 'Không thể xóa đơn hàng đã thanh toán!';
    end if;
end &&
DELIMITER ;
-- 7) Hãy tạo một trigger AFTER DELETE để hoàn trả số lượng hàng vào kho sau khi xóa một sản phẩm khỏi order_items
DELIMITER &&
create trigger after_delete_order_items
after delete on order_items
for each row
begin
    update inventory
    set stock_quantity = stock_quantity + old.quantity
    where product_id = old.product_id;
end &&
DELIMITER ;
-- 8) Hãy xóa tất cả các trigger đã tạo trên.
drop trigger if exists before_insert_order_items;
drop trigger if exists after_insert_order_items;
drop trigger if exists before_update_order_items;
drop trigger if exists after_update_order_items;
drop trigger if exists before_delete_orders;
drop trigger if exists after_delete_order_items;

