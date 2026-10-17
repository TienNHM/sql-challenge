-- =============================================================
-- Dữ liệu lớn cho các bài hiệu năng (Ngày 15, 20, 28): schema perf
-- 100.000 khách, 1.000.000 đơn hàng. Chạy mất khoảng 10-30 giây:
--   docker compose exec -T db psql -U postgres -d sql_challenge < setup/perf_seed.sql
-- Tách riêng schema perf để không làm đổi kết quả của các bài dùng schema shop.
-- setseed() giúp mọi người sinh ra cùng một bộ dữ liệu.
-- =============================================================

DROP SCHEMA IF EXISTS perf CASCADE;
CREATE SCHEMA perf;

SELECT setseed(0.42);

CREATE TABLE perf.customers (
    customer_id INT PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL,
    city        VARCHAR(100) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL
);

INSERT INTO perf.customers
SELECT i,
       'Khách hàng ' || i,
       'user' || i || '@example.com',
       (ARRAY['TP. Hồ Chí Minh', 'Hà Nội', 'Đà Nẵng', 'Cần Thơ', 'Hải Phòng',
              'Biên Hòa', 'Huế', 'Nha Trang', 'Vũng Tàu', 'Quy Nhơn'])[1 + floor(random() * 10)::int],
       TIMESTAMPTZ '2023-01-01' + random() * INTERVAL '1000 days'
FROM generate_series(1, 100000) AS i;

CREATE TABLE perf.orders (
    order_id     INT PRIMARY KEY,
    customer_id  INT           NOT NULL REFERENCES perf.customers (customer_id),
    order_date   TIMESTAMPTZ   NOT NULL,
    status       VARCHAR(20)   NOT NULL,
    total_amount NUMERIC(12,0) NOT NULL
);

INSERT INTO perf.orders
SELECT i,
       1 + floor(random() * 100000)::int,
       TIMESTAMPTZ '2023-01-01' + random() * INTERVAL '1380 days',
       -- phân bố lệch như thực tế: phần lớn đơn đã giao
       CASE WHEN r < 0.85 THEN 'delivered'
            WHEN r < 0.93 THEN 'cancelled'
            WHEN r < 0.97 THEN 'shipped'
            WHEN r < 0.99 THEN 'paid'
            ELSE 'pending' END,
       round((100000 + random() * 30000000) / 1000) * 1000
FROM (SELECT i, random() AS r FROM generate_series(1, 1000000) AS i) AS g;

-- Cố ý KHÔNG tạo index trên perf.orders(customer_id), order_date, status
-- để học viên tự đo trước và sau khi tạo index.
ANALYZE perf.customers;
ANALYZE perf.orders;
