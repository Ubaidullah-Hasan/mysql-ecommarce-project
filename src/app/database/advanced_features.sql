-- VIEWS - ভিউ তৈরি করা

-- Product Summary View - প্রোডাক্ট সামারি ভিউ
DROP VIEW IF EXISTS product_summary;


CREATE VIEW product_summary AS
SELECT 
    p.id,
    p.name,
    p.price,
    p.stock_quantity,
    c.name as category_name,
    COALESCE(AVG(r.rating), 0) as average_rating,
    COUNT(r.id) as review_count
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN reviews r ON p.id = r.product_id
GROUP BY p.id, p.name, p.price, p.stock_quantity, c.name;

-- User Order Summary View - ইউজার অর্ডার সামারি ভিউ
DROP VIEW IF EXISTS user_order_summary;


CREATE VIEW user_order_summary AS
SELECT 
    u.id as user_id,
    u.name,
    u.email,
    COUNT(o.id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent,
    MAX(o.created_at) as last_order_date
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.role = 'customer'
GROUP BY u.id, u.name, u.email;

-- Sales Report View - সেলস রিপোর্ট ভিউ  
DROP VIEW IF EXISTS monthly_sales_report;

CREATE VIEW monthly_sales_report AS
SELECT 
    YEAR(o.created_at) as year,
    MONTH(o.created_at) as month,
    COUNT(o.id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as average_order_value
FROM orders o
WHERE o.status != 'cancelled'
GROUP BY YEAR(o.created_at), MONTH(o.created_at)
ORDER BY year DESC, month DESC;

-- Add more complex views that demonstrate relationships

-- Complex Product View with all relationships
DROP VIEW IF EXISTS product_complete_info;

CREATE VIEW product_complete_info AS
SELECT 
    p.id,
    p.name,
    p.description,
    p.price,
    p.stock_quantity,
    p.sku,
    c.name as category_name,
    c.description as category_description,
    b.name as brand_name,
    b.website as brand_website,
    COALESCE(AVG(r.rating), 0) as average_rating,
    COUNT(DISTINCT r.id) as review_count,
    COUNT(DISTINCT pt.tag_id) as tag_count,
    COUNT(DISTINCT ps.supplier_id) as supplier_count,
    GROUP_CONCAT(DISTINCT t.name) as tags,
    GROUP_CONCAT(DISTINCT s.name) as suppliers
FROM products p
LEFT JOIN categories c ON p.category_id = c.id
LEFT JOIN brands b ON p.brand_id = b.id
LEFT JOIN reviews r ON p.id = r.product_id
LEFT JOIN product_tags pt ON p.id = pt.product_id
LEFT JOIN tags t ON pt.tag_id = t.id
LEFT JOIN product_suppliers ps ON p.id = ps.product_id
LEFT JOIN suppliers s ON ps.supplier_id = s.id
GROUP BY p.id, p.name, p.description, p.price, p.stock_quantity, p.sku, 
         c.name, c.description, b.name, b.website;

-- User Complete Profile View (ONE-TO-ONE and ONE-TO-MANY)
DROP VIEW IF EXISTS user_complete_profile;

CREATE VIEW user_complete_profile AS
SELECT 
    u.id,
    u.name,
    u.email,
    u.role,
    u.phone,
    up.date_of_birth,
    up.gender,
    up.profile_picture,
    up.bio,
    COUNT(DISTINCT a.id) as address_count,
    COUNT(DISTINCT o.id) as order_count,
    COUNT(DISTINCT w.id) as wishlist_count,
    COALESCE(SUM(o.final_amount), 0) as total_spent
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN addresses a ON u.id = a.user_id
LEFT JOIN orders o ON u.id = o.user_id AND o.status != 'cancelled'
LEFT JOIN wishlists w ON u.id = w.user_id
GROUP BY u.id, u.name, u.email, u.role, u.phone, 
         up.date_of_birth, up.gender, up.profile_picture, up.bio;

-- STORED PROCEDURES - স্টোরড প্রসিডিউর

-- Place Order Procedure - অর্ডার প্লেস করার প্রসিডিউর
DROP PROCEDURE IF EXISTS PlaceOrder;

CREATE PROCEDURE PlaceOrder(
    IN p_user_id INT,
    IN p_shipping_address TEXT
)
BEGIN
    DECLARE v_total_amount DECIMAL(10,2) DEFAULT 0;
    DECLARE v_order_id INT;
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_product_id INT;
    DECLARE v_quantity INT;
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_stock INT;

    DECLARE cart_cursor CURSOR FOR 
        SELECT c.product_id, c.quantity, p.price, p.stock_quantity
        FROM cart c
        JOIN products p ON c.product_id = p.id
        WHERE c.user_id = p_user_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    START TRANSACTION;

    SELECT SUM(c.quantity * p.price) INTO v_total_amount
    FROM cart c
    JOIN products p ON c.product_id = p.id
    WHERE c.user_id = p_user_id;

    IF v_total_amount IS NULL OR v_total_amount = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cart is empty';
    END IF;

    INSERT INTO orders (user_id, total_amount, shipping_address)
    VALUES (p_user_id, v_total_amount, p_shipping_address);

    SET v_order_id = LAST_INSERT_ID();

    OPEN cart_cursor;
    read_loop: LOOP
        FETCH cart_cursor INTO v_product_id, v_quantity, v_price, v_stock;
        IF done THEN
            LEAVE read_loop;
        END IF;

        IF v_stock < v_quantity THEN
            ROLLBACK;
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock';
        END IF;

        INSERT INTO order_items (order_id, product_id, quantity, price)
        VALUES (v_order_id, v_product_id, v_quantity, v_price);

        UPDATE products 
        SET stock_quantity = stock_quantity - v_quantity
        WHERE id = v_product_id;
    END LOOP;
    CLOSE cart_cursor;

    DELETE FROM cart WHERE user_id = p_user_id;

    COMMIT;

    SELECT v_order_id as order_id, v_total_amount as total_amount;
END;


-- Get Top Selling Products Procedure - টপ সেলিং প্রোডাক্ট প্রসিডিউর
DROP PROCEDURE IF EXISTS GetTopSellingProducts;

CREATE PROCEDURE GetTopSellingProducts(IN p_limit INT)
BEGIN
    SELECT 
        p.id,
        p.name,
        p.price,
        SUM(oi.quantity) as total_sold,
        SUM(oi.quantity * oi.unit_price) as total_revenue
    FROM products p
    JOIN order_items oi ON p.id = oi.product_id
    JOIN orders o ON oi.order_id = o.id
    WHERE o.status != 'cancelled'
    GROUP BY p.id, p.name, p.price
    ORDER BY total_sold DESC
    LIMIT p_limit;
END;




/*






-- Add more complex stored procedures

-- Procedure to get product with all relationships
DELIMITER //
CREATE PROCEDURE GetProductCompleteInfo(IN p_product_id INT)
BEGIN
    -- Get basic product info
    SELECT * FROM product_complete_info WHERE id = p_product_id;
    
    -- Get product attributes
    SELECT attribute_name, attribute_value 
    FROM product_attributes 
    WHERE product_id = p_product_id;
    
    -- Get product suppliers with details
    SELECT s.name, s.contact_person, s.email, s.phone,
           ps.supply_price, ps.minimum_order_quantity, ps.lead_time_days
    FROM product_suppliers ps
    JOIN suppliers s ON ps.supplier_id = s.id
    WHERE ps.product_id = p_product_id;
    
    -- Get recent reviews
    SELECT r.rating, r.title, r.comment, r.created_at,
           u.name as reviewer_name
    FROM reviews r
    JOIN users u ON r.user_id = u.id
    WHERE r.product_id = p_product_id
    ORDER BY r.created_at DESC
    LIMIT 5;
END //
DELIMITER ;

-- Procedure to demonstrate MANY-TO-MANY operations
DELIMITER //
CREATE PROCEDURE ManageProductTags(
    IN p_product_id INT,
    IN p_tag_names TEXT, -- Comma separated tag names
    IN p_operation ENUM('add', 'remove', 'replace')
)
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE tag_name VARCHAR(50);
    DECLARE tag_id INT;
    DECLARE tag_cursor CURSOR FOR 
        SELECT TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(p_tag_names, ',', numbers.n), ',', -1)) as tag_name
        FROM (SELECT 1 n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5) numbers
        WHERE CHAR_LENGTH(p_tag_names) - CHAR_LENGTH(REPLACE(p_tag_names, ',', '')) >= numbers.n - 1;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    START TRANSACTION;
    
    -- If replace, remove all existing tags first
    IF p_operation = 'replace' THEN
        DELETE FROM product_tags WHERE product_id = p_product_id;
    END IF;
    
    -- Process each tag
    OPEN tag_cursor;
    read_loop: LOOP
        FETCH tag_cursor INTO tag_name;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Get or create tag
        SELECT id INTO tag_id FROM tags WHERE name = tag_name LIMIT 1;
        
        IF tag_id IS NULL THEN
            INSERT INTO tags (name) VALUES (tag_name);
            SET tag_id = LAST_INSERT_ID();
        END IF;
        
        -- Add or remove tag
        IF p_operation IN ('add', 'replace') THEN
            INSERT IGNORE INTO product_tags (product_id, tag_id) VALUES (p_product_id, tag_id);
        ELSEIF p_operation = 'remove' THEN
            DELETE FROM product_tags WHERE product_id = p_product_id AND tag_id = tag_id;
        END IF;
        
    END LOOP;
    CLOSE tag_cursor;
    
    COMMIT;
    
    -- Return updated product tags
    SELECT t.name 
    FROM product_tags pt
    JOIN tags t ON pt.tag_id = t.id
    WHERE pt.product_id = p_product_id;
END //
DELIMITER ;

-- TRIGGERS - ট্রিগার

-- Audit trigger for products table - প্রোডাক্ট টেবিলের জন্য অডিট ট্রিগার
DELIMITER //
CREATE TRIGGER products_audit_insert
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (table_name, operation, record_id, new_values)
    VALUES ('products', 'INSERT', NEW.id, JSON_OBJECT(
        'name', NEW.name,
        'price', NEW.price,
        'stock_quantity', NEW.stock_quantity
    ));
END //

CREATE TRIGGER products_audit_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (table_name, operation, record_id, old_values, new_values)
    VALUES ('products', 'UPDATE', NEW.id, 
        JSON_OBJECT(
            'name', OLD.name,
            'price', OLD.price,
            'stock_quantity', OLD.stock_quantity
        ),
        JSON_OBJECT(
            'name', NEW.name,
            'price', NEW.price,
            'stock_quantity', NEW.stock_quantity
        )
    );
END //

CREATE TRIGGER products_audit_delete
AFTER DELETE ON products
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (table_name, operation, record_id, old_values)
    VALUES ('products', 'DELETE', OLD.id, JSON_OBJECT(
        'name', OLD.name,
        'price', OLD.price,
        'stock_quantity', OLD.stock_quantity
    ));
END //
DELIMITER ;

-- Stock alert trigger - স্টক এলার্ট ট্রিগার
DELIMITER //
CREATE TRIGGER stock_alert_trigger
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF NEW.stock_quantity < 10 AND OLD.stock_quantity >= 10 THEN
        INSERT INTO audit_logs (table_name, operation, record_id, new_values)
        VALUES ('products', 'LOW_STOCK_ALERT', NEW.id, JSON_OBJECT(
            'product_name', NEW.name,
            'current_stock', NEW.stock_quantity,
            'alert_message', 'Stock is running low'
        ));
    END IF;
END //
DELIMITER ;

-- Add more triggers for relationship management

-- Trigger to update coupon usage count
DELIMITER //
CREATE TRIGGER update_coupon_usage
AFTER INSERT ON user_coupons
FOR EACH ROW
BEGIN
    IF NEW.used_at IS NOT NULL THEN
        UPDATE coupons 
        SET current_usage_count = current_usage_count + 1
        WHERE id = NEW.coupon_id;
    END IF;
END //
DELIMITER ;

-- Trigger to create order status history
DELIMITER //
CREATE TRIGGER order_status_history_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO order_status_history (order_id, new_status, notes)
    VALUES (NEW.id, NEW.status, 'Order created');
END //

CREATE TRIGGER order_status_history_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO order_status_history (order_id, old_status, new_status, notes)
        VALUES (NEW.id, OLD.status, NEW.status, 'Status updated');
    END IF;
END //
DELIMITER ;

-- Trigger to maintain wishlist count in user profiles
DELIMITER //
CREATE TRIGGER update_wishlist_count
AFTER INSERT ON wishlists
FOR EACH ROW
BEGIN
    -- This is just for demonstration - in real app you might cache this
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (NEW.user_id, 'Wishlist Updated', 'Product added to your wishlist', 'product');
END //
DELIMITER ;




*/