-- =============================================================
-- 30 Days SQL Challenge - bộ dữ liệu thực hành dùng chung
-- Cửa hàng đồ công nghệ "DSC Shop" (PostgreSQL 16)
--
-- Chạy lại từ đầu: psql -d sql_challenge -f 01_schema.sql -f 02_seed.sql
-- (file này tự xóa và tạo lại schema shop)
-- =============================================================

DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;

-- Danh mục sản phẩm, dạng cây: parent_id trỏ về danh mục cha
CREATE TABLE shop.categories (
    category_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    parent_id   INT REFERENCES shop.categories (category_id)
);

CREATE TABLE shop.products (
    product_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku            VARCHAR(20)   NOT NULL UNIQUE,
    name           VARCHAR(200)  NOT NULL,
    category_id    INT           NOT NULL REFERENCES shop.categories (category_id),
    price          NUMERIC(12,0) NOT NULL CHECK (price >= 0),          -- giá bán, VNĐ
    cost_price     NUMERIC(12,0)          CHECK (cost_price >= 0),     -- giá nhập, có thể chưa có
    stock_quantity INT           NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    attributes     JSONB,                                              -- thông số kỹ thuật
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE shop.customers (
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(255) UNIQUE,       -- có khách không để lại email (NULL)
    phone       VARCHAR(20),
    city        VARCHAR(100),              -- nhập tay nên có chỗ viết không thống nhất
    birth_date  DATE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Nhân viên, dạng cây: manager_id trỏ về quản lý trực tiếp
CREATE TABLE shop.employees (
    employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   VARCHAR(100)  NOT NULL,
    title       VARCHAR(100)  NOT NULL,
    manager_id  INT REFERENCES shop.employees (employee_id),
    hire_date   DATE          NOT NULL,
    salary      NUMERIC(12,0) NOT NULL CHECK (salary > 0)
);

CREATE TABLE shop.orders (
    order_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   INT         NOT NULL REFERENCES shop.customers (customer_id),
    employee_id   INT         REFERENCES shop.employees (employee_id),   -- NULL với đơn online
    order_date    TIMESTAMPTZ NOT NULL,
    status        VARCHAR(20) NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
    channel       VARCHAR(10) NOT NULL CHECK (channel IN ('online', 'offline')),
    shipping_city VARCHAR(100),
    note          TEXT
);

CREATE TABLE shop.order_items (
    order_id   INT           NOT NULL REFERENCES shop.orders (order_id) ON DELETE CASCADE,
    product_id INT           NOT NULL REFERENCES shop.products (product_id),
    quantity   INT           NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,0) NOT NULL CHECK (unit_price >= 0),   -- giá tại thời điểm mua
    discount   NUMERIC(3,2)  NOT NULL DEFAULT 0 CHECK (discount BETWEEN 0 AND 1),
    PRIMARY KEY (order_id, product_id)
);

CREATE TABLE shop.payments (
    payment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id   INT           NOT NULL REFERENCES shop.orders (order_id),
    amount     NUMERIC(12,0) NOT NULL CHECK (amount > 0),
    method     VARCHAR(20)   NOT NULL CHECK (method IN ('cash', 'card', 'momo', 'bank_transfer')),
    paid_at    TIMESTAMPTZ   NOT NULL
);

-- Khóa ngoại không tự có index trong PostgreSQL
CREATE INDEX ON shop.products (category_id);
CREATE INDEX ON shop.orders (customer_id);
CREATE INDEX ON shop.order_items (product_id);
CREATE INDEX ON shop.payments (order_id);

-- Để viết "customers" thay vì "shop.customers", và để ngày giờ hiển thị
-- theo giờ Việt Nam dù PostgreSQL cài ở múi giờ nào (kết quả trong bài dựa trên điều này)
DO $$
BEGIN
    EXECUTE format('ALTER DATABASE %I SET search_path = shop, public', current_database());
    EXECUTE format('ALTER DATABASE %I SET timezone = %L', current_database(), 'Asia/Ho_Chi_Minh');
END $$;
SET search_path = shop, public;
SET timezone = 'Asia/Ho_Chi_Minh';
