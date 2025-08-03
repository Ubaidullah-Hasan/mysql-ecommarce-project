

-- Users table - ইউজার টেবিল (Admin এবং Customer)
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'customer') DEFAULT 'customer',
    phone VARCHAR(15),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- User Profiles table - ইউজার প্রোফাইল টেবিল (ONE-TO-ONE with users)
CREATE TABLE IF NOT EXISTS user_profiles (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT UNIQUE NOT NULL, -- ONE-TO-ONE relationship
    date_of_birth DATE,
    gender ENUM('male', 'female', 'other'),
    profile_picture VARCHAR(500),
    bio TEXT,
    social_media JSON, -- Store social media links as JSON
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Categories table - ক্যাটেগরি টেবিল
CREATE TABLE IF NOT EXISTS categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_category_id INT, -- Self-referencing for subcategories
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_category_id) REFERENCES categories(id) ON DELETE SET NULL
);

-- Brands table - ব্র্যান্ড টেবিল
CREATE TABLE IF NOT EXISTS brands (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    logo_url VARCHAR(500),
    website VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Products table - প্রোডাক্ট টেবিল (ONE-TO-MANY with categories and brands)
CREATE TABLE IF NOT EXISTS products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    stock_quantity INT DEFAULT 0,
    category_id INT, -- ONE-TO-MANY: Many products belong to one category
    brand_id INT, -- ONE-TO-MANY: Many products belong to one brand
    image_url VARCHAR(500),
    sku VARCHAR(100) UNIQUE,
    weight DECIMAL(8,2),
    dimensions VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
    FOREIGN KEY (brand_id) REFERENCES brands(id) ON DELETE SET NULL
);

-- Product Attributes table - প্রোডাক্ট অ্যাট্রিবিউট টেবিল (ONE-TO-MANY with products)
CREATE TABLE IF NOT EXISTS product_attributes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL, -- ONE-TO-MANY: One product can have many attributes
    attribute_name VARCHAR(100) NOT NULL, -- e.g., 'Color', 'Size', 'Material'
    attribute_value VARCHAR(200) NOT NULL, -- e.g., 'Red', 'Large', 'Cotton'
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Tags table - ট্যাগ টেবিল (for MANY-TO-MANY with products)
CREATE TABLE IF NOT EXISTS tags (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product Tags junction table - প্রোডাক্ট ট্যাগ জাংশন টেবিল (MANY-TO-MANY)
CREATE TABLE IF NOT EXISTS product_tags (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    tag_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE,
    UNIQUE KEY unique_product_tag (product_id, tag_id) -- Prevent duplicate entries
);

-- Suppliers table - সাপ্লায়ার টেবিল
CREATE TABLE IF NOT EXISTS suppliers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    contact_person VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(15),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product Suppliers junction table - প্রোডাক্ট সাপ্লায়ার জাংশন টেবিল (MANY-TO-MANY)
CREATE TABLE IF NOT EXISTS product_suppliers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT NOT NULL,
    supplier_id INT NOT NULL,
    supply_price DECIMAL(10,2),
    minimum_order_quantity INT DEFAULT 1,
    lead_time_days INT DEFAULT 7,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE CASCADE,
    UNIQUE KEY unique_product_supplier (product_id, supplier_id)
);

-- Addresses table - ঠিকানা টেবিল (ONE-TO-MANY with users)
CREATE TABLE IF NOT EXISTS addresses (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL, -- ONE-TO-MANY: One user can have many addresses
    address_type ENUM('home', 'office', 'other') DEFAULT 'home',
    street_address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'Bangladesh',
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Cart table - কার্ট টেবিল (ONE-TO-MANY with users and products)
CREATE TABLE IF NOT EXISTS cart (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL, -- ONE-TO-MANY: One user can have many cart items
    product_id INT NOT NULL, -- ONE-TO-MANY: One product can be in many carts
    quantity INT DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_product (user_id, product_id)
);

-- Coupons table - কুপন টেবিল
CREATE TABLE IF NOT EXISTS coupons (
    id INT PRIMARY KEY AUTO_INCREMENT,
    code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    discount_type ENUM('percentage', 'fixed') NOT NULL,
    discount_value DECIMAL(10,2) NOT NULL,
    minimum_order_amount DECIMAL(10,2) DEFAULT 0,
    max_usage_count INT DEFAULT NULL,
    current_usage_count INT DEFAULT 0,
    valid_from DATETIME NOT NULL,
    valid_until DATETIME NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Coupons junction table - ইউজার কুপন জাংশন টেবিল (MANY-TO-MANY)
CREATE TABLE IF NOT EXISTS user_coupons (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    coupon_id INT NOT NULL,
    used_at TIMESTAMP NULL,
    order_id INT NULL, -- Reference to which order used this coupon
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_coupon_usage (user_id, coupon_id)
);

-- Orders table - অর্ডার টেবিল (ONE-TO-MANY with users)
CREATE TABLE IF NOT EXISTS orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL, -- ONE-TO-MANY: One user can have many orders
    order_number VARCHAR(50) UNIQUE NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    shipping_amount DECIMAL(10,2) DEFAULT 0,
    final_amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded') DEFAULT 'pending',
    shipping_address_id INT, -- Reference to addresses table
    billing_address_id INT, -- Reference to addresses table
    coupon_id INT NULL, -- Reference to used coupon
    payment_method ENUM('cash_on_delivery', 'card', 'mobile_banking', 'bank_transfer') DEFAULT 'cash_on_delivery',
    payment_status ENUM('pending', 'paid', 'failed', 'refunded') DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    FOREIGN KEY (billing_address_id) REFERENCES addresses(id) ON DELETE SET NULL,
    FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE SET NULL
);

-- Order Items table - অর্ডার আইটেম টেবিল (ONE-TO-MANY with orders and products)
CREATE TABLE IF NOT EXISTS order_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL, -- ONE-TO-MANY: One order can have many items
    product_id INT NOT NULL, -- ONE-TO-MANY: One product can be in many orders
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Order Status History table - অর্ডার স্ট্যাটাস হিস্টরি টেবিল (ONE-TO-MANY with orders)
CREATE TABLE IF NOT EXISTS order_status_history (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL, -- ONE-TO-MANY: One order can have many status changes
    old_status VARCHAR(50),
    new_status VARCHAR(50) NOT NULL,
    changed_by INT, -- Reference to user who changed the status
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (changed_by) REFERENCES users(id) ON DELETE SET NULL
);

-- Reviews table - রিভিউ টেবিল (ONE-TO-MANY with users and products)
CREATE TABLE IF NOT EXISTS reviews (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL, -- ONE-TO-MANY: One user can write many reviews
    product_id INT NOT NULL, -- ONE-TO-MANY: One product can have many reviews
    order_id INT, -- Reference to the order where this product was purchased
    rating INT CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(200),
    comment TEXT,
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
    UNIQUE KEY unique_user_product_order_review (user_id, product_id, order_id)
);

-- Review Images table - রিভিউ ইমেজ টেবিল (ONE-TO-MANY with reviews)
CREATE TABLE IF NOT EXISTS review_images (
    id INT PRIMARY KEY AUTO_INCREMENT,
    review_id INT NOT NULL, -- ONE-TO-MANY: One review can have many images
    image_url VARCHAR(500) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES reviews(id) ON DELETE CASCADE
);

-- Wishlists table - উইশলিস্ট টেবিল (MANY-TO-MANY between users and products)
CREATE TABLE IF NOT EXISTS wishlists (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_product_wishlist (user_id, product_id)
);

-- Notifications table - নোটিফিকেশন টেবিল (ONE-TO-MANY with users)
CREATE TABLE IF NOT EXISTS notifications (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL, -- ONE-TO-MANY: One user can have many notifications
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('order', 'product', 'promotion', 'system') DEFAULT 'system',
    is_read BOOLEAN DEFAULT FALSE,
    related_id INT, -- Can reference order_id, product_id, etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Audit log table - অডিট লগ টেবিল (for triggers)
CREATE TABLE IF NOT EXISTS audit_logs (
    id INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(50),
    operation VARCHAR(10),
    record_id INT,
    old_values JSON,
    new_values JSON,
    user_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

/*
-- Sample Data Insert - নমুনা ডেটা

-- Insert Categories (with parent-child relationship)
INSERT INTO categories (name, description, parent_category_id) VALUES
('Electronics', 'Electronic devices and gadgets', NULL),
('Mobile Phones', 'Smartphones and accessories', 1),
('Laptops', 'Laptops and computers', 1),
('Clothing', 'Fashion and apparel', NULL),
('Men Clothing', 'Clothing for men', 4),
('Women Clothing', 'Clothing for women', 4),
('Books', 'Books and educational materials', NULL),
('Home & Garden', 'Home improvement and gardening', NULL);

-- Insert Brands
INSERT INTO brands (name, description, logo_url, website) VALUES
('Apple', 'Technology company', 'https://example.com/apple-logo.png', 'https://apple.com'),
('Samsung', 'Electronics manufacturer', 'https://example.com/samsung-logo.png', 'https://samsung.com'),
('Nike', 'Sports apparel brand', 'https://example.com/nike-logo.png', 'https://nike.com'),
('Adidas', 'Sports brand', 'https://example.com/adidas-logo.png', 'https://adidas.com');

-- Insert Tags
INSERT INTO tags (name, description) VALUES
('bestseller', 'Best selling products'),
('new-arrival', 'Newly arrived products'),
('sale', 'Products on sale'),
('premium', 'Premium quality products'),
('eco-friendly', 'Environment friendly products'),
('wireless', 'Wireless technology products'),
('waterproof', 'Water resistant products');

-- Insert Suppliers
INSERT INTO suppliers (name, contact_person, email, phone, address) VALUES
('Tech Distributors Ltd', 'John Smith', 'john@techdist.com', '01700000010', 'Dhaka, Bangladesh'),
('Fashion Wholesale Co', 'Jane Doe', 'jane@fashionwhole.com', '01700000011', 'Chittagong, Bangladesh'),
('Book Publishers Inc', 'Mike Johnson', 'mike@bookpub.com', '01700000012', 'Sylhet, Bangladesh');

-- Insert Coupons
INSERT INTO coupons (code, description, discount_type, discount_value, minimum_order_amount, max_usage_count, valid_from, valid_until) VALUES
('WELCOME10', '10% discount for new customers', 'percentage', 10.00, 1000.00, 100, '2024-01-01 00:00:00', '2024-12-31 23:59:59'),
('SAVE500', 'Save 500 taka on orders above 5000', 'fixed', 500.00, 5000.00, 50, '2024-01-01 00:00:00', '2024-12-31 23:59:59'),
('FLASH20', '20% flash sale discount', 'percentage', 20.00, 2000.00, 200, '2024-01-01 00:00:00', '2024-06-30 23:59:59');

-- Insert Users
INSERT INTO users (name, email, password, role, phone, address) VALUES
('Admin User', 'admin@shopeasy.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin', '01700000000', 'Dhaka, Bangladesh'),
('John Doe', 'john@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'customer', '01700000001', 'Chittagong, Bangladesh'),
('Jane Smith', 'jane@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'customer', '01700000002', 'Sylhet, Bangladesh'),
('Alice Johnson', 'alice@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'customer', '01700000003', 'Rajshahi, Bangladesh');

-- Insert User Profiles (ONE-TO-ONE relationship)
INSERT INTO user_profiles (user_id, date_of_birth, gender, profile_picture, bio, social_media) VALUES
(2, '1990-05-15', 'male', 'https://example.com/john-profile.jpg', 'Tech enthusiast and gadget lover', '{"facebook": "john.doe", "twitter": "@johndoe"}'),
(3, '1992-08-22', 'female', 'https://example.com/jane-profile.jpg', 'Fashion blogger and style consultant', '{"instagram": "jane_style", "linkedin": "jane-smith"}'),
(4, '1988-12-10', 'female', 'https://example.com/alice-profile.jpg', 'Book lover and avid reader', '{"goodreads": "alice_reads", "twitter": "@alice_books"}');

-- Insert Addresses (ONE-TO-MANY relationship)
INSERT INTO addresses (user_id, address_type, street_address, city, state, postal_code, is_default) VALUES
(2, 'home', '123 Main Street, Agrabad', 'Chittagong', 'Chittagong Division', '4100', TRUE),
(2, 'office', '456 Business District', 'Chittagong', 'Chittagong Division', '4000', FALSE),
(3, 'home', '789 Fashion Avenue', 'Sylhet', 'Sylhet Division', '3100', TRUE),
(4, 'home', '321 Book Street', 'Rajshahi', 'Rajshahi Division', '6000', TRUE);

-- Insert Products
INSERT INTO products (name, description, price, stock_quantity, category_id, brand_id, image_url, sku, weight, dimensions) VALUES
('iPhone 15 Pro', 'Latest Apple smartphone with advanced features', 120000.00, 50, 2, 1, 'https://example.com/iphone15.jpg', 'APL-IP15-PRO', 0.187, '146.6 x 70.6 x 7.8 mm'),
('Samsung Galaxy S24', 'Android flagship phone with AI features', 95000.00, 30, 2, 2, 'https://example.com/galaxy-s24.jpg', 'SAM-GS24-ULT', 0.196, '147.0 x 70.6 x 7.6 mm'),
('MacBook Pro 14"', 'Professional laptop for creative work', 250000.00, 20, 3, 1, 'https://example.com/macbook.jpg', 'APL-MBP-14', 1.6, '312.6 x 221.2 x 15.5 mm'),
('Nike Air Max', 'Comfortable running shoes', 8500.00, 100, 5, 3, 'https://example.com/nike-shoes.jpg', 'NIK-AM-001', 0.5, '30 x 20 x 12 cm'),
('Adidas T-Shirt', 'Cotton sports t-shirt', 2500.00, 75, 5, 4, 'https://example.com/adidas-tshirt.jpg', 'ADI-TSH-001', 0.2, 'L x W x H'),
('Programming Fundamentals', 'Learn programming from basics', 1500.00, 40, 7, NULL, 'https://example.com/prog-book.jpg', 'BOOK-PROG-001', 0.5, '24 x 18 x 2 cm');

-- Insert Product Attributes (ONE-TO-MANY relationship)
INSERT INTO product_attributes (product_id, attribute_name, attribute_value) VALUES
(1, 'Color', 'Space Black'),
(1, 'Storage', '256GB'),
(1, 'RAM', '8GB'),
(2, 'Color', 'Phantom Black'),
(2, 'Storage', '128GB'),
(2, 'RAM', '12GB'),
(4, 'Size', '42'),
(4, 'Color', 'White/Black'),
(5, 'Size', 'Large'),
(5, 'Color', 'Blue'),
(5, 'Material', 'Cotton');

-- Insert Product Tags (MANY-TO-MANY relationship)
INSERT INTO product_tags (product_id, tag_id) VALUES
(1, 1), (1, 4), (1, 6), -- iPhone: bestseller, premium, wireless
(2, 2), (2, 6), -- Samsung: new-arrival, wireless
(3, 1), (3, 4), -- MacBook: bestseller, premium
(4, 1), (4, 3), -- Nike shoes: bestseller, sale
(5, 2), (5, 5), -- Adidas t-shirt: new-arrival, eco-friendly
(6, 2); -- Book: new-arrival

-- Insert Product Suppliers (MANY-TO-MANY relationship)
INSERT INTO product_suppliers (product_id, supplier_id, supply_price, minimum_order_quantity, lead_time_days) VALUES
(1, 1, 110000.00, 5, 7),
(2, 1, 85000.00, 10, 5),
(3, 1, 230000.00, 2, 10),
(4, 2, 7000.00, 20, 14),
(5, 2, 2000.00, 50, 7),
(6, 3, 1200.00, 100, 3);

-- Insert User Coupons (MANY-TO-MANY relationship)
INSERT INTO user_coupons (user_id, coupon_id) VALUES
(2, 1), -- John has WELCOME10 coupon
(2, 2), -- John has SAVE500 coupon
(3, 1), -- Jane has WELCOME10 coupon
(3, 3), -- Jane has FLASH20 coupon
(4, 1); -- Alice has WELCOME10 coupon

-- Insert some sample cart items
INSERT INTO cart (user_id, product_id, quantity) VALUES
(2, 1, 1), -- John has iPhone in cart
(2, 4, 2), -- John has 2 Nike shoes in cart
(3, 5, 3), -- Jane has 3 Adidas t-shirts in cart
(4, 6, 1); -- Alice has programming book in cart

-- Insert Wishlists (MANY-TO-MANY relationship)
INSERT INTO wishlists (user_id, product_id) VALUES
(2, 3), -- John wishes for MacBook
(3, 1), -- Jane wishes for iPhone
(3, 4), -- Jane wishes for Nike shoes
(4, 2); -- Alice wishes for Samsung phone

*/