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


DROP TRIGGER IF EXISTS after_cart_delete;

CREATE TRIGGER after_cart_delete
AFTER DELETE ON cart
FOR EACH ROW
BEGIN
    INSERT INTO watchlist (cart_id, user_id, product_id, quantity)
    VALUES (OLD.id, OLD.user_id, OLD.product_id, OLD.quantity);
END;