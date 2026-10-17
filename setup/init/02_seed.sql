-- =============================================================
-- Dữ liệu mẫu cho DSC Shop. Chạy ngay sau 01_schema.sql
-- (id được sinh theo thứ tự INSERT nên cần schema mới tạo).
--
-- Dữ liệu cố ý có "vấn đề" để luyện tập:
--   - NULL: khách không có email/phone/city/birth_date, sản phẩm chưa có cost_price
--   - city viết không thống nhất: 'TP. Hồ Chí Minh', 'Hồ Chí Minh', 'TP.HCM', 'đà nẵng'
--   - hai khách trùng tên 'Nguyễn Văn An'
--   - khách chưa từng mua, sản phẩm chưa từng bán, danh mục chưa có sản phẩm
--   - unit_price của vài đơn cũ khác price hiện tại (giá đã thay đổi)
-- =============================================================

SET search_path = shop, public;

INSERT INTO categories (name, parent_id) VALUES
    ('Máy tính',            NULL),  -- 1
    ('Laptop',              1),     -- 2
    ('Laptop gaming',       2),     -- 3
    ('Laptop văn phòng',    2),     -- 4
    ('PC & Màn hình',       1),     -- 5
    ('Điện thoại & Tablet', NULL),  -- 6
    ('Điện thoại',          6),     -- 7
    ('Máy tính bảng',       6),     -- 8
    ('Phụ kiện',            NULL),  -- 9
    ('Chuột & Bàn phím',    9),     -- 10
    ('Tai nghe & Loa',      9),     -- 11
    ('Sạc & Cáp',           9),     -- 12
    ('Thiết bị mạng',       NULL);  -- 13 (chưa có sản phẩm)

INSERT INTO products (sku, name, category_id, price, cost_price, stock_quantity, attributes, is_active, created_at) VALUES
    ('LAP-001', 'ASUS ROG Strix G16',           3, 32990000, 28500000,  5, '{"brand": "ASUS", "cpu": "Intel Core i7-13650HX", "ram_gb": 16, "storage_gb": 512, "gpu": "RTX 4060"}', TRUE, '2024-11-01'),
    ('LAP-002', 'Lenovo Legion 5',              3, 29990000, 26000000,  3, '{"brand": "Lenovo", "cpu": "AMD Ryzen 7 7840HS", "ram_gb": 16, "storage_gb": 1024, "gpu": "RTX 4060"}', TRUE, '2024-11-01'),
    ('LAP-003', 'Acer Nitro V 15',              3, 21990000, 19000000,  0, '{"brand": "Acer", "cpu": "Intel Core i5-13420H", "ram_gb": 8, "storage_gb": 512, "gpu": "RTX 3050"}', TRUE, '2024-11-15'),
    ('LAP-004', 'Dell Inspiron 14',             4, 18490000, 16000000,  8, '{"brand": "Dell", "cpu": "Intel Core i5-1335U", "ram_gb": 8, "storage_gb": 512}', TRUE, '2024-11-15'),
    ('LAP-005', 'MacBook Air M2 13 inch',       4, 24990000, 22000000,  6, '{"brand": "Apple", "cpu": "Apple M2", "ram_gb": 8, "storage_gb": 256}', TRUE, '2024-12-01'),
    ('LAP-006', 'HP Pavilion 15',               4, 16990000,     NULL,  4, '{"brand": "HP", "cpu": "AMD Ryzen 5 7530U", "ram_gb": 16, "storage_gb": 512}', TRUE, '2025-06-01'),
    ('PC-001',  'Màn hình LG UltraGear 27 inch', 5, 6490000,  5200000, 12, '{"brand": "LG", "size_inch": 27, "refresh_hz": 165}', TRUE, '2024-11-01'),
    ('PC-002',  'Màn hình Dell P2422H',         5,  4290000,  3500000, 10, '{"brand": "Dell", "size_inch": 24, "refresh_hz": 60}', TRUE, '2024-11-01'),
    ('PC-003',  'PC văn phòng DSC Basic',       5,  9990000,  8000000,  2, NULL, TRUE, '2025-03-01'),
    ('PHN-001', 'iPhone 15 128GB',              7, 19990000, 17500000, 15, '{"brand": "Apple", "storage_gb": 128, "colors": ["Đen", "Hồng", "Xanh"]}', TRUE, '2024-11-01'),
    ('PHN-002', 'Samsung Galaxy S24',           7, 18990000, 16000000,  9, '{"brand": "Samsung", "storage_gb": 256, "colors": ["Đen", "Tím"]}', TRUE, '2025-02-01'),
    ('PHN-003', 'Xiaomi Redmi Note 13',         7,  4890000,  4000000, 25, '{"brand": "Xiaomi", "storage_gb": 128, "colors": ["Đen", "Xanh", "Vàng"]}', TRUE, '2024-11-01'),
    ('PHN-004', 'Nokia 105 4G',                 7,   690000,   500000,  0, '{"brand": "Nokia", "storage_gb": 0}', FALSE, '2024-11-01'),
    ('TAB-001', 'iPad Air M2 11 inch',          8, 16990000, 15000000,  5, '{"brand": "Apple", "storage_gb": 128}', TRUE, '2025-01-15'),
    ('TAB-002', 'Samsung Galaxy Tab S9 FE',     8,  9490000,  8200000,  7, '{"brand": "Samsung", "storage_gb": 128}', TRUE, '2025-01-15'),
    ('ACC-001', 'Chuột Logitech G102',         10,   399000,   250000, 60, '{"brand": "Logitech", "wireless": false}', TRUE, '2024-11-01'),
    ('ACC-002', 'Chuột Logitech MX Master 3S', 10,  2490000,  2000000, 20, '{"brand": "Logitech", "wireless": true}', TRUE, '2024-11-01'),
    ('ACC-003', 'Bàn phím cơ Keychron K2',     10,  1890000,  1500000, 15, '{"brand": "Keychron", "wireless": true, "switch": "Brown"}', TRUE, '2024-11-01'),
    ('ACC-004', 'Tai nghe Sony WH-1000XM5',    11,  7990000,  6800000,  8, '{"brand": "Sony", "wireless": true}', TRUE, '2024-11-01'),
    ('ACC-005', 'Tai nghe AirPods Pro 2',      11,  5990000,  5100000, 12, '{"brand": "Apple", "wireless": true}', TRUE, '2024-11-01'),
    ('ACC-006', 'Loa JBL Flip 6',              11,  2690000,  2200000,  0, '{"brand": "JBL", "wireless": true}', TRUE, '2024-12-01'),
    ('ACC-007', 'Sạc Anker 65W',               12,   890000,   600000, 40, '{"brand": "Anker", "watt": 65}', TRUE, '2024-11-01'),
    ('ACC-008', 'Cáp USB-C to USB-C 1m',       12,   150000,    60000, 200, NULL, TRUE, '2024-11-01'),
    ('ACC-009', 'Lót chuột DSC XXL',           10,   250000,     NULL, 30, NULL, TRUE, '2026-09-01');  -- chưa bán được cái nào

INSERT INTO customers (full_name, email, phone, city, birth_date, created_at) VALUES
    ('Nguyễn Văn An',    'an.nguyen@gmail.com',              '0901234567', 'TP. Hồ Chí Minh', '2002-03-15', '2025-01-05'),  -- 1
    ('Trần Thị Bình',    'binh.tran@gmail.com',              '0912345678', 'Hà Nội',          '2001-07-22', '2025-01-10'),  -- 2
    ('Lê Hoàng Cường',   'cuong.le@outlook.com',             NULL,         'Đà Nẵng',         '1999-11-02', '2025-01-28'),  -- 3
    ('Phạm Minh Duy',    'duy.pham@gmail.com',               '0987654321', 'TP. Hồ Chí Minh', '2003-01-30', '2025-02-20'),  -- 4
    ('Hoàng Thị Em',     NULL,                               '0934567890', 'Cần Thơ',         NULL,         '2025-03-18'),  -- 5
    ('Võ Quốc Phong',    'phong.vo@student.hcmute.edu.vn',   '0976543210', 'Hồ Chí Minh',     '2004-05-12', '2025-04-01'),  -- 6
    ('Đặng Thu Giang',   'giang.dang@gmail.com',             NULL,         'Hà Nội',          '2000-09-09', '2025-05-02'),  -- 7
    ('Bùi Văn Hùng',     'hung.bui@yahoo.com',               '0909876543', 'đà nẵng',         '1985-04-18', '2025-05-25'),  -- 8
    ('Ngô Thị Lan',      'lan.ngo@gmail.com',                '0911222333', 'Hải Phòng',       '1995-12-25', '2025-06-10'),  -- 9
    ('Dương Minh Khoa',  'khoa.duong@student.hcmute.edu.vn', '0922333444', 'TP. Hồ Chí Minh', '2005-02-14', '2025-06-28'),  -- 10
    ('Lý Thanh Mai',     'mai.ly@gmail.com',                 '0933444555', NULL,              '1998-06-01', '2025-07-15'),  -- 11
    ('Trịnh Công Nam',   'nam.trinh@gmail.com',              '0944555666', 'Biên Hòa',        '1990-10-10', '2025-08-01'),  -- 12
    ('Phan Thị Oanh',    'oanh.phan@hotmail.com',            NULL,         'Hà Nội',          NULL,         '2025-08-30'),  -- 13
    ('Huỳnh Tấn Phát',   'phat.huynh@student.hcmute.edu.vn', '0955666777', 'TP.HCM',          '2004-08-20', '2025-09-04'),  -- 14
    ('Nguyễn Văn An',    'an.nguyenvan@gmail.com',           '0966777888', 'Hà Nội',          '1997-03-03', '2025-10-10'),  -- 15 trùng tên khách 1
    ('Tạ Quang Sơn',     'son.ta@gmail.com',                 '0977888999', 'Cần Thơ',         '2002-12-12', '2025-11-20'),  -- 16 chưa mua
    ('Châu Ngọc Trâm',   NULL,                               NULL,         NULL,              NULL,         '2026-01-15'),  -- 17 chưa mua
    ('Mai Đức Uy',       'uy.mai@gmail.com',                 '0988999000', 'Đà Nẵng',         '2001-04-04', '2025-11-24');  -- 18

INSERT INTO employees (full_name, title, manager_id, hire_date, salary) VALUES
    ('Nguyễn Thành Long', 'Giám đốc',                NULL, '2020-01-15', 45000000),  -- 1
    ('Lê Thị Hạnh',       'Trưởng phòng Kinh doanh', 1,    '2021-03-01', 28000000),  -- 2
    ('Trần Quốc Bảo',     'Trưởng phòng Kỹ thuật',   1,    '2021-06-15', 27000000),  -- 3
    ('Phạm Thị Thu',      'Nhân viên bán hàng',      2,    '2022-02-10', 12000000),  -- 4
    ('Đỗ Minh Tuấn',      'Nhân viên bán hàng',      2,    '2023-07-01', 11000000),  -- 5
    ('Vũ Hoài Nam',       'Nhân viên bán hàng',      2,    '2024-09-01', 10000000),  -- 6
    ('Lâm Gia Huy',       'Kỹ thuật viên',           3,    '2022-11-20', 13000000),  -- 7
    ('Kiều Anh Thư',      'Thực tập sinh bán hàng',  4,    '2026-06-01',  5000000);  -- 8

-- Đơn offline có employee_id (người bán), đơn online thì không
INSERT INTO orders (customer_id, employee_id, order_date, status, channel, shipping_city, note) VALUES
    ( 1, NULL, '2025-01-12 10:15+07', 'delivered', 'online',  'TP. Hồ Chí Minh', NULL),                        -- 1
    ( 2, 4,    '2025-01-20 14:30+07', 'delivered', 'offline', NULL,              NULL),                        -- 2
    ( 3, NULL, '2025-02-03 09:00+07', 'delivered', 'online',  'Đà Nẵng',         NULL),                        -- 3
    ( 1, 5,    '2025-02-14 19:45+07', 'delivered', 'offline', NULL,              'Quà Valentine, gói giấy đỏ'), -- 4
    ( 4, NULL, '2025-03-02 21:10+07', 'cancelled', 'online',  'TP. Hồ Chí Minh', 'Khách đổi ý'),               -- 5
    ( 5, 4,    '2025-03-18 11:20+07', 'delivered', 'offline', NULL,              NULL),                        -- 6
    ( 6, NULL, '2025-04-05 08:30+07', 'delivered', 'online',  'TP. Hồ Chí Minh', NULL),                        -- 7
    ( 2, NULL, '2025-04-22 16:00+07', 'delivered', 'online',  'Hà Nội',          NULL),                        -- 8
    ( 7, 5,    '2025-05-10 10:00+07', 'delivered', 'offline', NULL,              NULL),                        -- 9
    ( 8, NULL, '2025-05-28 13:15+07', 'delivered', 'online',  'Đà Nẵng',         NULL),                        -- 10
    ( 9, 6,    '2025-06-15 15:40+07', 'delivered', 'offline', NULL,              NULL),                        -- 11
    (10, NULL, '2025-06-30 22:05+07', 'delivered', 'online',  'TP. Hồ Chí Minh', 'Trả góp 2 lần'),             -- 12
    ( 1, NULL, '2025-07-08 09:50+07', 'delivered', 'online',  'TP. Hồ Chí Minh', NULL),                        -- 13
    (11, 4,    '2025-07-19 17:30+07', 'delivered', 'offline', NULL,              NULL),                        -- 14
    (12, NULL, '2025-08-02 20:00+07', 'cancelled', 'online',  'Biên Hòa',        'Hết hàng'),                  -- 15
    ( 4, 5,    '2025-08-16 10:10+07', 'delivered', 'offline', NULL,              NULL),                        -- 16
    (13, NULL, '2025-09-01 12:00+07', 'delivered', 'online',  'Hà Nội',          NULL),                        -- 17
    (14, NULL, '2025-09-05 08:00+07', 'delivered', 'online',  'TP. Hồ Chí Minh', 'Mua đầu năm học'),           -- 18
    ( 6, 6,    '2025-09-06 18:20+07', 'delivered', 'offline', NULL,              NULL),                        -- 19
    (15, NULL, '2025-10-11 11:11+07', 'delivered', 'online',  'Hà Nội',          NULL),                        -- 20
    ( 3, 4,    '2025-11-11 19:00+07', 'delivered', 'offline', NULL,              NULL),                        -- 21
    ( 2, NULL, '2025-11-11 23:30+07', 'delivered', 'online',  'Hà Nội',          'Săn sale 11/11'),            -- 22
    (18, NULL, '2025-11-25 14:45+07', 'delivered', 'online',  'Đà Nẵng',         NULL),                        -- 23
    ( 9, NULL, '2025-12-12 20:20+07', 'delivered', 'online',  'Hải Phòng',       NULL),                        -- 24
    ( 1, 5,    '2025-12-24 16:00+07', 'delivered', 'offline', NULL,              'Quà Giáng sinh'),            -- 25
    ( 7, NULL, '2026-01-08 09:30+07', 'delivered', 'online',  'Hà Nội',          NULL),                        -- 26
    (10, 6,    '2026-01-20 15:00+07', 'delivered', 'offline', NULL,              NULL),                        -- 27
    ( 5, NULL, '2026-02-02 10:45+07', 'cancelled', 'online',  'Cần Thơ',         NULL),                        -- 28
    ( 8, 4,    '2026-02-25 13:30+07', 'delivered', 'offline', NULL,              NULL),                        -- 29
    (11, NULL, '2026-03-15 21:00+07', 'delivered', 'online',  'TP. Hồ Chí Minh', NULL),                        -- 30
    ( 4, NULL, '2026-04-01 08:15+07', 'delivered', 'online',  'TP. Hồ Chí Minh', NULL),                        -- 31
    (12, 5,    '2026-04-30 10:00+07', 'delivered', 'offline', NULL,              NULL),                        -- 32
    (14, NULL, '2026-05-20 19:30+07', 'delivered', 'online',  'TP. Hồ Chí Minh', NULL),                        -- 33
    ( 2, 8,    '2026-06-15 14:00+07', 'delivered', 'offline', NULL,              NULL),                        -- 34
    ( 6, NULL, '2026-07-07 07:07+07', 'delivered', 'online',  'TP. Hồ Chí Minh', NULL),                        -- 35
    (18, 6,    '2026-08-08 18:00+07', 'delivered', 'offline', NULL,              NULL),                        -- 36
    ( 1, NULL, '2026-09-02 10:00+07', 'shipped',   'online',  'TP. Hồ Chí Minh', NULL),                        -- 37
    (13, NULL, '2026-09-20 16:30+07', 'paid',      'online',  'Hà Nội',          NULL),                        -- 38
    (15, NULL, '2026-10-05 09:00+07', 'paid',      'online',  'Hà Nội',          NULL),                        -- 39
    ( 3, NULL, '2026-10-14 22:00+07', 'pending',   'online',  'Đà Nẵng',         NULL);                        -- 40

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount) VALUES
    ( 1, 16, 1,   399000, 0),    ( 1, 23, 2,   150000, 0),
    ( 2,  5, 1, 26990000, 0),                                  -- giá MacBook lúc đó cao hơn hiện tại
    ( 3, 12, 1,  4890000, 0),    ( 3, 22, 1,   890000, 0),
    ( 4, 20, 1,  5990000, 0.10), ( 4, 17, 1,  2490000, 0),
    ( 5,  1, 1, 32990000, 0),
    ( 6, 13, 2,   690000, 0),
    ( 7,  3, 1, 22990000, 0.05), ( 7, 16, 1,   399000, 0),
    ( 8, 10, 1, 19990000, 0),    ( 8, 23, 1,   150000, 0),
    ( 9,  8, 2,  4290000, 0),
    (10, 19, 1,  7990000, 0),
    (11,  4, 1, 18490000, 0),    (11, 16, 1,   399000, 0),
    (12,  2, 1, 29990000, 0),    (12, 18, 1,  1890000, 0),
    (13, 22, 2,   890000, 0),    (13, 23, 3,   150000, 0),
    (14, 15, 1,  9490000, 0),
    (15, 21, 1,  2690000, 0),
    (16,  7, 1,  6490000, 0),    (16, 17, 1,  2490000, 0),
    (17, 14, 1, 16990000, 0),
    (18,  5, 1, 24990000, 0.05), (18, 23, 1,   150000, 0),
    (19, 18, 1,  1890000, 0),    (19, 16, 2,   399000, 0),
    (20, 11, 1, 18990000, 0),
    (21,  9, 1,  9990000, 0),    (21,  8, 1,  4290000, 0),
    (22, 20, 1,  5990000, 0.15), (22, 12, 1,  4890000, 0.10),
    (23,  6, 1, 16990000, 0),
    (24, 10, 1, 19990000, 0.05), (24, 20, 1,  5990000, 0.05),
    (25, 19, 1,  7990000, 0),    (25, 14, 1, 16990000, 0),
    (26, 21, 1,  2690000, 0),
    (27,  1, 1, 32990000, 0.05),
    (28, 17, 1,  2490000, 0),
    (29, 12, 2,  4890000, 0),    (29, 22, 2,   890000, 0),
    (30,  4, 1, 18490000, 0),
    (31, 18, 1,  1890000, 0),    (31, 17, 1,  2490000, 0),    (31, 16, 1,   399000, 0),
    (32,  7, 2,  6490000, 0),
    (33,  3, 1, 21990000, 0),
    (34, 23, 5,   150000, 0),    (34, 22, 1,   890000, 0),
    (35, 11, 1, 18990000, 0.10),
    (36,  2, 1, 29990000, 0),
    (37, 15, 1,  9490000, 0),    (37, 23, 1,   150000, 0),
    (38, 19, 1,  7990000, 0),
    (39, 10, 2, 19990000, 0),
    (40, 12, 1,  4890000, 0);

-- Đơn đã thanh toán (mọi trạng thái trừ pending/cancelled) có một payment bằng tổng tiền đơn,
-- riêng đơn 12 trả góp 2 lần
INSERT INTO payments (order_id, amount, method, paid_at)
SELECT o.order_id,
       SUM(oi.quantity * oi.unit_price * (1 - oi.discount)),
       CASE
           WHEN o.channel = 'offline' AND o.order_id % 2 = 0 THEN 'cash'
           WHEN o.channel = 'offline' THEN 'card'
           WHEN o.order_id % 3 = 0 THEN 'bank_transfer'
           ELSE 'momo'
       END,
       o.order_date + INTERVAL '5 minutes'
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.status NOT IN ('pending', 'cancelled')
  AND o.order_id <> 12
GROUP BY o.order_id
ORDER BY o.order_id;

INSERT INTO payments (order_id, amount, method, paid_at) VALUES
    (12, 15000000, 'bank_transfer', '2025-06-30 22:10+07'),
    (12, 16880000, 'bank_transfer', '2025-07-30 09:00+07');
