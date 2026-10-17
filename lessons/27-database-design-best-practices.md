# Ngày 27: Thiết kế cơ sở dữ liệu

> **Tóm tắt:** Thiết kế tốt bắt đầu từ việc xác định thực thể và quan hệ (ERD), rồi dùng phụ thuộc hàm để kiểm tra mỗi sự thật chỉ được lưu đúng một chỗ (chuẩn hóa 1NF, 2NF, 3NF, BCNF). Bài này làm mẫu từng bước chuẩn hóa một bảng đơn hàng "phẳng" cho tới đúng cấu trúc của DSC Shop, rồi phân tích vì sao DSC Shop được thiết kế như hiện tại và khi nào nên cố ý phi chuẩn hóa.

**Sau bài này bạn có thể:**

- Đọc và vẽ ERD, xác định quan hệ 1-1, 1-n, n-n và đặt khóa ngoại, bảng trung gian đúng chỗ.
- Viết ra các phụ thuộc hàm của một bảng và kiểm tra chúng trên dữ liệu bằng `GROUP BY ... HAVING`.
- Nhận ra bảng vi phạm 1NF, 2NF, 3NF, BCNF và tách bảng để hết vi phạm, kèm DDL đầy đủ.
- Quyết định khi nào phi chuẩn hóa (lưu sẵn tổng tiền, materialized view) và cái giá phải trả.

**Cần biết trước:** [Ngày 2](02-table-structure-and-data-types.md) (khóa, ràng buộc), [Ngày 10](10-join.md) (JOIN), [Ngày 12](12-union-intersect.md) (EXCEPT), [Ngày 19](19-views.md) (materialized view).

> Các ví dụ tạo bảng trong schema riêng `thiet_ke` (và `bai_tap` ở phần bài tập), nên không đụng tới bảng của `shop`. Schema giống một thư mục chứa bảng: `thiet_ke.don_hang` và `shop.orders` là hai bảng khác nhau. Vì `search_path` là `shop, public`, khi làm việc với `thiet_ke` luôn ghi rõ tên schema.

## 1. Thiết kế đi từ đâu?

Thiết kế cơ sở dữ liệu thường qua ba mức:

| Mức | Câu hỏi | Kết quả |
| --- | --- | --- |
| Khái niệm | Hệ thống quản lý những "thứ" gì, chúng liên quan với nhau thế nào? | ERD: thực thể, thuộc tính, quan hệ |
| Logic | Mỗi thực thể thành bảng nào, khóa nào, có dư thừa không? | Lược đồ bảng đã chuẩn hóa |
| Vật lý | Kiểu dữ liệu, ràng buộc, index, phân vùng cụ thể trên PostgreSQL | Các lệnh `CREATE TABLE`, `CREATE INDEX` |

Thiết kế sai ở mức khái niệm (thiếu một thực thể, gộp hai thực thể làm một) là sai lầm đắt nhất, vì sửa nó nghĩa là sửa bảng, dữ liệu, và mọi truy vấn của ứng dụng.

## 2. ERD: thực thể và quan hệ

**Thực thể** (entity) là một loại đối tượng mà hệ thống cần lưu thông tin: khách hàng, sản phẩm, đơn hàng. Mỗi thực thể có **thuộc tính** (attribute), như tên, giá, ngày đặt. **Quan hệ** (relationship) nối các thực thể: khách hàng *đặt* đơn hàng, đơn hàng *chứa* sản phẩm.

Sơ đồ thực thể quan hệ (ERD: Entity Relationship Diagram) của DSC Shop:

![ERD của DSC Shop gồm 7 bảng. customers 1-n orders qua orders.customer_id. employees 0..1-n orders qua orders.employee_id (đơn online không có nhân viên). orders 1-n payments qua payments.order_id. orders n-n products thông qua bảng trung gian order_items, có khóa chính ghép (order_id, product_id) và các cột quantity, unit_price, discount. categories 1-n products qua products.category_id. categories tự tham chiếu qua parent_id để tạo cây danh mục, employees tự tham chiếu qua manager_id để tạo cây quản lý. orders là thực thể trung tâm.](img/erd-dsc-shop.png#gh-light-mode-only)
![ERD của DSC Shop gồm 7 bảng. customers 1-n orders qua orders.customer_id. employees 0..1-n orders qua orders.employee_id (đơn online không có nhân viên). orders 1-n payments qua payments.order_id. orders n-n products thông qua bảng trung gian order_items, có khóa chính ghép (order_id, product_id) và các cột quantity, unit_price, discount. categories 1-n products qua products.category_id. categories tự tham chiếu qua parent_id để tạo cây danh mục, employees tự tham chiếu qua manager_id để tạo cây quản lý. orders là thực thể trung tâm.](img/erd-dsc-shop-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/database-design-best-practices/erd-dsc-shop.html) · [nền tối](../diagrams/database-design-best-practices/erd-dsc-shop-dark.html)</small>

Cách đọc: `#` là khóa chính, `→` là khóa ngoại. Số ở hai đầu đường nối là **bản số** (cardinality): `1` và `N` nghĩa là một dòng bên này ứng với nhiều dòng bên kia. `0..1` nghĩa là có thể không có (cột khóa ngoại cho phép NULL).

> Bạn sẽ gặp nhiều kiểu ký hiệu ERD. Kiểu "chân chim" (crow's foot) phổ biến trong công cụ như dbdiagram.io, DBeaver, MySQL Workbench; Mermaid cũng dùng kiểu này (xem sơ đồ ở [setup/README.md](../setup/README.md#bộ-dữ-liệu-dsc-shop)). Ký hiệu khác nhau nhưng thông tin giống nhau: thực thể, khóa, bản số.

## 3. Ba loại quan hệ và cách cài đặt

### 3.1. Một nhiều (1-n): khóa ngoại nằm ở phía "nhiều"

Một khách có nhiều đơn, mỗi đơn thuộc đúng một khách. Cột `orders.customer_id` trỏ về `customers`. Không bao giờ đặt danh sách đơn vào bảng khách (một cột `order_ids` chứa `"1,4,13"` vi phạm 1NF, xem mục 5).

```sql
SELECT c.customer_id, c.full_name, count(o.order_id) AS so_don
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name
ORDER BY so_don DESC, c.customer_id
LIMIT 3;
```

| customer_id | full_name | so_don |
| --- | --- | --- |
| 1 | Nguyễn Văn An | 5 |
| 2 | Trần Thị Bình | 4 |
| 3 | Lê Hoàng Cường | 3 |

DSC Shop có nhiều quan hệ 1-n khác: `categories`/`products`, `orders`/`payments` (đơn 12 trả góp 2 lần), và hai quan hệ **tự tham chiếu**: `categories.parent_id` trỏ về chính `categories` (cây danh mục), `employees.manager_id` trỏ về chính `employees` (cây quản lý).

### 3.2. Một một (1-1): khóa ngoại kiêm khóa chính (hoặc UNIQUE)

Giả sử cửa hàng phát hành thẻ thành viên, mỗi khách có tối đa một thẻ. Đặt `customer_id` vừa là khóa chính vừa là khóa ngoại thì mỗi khách chỉ có được một dòng:

```sql
DROP SCHEMA IF EXISTS thiet_ke CASCADE;
CREATE SCHEMA thiet_ke;

CREATE TABLE thiet_ke.the_thanh_vien (
    customer_id INT PRIMARY KEY REFERENCES shop.customers (customer_id),
    hang        VARCHAR(20) NOT NULL CHECK (hang IN ('Bạc', 'Vàng', 'Kim cương')),
    diem        INT         NOT NULL DEFAULT 0 CHECK (diem >= 0),
    ngay_cap    DATE        NOT NULL
);

INSERT INTO thiet_ke.the_thanh_vien VALUES (1, 'Vàng', 1200, '2025-03-01');
INSERT INTO thiet_ke.the_thanh_vien VALUES (1, 'Bạc', 0, '2026-01-01');   -- thẻ thứ hai cho khách 1
```

```text
ERROR:  duplicate key value violates unique constraint "the_thanh_vien_pkey"
DETAIL:  Key (customer_id)=(1) already exists.
```

Vì sao không gộp luôn các cột thẻ vào `customers`? Tách bảng 1-1 có lý khi phần dữ liệu đó **tùy chọn** (đa số khách không có thẻ, gộp vào sẽ đầy NULL), **ít dùng**, hoặc **cần phân quyền riêng** (thông tin nhạy cảm). Nếu không có lý do nào như vậy, cứ gộp vào một bảng.

### 3.3. Nhiều nhiều (n-n): cần bảng trung gian

Một đơn có nhiều sản phẩm, một sản phẩm nằm trong nhiều đơn. Không thể đặt khóa ngoại ở bảng nào trong hai bảng, nên cần **bảng trung gian** (junction table) `order_items` với hai khóa ngoại, và khóa chính ghép `(order_id, product_id)`. Bảng trung gian còn là nơi chứa thuộc tính **của chính mối quan hệ**: số lượng, giá lúc mua, giảm giá.

Khóa chính ghép chặn việc một sản phẩm xuất hiện hai lần trong cùng một đơn (muốn mua thêm thì tăng `quantity`):

```sql
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (1, 23, 1, 150000);   -- đơn 1 đã có sản phẩm 23
```

```text
ERROR:  duplicate key value violates unique constraint "order_items_pkey"
DETAIL:  Key (order_id, product_id)=(1, 23) already exists.
```

## 4. Khóa và phụ thuộc hàm

### 4.1. Các loại khóa

| Khái niệm | Nghĩa | Ví dụ trong DSC Shop |
| --- | --- | --- |
| Siêu khóa (superkey) | Tập cột mà không có hai dòng nào trùng giá trị | `{product_id}`, `{product_id, name}`, `{sku}` |
| Khóa ứng viên (candidate key) | Siêu khóa tối thiểu: bỏ bất kỳ cột nào đi là hết duy nhất | `{product_id}`, `{sku}` của `products` |
| Khóa chính (primary key) | Khóa ứng viên được chọn làm định danh chính | `product_id` |
| Khóa tự nhiên (natural key) | Khóa có nghĩa ngoài đời | `sku`, `email` |
| Khóa thay thế (surrogate key) | Số do hệ thống sinh, không mang nghĩa | `product_id INT GENERATED ALWAYS AS IDENTITY` |

DSC Shop dùng khóa thay thế làm khóa chính và giữ khóa tự nhiên bằng `UNIQUE` (`products.sku`, `customers.email`). Lý do: khóa tự nhiên có thể đổi (cửa hàng đổi quy tắc mã SKU, khách đổi email), có thể thiếu (khách không để lại email), và khóa ngoại trỏ tới một số nguyên nhỏ thì gọn hơn. **Thuộc tính khóa** (prime attribute) là cột nằm trong ít nhất một khóa ứng viên.

### 4.2. Phụ thuộc hàm

Ta nói **X xác định Y**, viết **X → Y** (đọc: Y phụ thuộc hàm vào X), nếu hai dòng bất kỳ giống nhau ở X thì chắc chắn giống nhau ở Y. Biết X là tra ra đúng một giá trị Y.

Trong DSC Shop:

- `product_id → sku, name, price, category_id`: biết mã sản phẩm là biết tên, giá hiện tại, danh mục.
- `order_id → customer_id, order_date, status`: mỗi đơn có đúng một khách, một ngày đặt.
- `(order_id, product_id) → quantity, unit_price, discount`: số lượng và giá lúc mua là của **một dòng hàng**, cần cả hai cột mới xác định được.
- `customer_id → full_name, city`, nhưng `full_name ↛ customer_id`: hai khách cùng tên.

Phụ thuộc hàm là **quy tắc nghiệp vụ**, không phải điều rút ra từ dữ liệu. Dữ liệu chỉ có thể **bác bỏ** nó: tìm các giá trị X đi kèm nhiều hơn một giá trị Y.

```sql
-- full_name có xác định được khách không?
SELECT full_name, count(*) AS so_khach
FROM customers
GROUP BY full_name
HAVING count(DISTINCT customer_id) > 1;
```

| full_name | so_khach |
| --- | --- |
| Nguyễn Văn An | 2 |

```sql
-- product_id có xác định được unit_price trong order_items không?
SELECT product_id, count(DISTINCT unit_price) AS so_muc_gia,
       min(unit_price), max(unit_price)
FROM order_items
GROUP BY product_id
HAVING count(DISTINCT unit_price) > 1;
```

| product_id | so_muc_gia | min | max |
| --- | --- | --- | --- |
| 3 | 2 | 21990000 | 22990000 |
| 5 | 2 | 24990000 | 26990000 |

Cùng một sản phẩm mà có hai mức giá: `product_id ↛ unit_price`. Giá lúc mua phụ thuộc vào cả dòng hàng `(order_id, product_id)`, đúng như thiết kế. Nếu truy vấn kiểm tra trả về 0 dòng, nghĩa là dữ liệu hiện tại **chưa** vi phạm, chưa chắc quy tắc luôn đúng.

## 5. Chuẩn hóa từng bước

Chuẩn hóa (normalization) là tách bảng theo phụ thuộc hàm để **mỗi sự thật chỉ được lưu một lần**. Lưu một sự thật nhiều lần gây ra ba loại **dị thường** (anomaly):

- **Dị thường cập nhật:** sửa một chỗ, quên chỗ khác, dữ liệu mâu thuẫn.
- **Dị thường thêm:** không thêm được một sự thật vì thiếu một sự thật khác không liên quan.
- **Dị thường xóa:** xóa một sự thật làm mất luôn sự thật khác.

Các dạng chuẩn tóm tắt (mỗi dạng đòi hỏi dạng trước):

| Dạng chuẩn | Điều kiện |
| --- | --- |
| 1NF | Mỗi ô chứa một giá trị nguyên tố (không danh sách, không nhóm lặp), bảng có khóa |
| 2NF | 1NF, và mọi cột **không khóa** phụ thuộc vào **toàn bộ** mỗi khóa ứng viên, không phụ thuộc vào một phần của khóa ghép |
| 3NF | 2NF, và không cột không khóa nào phụ thuộc **bắc cầu** vào khóa (khóa → cột không khóa A → cột không khóa B). Nói chính xác: với mọi phụ thuộc X → A không tầm thường, hoặc X là siêu khóa, hoặc A là thuộc tính khóa |
| BCNF | Với mọi phụ thuộc X → A không tầm thường, X là siêu khóa |

Câu dễ nhớ cho 3NF: mọi cột không khóa phụ thuộc vào "khóa, toàn bộ khóa, và không gì khác ngoài khóa".

### 5.1. Chưa chuẩn hóa: phiếu bán hàng chép tay

Hình dung nhân viên ghi sổ bán hàng của khách Trần Thị Bình trong một bảng tính, mỗi đơn một dòng:

```sql
CREATE TABLE thiet_ke.phieu_ban_hang (
    order_id      INT PRIMARY KEY,
    order_date    DATE,
    customer_name VARCHAR(100),
    customer_city VARCHAR(100),
    products      TEXT
);

INSERT INTO thiet_ke.phieu_ban_hang VALUES
    (2,  '2025-01-20', 'Trần Thị Bình', 'Hà Nội', 'LAP-005 MacBook Air M2 13 inch x1'),
    (8,  '2025-04-22', 'Trần Thị Bình', 'Hà Nội', 'PHN-001 iPhone 15 128GB x1; ACC-008 Cáp USB-C to USB-C 1m x1'),
    (34, '2026-06-15', 'Trần Thị Bình', 'Hà Nội', 'ACC-007 Sạc Anker 65W x1; ACC-008 Cáp USB-C to USB-C 1m x5');
```

Cột `products` nhồi nhiều sản phẩm vào một ô: **vi phạm 1NF**. Muốn biết đơn nào mua cáp ACC-008, chỉ còn cách dò chuỗi:

```sql
SELECT order_id, products
FROM thiet_ke.phieu_ban_hang
WHERE products LIKE '%ACC-008%';
```

| order_id | products |
| --- | --- |
| 8 | PHN-001 iPhone 15 128GB x1; ACC-008 Cáp USB-C to USB-C 1m x1 |
| 34 | ACC-007 Sạc Anker 65W x1; ACC-008 Cáp USB-C to USB-C 1m x5 |

Còn câu "tổng số cáp ACC-008 đã bán" thì gần như không viết nổi bằng SQL, vì số lượng `x5` nằm lẫn trong chuỗi. Không có khóa ngoại nào kiểm tra mã sản phẩm có tồn tại.

### 5.2. 1NF: mỗi ô một giá trị

Tách mỗi sản phẩm của đơn thành một dòng. Một dòng giờ là một **dòng hàng**, khóa là `(order_id, sku)`. Lấy dữ liệu thật của khách 2 từ DSC Shop:

```sql
CREATE TABLE thiet_ke.don_hang_1nf (
    order_id      INT,
    sku           VARCHAR(20),
    order_date    DATE          NOT NULL,
    customer_id   INT           NOT NULL,
    customer_name VARCHAR(100)  NOT NULL,
    customer_city VARCHAR(100),
    product_name  VARCHAR(200)  NOT NULL,
    quantity      INT           NOT NULL,
    unit_price    NUMERIC(12,0) NOT NULL,
    PRIMARY KEY (order_id, sku)
);

INSERT INTO thiet_ke.don_hang_1nf
SELECT o.order_id, p.sku, o.order_date::date, c.customer_id, c.full_name, c.city,
       p.name, oi.quantity, oi.unit_price
FROM orders AS o
JOIN customers   AS c  ON c.customer_id = o.customer_id
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN products    AS p  ON p.product_id = oi.product_id
WHERE o.customer_id = 2;

SELECT * FROM thiet_ke.don_hang_1nf ORDER BY order_id, sku;
```

| order_id | sku | order_date | customer_id | customer_name | customer_city | product_name | quantity | unit_price |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2 | LAP-005 | 2025-01-20 | 2 | Trần Thị Bình | Hà Nội | MacBook Air M2 13 inch | 1 | 26990000 |
| 8 | ACC-008 | 2025-04-22 | 2 | Trần Thị Bình | Hà Nội | Cáp USB-C to USB-C 1m | 1 | 150000 |
| 8 | PHN-001 | 2025-04-22 | 2 | Trần Thị Bình | Hà Nội | iPhone 15 128GB | 1 | 19990000 |
| 22 | ACC-005 | 2025-11-11 | 2 | Trần Thị Bình | Hà Nội | Tai nghe AirPods Pro 2 | 1 | 5990000 |
| 22 | PHN-003 | 2025-11-11 | 2 | Trần Thị Bình | Hà Nội | Xiaomi Redmi Note 13 | 1 | 4890000 |
| 34 | ACC-007 | 2026-06-15 | 2 | Trần Thị Bình | Hà Nội | Sạc Anker 65W | 1 | 890000 |
| 34 | ACC-008 | 2026-06-15 | 2 | Trần Thị Bình | Hà Nội | Cáp USB-C to USB-C 1m | 5 | 150000 |

Đã đạt 1NF, nhưng nhìn là thấy lặp: tên và thành phố của khách lặp 7 lần, ngày đặt lặp theo số dòng của đơn, tên cáp ACC-008 lặp 2 lần. Đủ cả ba loại dị thường:

Dị thường thêm: sản phẩm `ACC-009` chưa bán được cái nào thì không có chỗ để ghi, vì khóa chính bắt buộc có `order_id`:

```sql
INSERT INTO thiet_ke.don_hang_1nf (sku, product_name, order_date, customer_id, customer_name, quantity, unit_price)
VALUES ('ACC-009', 'Lót chuột DSC XXL', '2026-10-17', 0, '?', 0, 0);
```

```text
ERROR:  null value in column "order_id" of relation "don_hang_1nf" violates not-null constraint
DETAIL:  Failing row contains (null, ACC-009, 2026-10-17, 0, ?, null, Lót chuột DSC XXL, 0, 0).
```

Dị thường cập nhật: đổi tên sản phẩm mà chỉ sửa một dòng, dữ liệu tự mâu thuẫn:

```sql
BEGIN;

UPDATE thiet_ke.don_hang_1nf
SET product_name = 'Cáp Type-C 1m'
WHERE order_id = 8 AND sku = 'ACC-008';

SELECT sku, product_name, count(*) AS so_dong
FROM thiet_ke.don_hang_1nf
WHERE sku = 'ACC-008'
GROUP BY sku, product_name;

ROLLBACK;
```

| sku | product_name | so_dong |
| --- | --- | --- |
| ACC-008 | Cáp Type-C 1m | 1 |
| ACC-008 | Cáp USB-C to USB-C 1m | 1 |

Dị thường xóa: nếu xóa đơn 2 (đơn duy nhất có `LAP-005` trong bảng này), thông tin "LAP-005 là MacBook Air M2 13 inch" biến mất theo.

### 5.3. Viết ra các phụ thuộc hàm

Khóa của `don_hang_1nf` là `(order_id, sku)`. Theo nghiệp vụ:

1. `order_id → order_date, customer_id`
2. `customer_id → customer_name, customer_city`
3. `sku → product_name`
4. `(order_id, sku) → quantity, unit_price`

Chỉ phụ thuộc 4 là "lành mạnh": vế trái là cả khóa. Các phụ thuộc còn lại là gốc rễ của sự lặp lại.

### 5.4. 2NF: bỏ phụ thuộc vào một phần khóa

Phụ thuộc 1 và 3 có vế trái chỉ là **một phần** của khóa ghép (`order_id` hoặc `sku`): đó là **phụ thuộc bộ phận**, vi phạm 2NF. Tách mỗi phần ra bảng riêng, vế trái thành khóa của bảng mới:

- `don_hang_2nf(order_id, order_date, customer_id, customer_name, customer_city)`, khóa `order_id`
- `san_pham(sku, product_name)`, khóa `sku`
- `dong_hang(order_id, sku, quantity, unit_price)`, khóa `(order_id, sku)`

Lưu ý: một bảng có khóa chính chỉ một cột thì không thể có phụ thuộc bộ phận, nên tự động đạt 2NF nếu đã đạt 1NF. 2NF chỉ là vấn đề với khóa ghép.

### 5.5. 3NF: bỏ phụ thuộc bắc cầu

Trong `don_hang_2nf` còn chuỗi `order_id → customer_id → customer_name, customer_city`. Tên và thành phố không phụ thuộc trực tiếp vào đơn mà phụ thuộc **qua** khách hàng: đó là **phụ thuộc bắc cầu**, vi phạm 3NF (`customer_id` không phải siêu khóa của bảng đơn). Khách đặt 4 đơn thì tên khách vẫn bị lặp 4 lần. Tách tiếp:

- `khach_hang(customer_id, customer_name, customer_city)`
- `don_hang(order_id, order_date, customer_id)`

Kết quả cuối cùng là 4 bảng, mỗi phụ thuộc hàm nằm gọn trong một bảng và vế trái là khóa của bảng đó:

![Chuẩn hóa bảng don_hang_1nf về 3NF. Bên trái là bảng don_hang_1nf có khóa ghép (order_id, sku), mỗi cột ghi kèm cột quyết định nó: order_date và customer_id phụ thuộc order_id, customer_name và customer_city phụ thuộc customer_id, product_name phụ thuộc sku, quantity và unit_price phụ thuộc cả (order_id, sku). Bên phải là 4 bảng sau chuẩn hóa: khach_hang (khóa customer_id, customer_name, customer_city) 1-n don_hang (khóa order_id, order_date, khóa ngoại customer_id) 1-n dong_hang (khóa ghép gồm hai khóa ngoại order_id và sku, quantity, unit_price), và san_pham (khóa sku, product_name) 1-n dong_hang.](img/chuan-hoa-orders.png#gh-light-mode-only)
![Chuẩn hóa bảng don_hang_1nf về 3NF. Bên trái là bảng don_hang_1nf có khóa ghép (order_id, sku), mỗi cột ghi kèm cột quyết định nó: order_date và customer_id phụ thuộc order_id, customer_name và customer_city phụ thuộc customer_id, product_name phụ thuộc sku, quantity và unit_price phụ thuộc cả (order_id, sku). Bên phải là 4 bảng sau chuẩn hóa: khach_hang (khóa customer_id, customer_name, customer_city) 1-n don_hang (khóa order_id, order_date, khóa ngoại customer_id) 1-n dong_hang (khóa ghép gồm hai khóa ngoại order_id và sku, quantity, unit_price), và san_pham (khóa sku, product_name) 1-n dong_hang.](img/chuan-hoa-orders-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/database-design-best-practices/chuan-hoa-orders.html) · [nền tối](../diagrams/database-design-best-practices/chuan-hoa-orders-dark.html)</small>

DDL đầy đủ, rồi chuyển dữ liệu từ bảng 1NF sang:

```sql
CREATE TABLE thiet_ke.khach_hang (
    customer_id   INT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_city VARCHAR(100)
);

CREATE TABLE thiet_ke.san_pham (
    sku          VARCHAR(20)  PRIMARY KEY,
    product_name VARCHAR(200) NOT NULL
);

CREATE TABLE thiet_ke.don_hang (
    order_id    INT  PRIMARY KEY,
    order_date  DATE NOT NULL,
    customer_id INT  NOT NULL REFERENCES thiet_ke.khach_hang (customer_id)
);

CREATE TABLE thiet_ke.dong_hang (
    order_id   INT           NOT NULL REFERENCES thiet_ke.don_hang (order_id),
    sku        VARCHAR(20)   NOT NULL REFERENCES thiet_ke.san_pham (sku),
    quantity   INT           NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,0) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, sku)
);

INSERT INTO thiet_ke.khach_hang
SELECT DISTINCT customer_id, customer_name, customer_city FROM thiet_ke.don_hang_1nf;

INSERT INTO thiet_ke.san_pham
SELECT DISTINCT sku, product_name FROM thiet_ke.don_hang_1nf;

INSERT INTO thiet_ke.don_hang
SELECT DISTINCT order_id, order_date, customer_id FROM thiet_ke.don_hang_1nf;

INSERT INTO thiet_ke.dong_hang
SELECT order_id, sku, quantity, unit_price FROM thiet_ke.don_hang_1nf;

SELECT (SELECT count(*) FROM thiet_ke.khach_hang) AS khach_hang,
       (SELECT count(*) FROM thiet_ke.san_pham)   AS san_pham,
       (SELECT count(*) FROM thiet_ke.don_hang)   AS don_hang,
       (SELECT count(*) FROM thiet_ke.dong_hang)  AS dong_hang;
```

| khach_hang | san_pham | don_hang | dong_hang |
| --- | --- | --- | --- |
| 1 | 6 | 4 | 7 |

Tên khách giờ lưu 1 lần thay vì 7, tên cáp ACC-008 lưu 1 lần thay vì 2.

Tách bảng có làm mất thông tin không? Kiểm tra bằng cách JOIN 4 bảng để dựng lại bảng cũ, rồi `EXCEPT` với bảng 1NF. Không còn dòng nào khác nghĩa là phép tách **không mất mát** (lossless):

```sql
SELECT d.order_id, l.sku, d.order_date, k.customer_id, k.customer_name, k.customer_city,
       s.product_name, l.quantity, l.unit_price
FROM thiet_ke.dong_hang  AS l
JOIN thiet_ke.don_hang   AS d ON d.order_id = l.order_id
JOIN thiet_ke.khach_hang AS k ON k.customer_id = d.customer_id
JOIN thiet_ke.san_pham   AS s ON s.sku = l.sku
EXCEPT
SELECT * FROM thiet_ke.don_hang_1nf;
```

Kết quả: 0 dòng.

Các dị thường biến mất: thêm sản phẩm chưa bán được, đổi tên sản phẩm chỉ sửa một dòng:

```sql
INSERT INTO thiet_ke.san_pham VALUES ('ACC-009', 'Lót chuột DSC XXL');
UPDATE thiet_ke.san_pham SET product_name = 'Cáp USB-C 1m' WHERE sku = 'ACC-008';

SELECT * FROM thiet_ke.san_pham ORDER BY sku;
```

| sku | product_name |
| --- | --- |
| ACC-005 | Tai nghe AirPods Pro 2 |
| ACC-007 | Sạc Anker 65W |
| ACC-008 | Cáp USB-C 1m |
| ACC-009 | Lót chuột DSC XXL |
| LAP-005 | MacBook Air M2 13 inch |
| PHN-001 | iPhone 15 128GB |
| PHN-003 | Xiaomi Redmi Note 13 |

Bốn bảng này chính là `customers`, `orders`, `order_items`, `products` của DSC Shop (DSC Shop dùng khóa thay thế `product_id` thay cho `sku`).

**`unit_price` có vi phạm 3NF không?** Không. Đơn 2 mua MacBook Air với giá 26.990.000, còn giá hiện tại trong `products` là 24.990.000. `unit_price` là sự thật của dòng hàng (`(order_id, sku) → unit_price`), không phải bản sao của giá sản phẩm. Ngược lại, nếu bạn chép **giá hiện tại** vào dòng hàng chỉ để khỏi JOIN, đó mới là phụ thuộc bộ phận `sku → price` và vi phạm 2NF.

### 5.6. BCNF: khi phần dư thừa nằm ngay trong khóa

3NF cho phép một ngoại lệ: phụ thuộc X → A với A là **thuộc tính khóa**, dù X không phải siêu khóa. BCNF bỏ luôn ngoại lệ này. Trường hợp này hiếm, chỉ xuất hiện khi bảng có nhiều khóa ứng viên chồng lên nhau.

Ví dụ: DSC Shop phân công nhân viên tư vấn theo nhóm hàng, với hai quy tắc:

- Mỗi nhân viên chỉ tư vấn một nhóm hàng: `employee_id → category_name`.
- Mỗi khách, với mỗi nhóm hàng, có đúng một người tư vấn: `(customer_id, category_name) → employee_id`.

```sql
CREATE TABLE thiet_ke.tu_van (
    customer_id   INT          NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    employee_id   INT          NOT NULL,
    PRIMARY KEY (customer_id, category_name),
    UNIQUE (customer_id, employee_id)
);

INSERT INTO thiet_ke.tu_van VALUES
    (1, 'Laptop',     4),
    (2, 'Laptop',     6),
    (2, 'Điện thoại', 5),
    (3, 'Laptop',     4),
    (3, 'Điện thoại', 5);

SELECT employee_id, count(DISTINCT category_name) AS so_nhom, count(*) AS so_dong
FROM thiet_ke.tu_van
GROUP BY employee_id
ORDER BY employee_id;
```

| employee_id | so_nhom | so_dong |
| --- | --- | --- |
| 4 | 1 | 2 |
| 5 | 1 | 2 |
| 6 | 1 | 1 |

Khóa ứng viên: `{customer_id, category_name}` và `{customer_id, employee_id}`. Mọi cột đều là thuộc tính khóa, nên bảng **đạt 3NF**. Nhưng `employee_id → category_name` có vế trái không phải siêu khóa, nên **vi phạm BCNF**: sự thật "nhân viên 4 tư vấn Laptop" bị lưu 2 lần; nhân viên mới chưa có khách thì không ghi được chuyên môn.

Tách theo phụ thuộc vi phạm:

```sql
CREATE TABLE thiet_ke.chuyen_mon (
    employee_id   INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
);

CREATE TABLE thiet_ke.phan_cong (
    customer_id INT NOT NULL,
    employee_id INT NOT NULL REFERENCES thiet_ke.chuyen_mon (employee_id),
    PRIMARY KEY (customer_id, employee_id)
);

INSERT INTO thiet_ke.chuyen_mon
SELECT DISTINCT employee_id, category_name FROM thiet_ke.tu_van;

INSERT INTO thiet_ke.phan_cong
SELECT customer_id, employee_id FROM thiet_ke.tu_van;

SELECT * FROM thiet_ke.chuyen_mon ORDER BY employee_id;
```

| employee_id | category_name |
| --- | --- |
| 4 | Laptop |
| 5 | Điện thoại |
| 6 | Laptop |

Cái giá: quy tắc "mỗi khách một người tư vấn cho mỗi nhóm hàng" giờ trải trên hai bảng, không còn ràng buộc `UNIQUE` nào chặn được. Gán thêm nhân viên 6 (cũng tư vấn Laptop) cho khách 1 vẫn thành công:

```sql
INSERT INTO thiet_ke.phan_cong VALUES (1, 6);

SELECT p.customer_id, c.category_name, count(*) AS so_nguoi_tu_van
FROM thiet_ke.phan_cong AS p
JOIN thiet_ke.chuyen_mon AS c ON c.employee_id = p.employee_id
GROUP BY p.customer_id, c.category_name
HAVING count(*) > 1;
```

| customer_id | category_name | so_nguoi_tu_van |
| --- | --- | --- |
| 1 | Laptop | 2 |

Muốn giữ quy tắc này phải dùng trigger (Ngày 18). Đây là lý do thực tế thường dừng ở 3NF: tách lên BCNF đôi khi làm mất khả năng kiểm tra một phụ thuộc bằng ràng buộc đơn giản. Hãy cân nhắc từng trường hợp.

## 6. Khi nào phi chuẩn hóa?

Phi chuẩn hóa (denormalization) là **cố ý** lưu dư thừa để đọc nhanh hơn, chấp nhận việc phải giữ các bản sao đồng bộ. Điều kiện: bạn đã chuẩn hóa trước, đã đo và thấy JOIN hoặc tính toán thật sự là nút thắt.

Ví dụ: DSC Shop không có cột tổng tiền trong `orders`, tổng luôn tính từ `order_items`, nên không thể lệch:

```sql
SELECT o.order_id,
       sum(oi.quantity * oi.unit_price * (1 - oi.discount)) AS tong_tien
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.order_id IN (12, 31)
GROUP BY o.order_id
ORDER BY o.order_id;
```

| order_id | tong_tien |
| --- | --- |
| 12 | 31880000.00 |
| 31 | 4779000.00 |

Ngược lại, bảng `perf.orders` có sẵn cột `total_amount`: đọc nhanh, nhưng mỗi khi sửa dòng hàng phải cập nhật lại tổng, trong cùng transaction hoặc bằng trigger. Quên một chỗ là sai số liệu.

| Cách | Khi nào | Cái giá |
| --- | --- | --- |
| Tính lúc đọc (JOIN, SUM) | Mặc định, dữ liệu vừa phải | Tốn CPU mỗi lần đọc |
| Materialized view (Ngày 19) | Báo cáo chấp nhận số liệu cũ vài phút | Phải `REFRESH` định kỳ |
| Cột lưu sẵn + trigger (Ngày 18) | Đọc cực nhiều, cần số mới ngay | Ghi chậm hơn, logic đồng bộ phức tạp |
| Bảng/kho riêng cho phân tích (OLAP) | Báo cáo nặng trên dữ liệu lớn (Ngày 25) | Hệ thống thứ hai phải đồng bộ |

Nguyên tắc chung: hệ thống giao dịch (OLTP) giữ chuẩn hóa, phần báo cáo (OLAP) có thể phi chuẩn hóa.

## 7. Vì sao DSC Shop được thiết kế như vậy

| Quyết định | Lý do |
| --- | --- |
| `order_items` có khóa chính `(order_id, product_id)` | Bảng trung gian của quan hệ n-n; một sản phẩm chỉ xuất hiện một lần mỗi đơn |
| `order_items.unit_price` tách khỏi `products.price` | Giá lúc mua là sự thật lịch sử (mục 5.5) |
| Không có cột tổng tiền trong `orders` | Dữ liệu dẫn xuất, tính được từ `order_items`, tránh lệch |
| `payments` là bảng riêng, không phải cột trong `orders` | Một đơn có thể trả nhiều lần (đơn 12 trả góp), hoặc chưa trả (đơn `pending`) |
| `orders.employee_id` cho phép NULL | Đơn online không có nhân viên bán: quan hệ `0..1` |
| `orders.shipping_city` tách khỏi `customers.city` | Hai sự thật khác nhau: nơi khách ở và nơi giao đơn này. `customer_id ↛ shipping_city` |
| `categories.parent_id`, `employees.manager_id` | Cây nhiều cấp bằng quan hệ tự tham chiếu, thay vì cố định số cột cấp 1, cấp 2 |
| Khóa thay thế `INT IDENTITY` + `UNIQUE` trên `sku`, `email` | Khóa chính ổn định, khóa tự nhiên vẫn không trùng (mục 4.1) |
| `products.attributes` là `JSONB` | Thông số mỗi loại sản phẩm mỗi khác (laptop có CPU, cáp thì không). Cột đa trị này là ngoại lệ có chủ đích với 1NF, chỉ dùng cho dữ liệu không cần ràng buộc chặt (Ngày 22) |
| `NUMERIC(12,0)` cho tiền, `TIMESTAMPTZ` cho thời điểm | Không sai số làm tròn; thời điểm không phụ thuộc múi giờ máy chủ (Ngày 2) |
| Index trên mọi cột khóa ngoại | PostgreSQL không tự tạo index cho khóa ngoại; JOIN và xóa dòng cha cần nó (Ngày 15) |

Điểm chưa tốt (cố ý để luyện tập): `customers.city` là chữ nhập tay nên có `TP. Hồ Chí Minh`, `TP.HCM`, `đà nẵng`. Đây là vấn đề chất lượng dữ liệu chứ không phải vi phạm dạng chuẩn. Nếu cần báo cáo theo thành phố chính xác, thêm bảng `cities` và cho `customers.city_id` trỏ tới, hoặc ít nhất làm sạch trước khi lưu (Ngày 5).

## 8. Thực hành tốt

**Đặt tên nhất quán.** Bảng số nhiều, chữ thường, snake_case (`order_items`); khóa chính `<thực thể>_id`; khóa ngoại cùng tên với khóa nó trỏ tới (`customer_id` ở cả hai bảng). Đừng trộn `CustomerID`, `customerId`, `cust_id` trong một schema.

**Chọn kiểu dữ liệu theo ý nghĩa.** Tiền dùng `NUMERIC`, không dùng `FLOAT`. Thời điểm dùng `TIMESTAMPTZ`. Không lưu dữ liệu dẫn xuất dễ cũ: lưu `birth_date`, tính tuổi khi cần bằng `AGE()`, đừng lưu cột `age`.

**Dùng NULL đúng nghĩa.** `NOT NULL` cho cột bắt buộc (tên khách, ngày đặt); cho phép NULL khi giá trị có thể thực sự chưa biết (email, ngày sinh). **Đừng thay NULL bằng giá trị giả** như `0`, `''`, `'1900-01-01'`: `AVG(birth_date)` hay `COUNT(email)` sẽ tính cả giá trị giả và cho kết quả sai. NULL không làm truy vấn chậm, B-tree của PostgreSQL vẫn index được NULL; cái cần nhớ là các bẫy logic của NULL (`= NULL`, `NOT IN` khi có NULL, Ngày 3 và 11). `DEFAULT` dành cho giá trị mặc định có thật (`status DEFAULT 'pending'`, `created_at DEFAULT now()`).

**Để cơ sở dữ liệu giữ quy tắc.** Khóa ngoại, `UNIQUE`, `CHECK`, `NOT NULL` chặn dữ liệu sai bất kể ứng dụng nào ghi vào. Kiểm tra ở ứng dụng là thêm, không phải thay thế.

**Index có chủ đích.** Index các cột khóa ngoại và cột hay lọc, sắp xếp; mỗi index làm chậm `INSERT`, `UPDATE` (Ngày 15). Bảng rất lớn theo thời gian thì cân nhắc partition (Ngày 25).

## Lỗi thường gặp

**1. Lưu danh sách trong một cột.** `orders.product_ids = '3,5,12'`: vi phạm 1NF, không có khóa ngoại, không JOIN được. Đúng: bảng trung gian `order_items`.

**2. Tham chiếu bằng tên thay vì khóa.** `employees.manager_name VARCHAR`: trùng tên thì không biết ai, đổi tên phải sửa nhiều nơi. Đúng: `manager_id INT REFERENCES employees (employee_id)`.

**3. Quan hệ n-n mà đặt khóa ngoại ở một bên.** `products.order_id` chỉ cho mỗi sản phẩm thuộc một đơn. Đúng: bảng trung gian với khóa chính ghép.

**4. Chép giá trị hiện tại thay vì lưu sự thật lịch sử, hoặc ngược lại.** Dòng hàng phải có giá lúc mua (`unit_price`); nhưng thông tin khách (tên, thành phố hiện tại) thì không chép vào đơn.

**5. Lưu tổng, tuổi, số lượng đếm được mà không có cơ chế đồng bộ.** Nếu thật sự cần, đi kèm trigger, transaction hoặc materialized view (mục 6).

**6. Chuẩn hóa quá mức.** Tách mỗi cột ra một bảng, hoặc tách bảng 1-1 không có lý do (mục 3.2), làm mọi truy vấn phải JOIN 6, 7 bảng. Chuẩn hóa để loại dư thừa, không phải để có nhiều bảng.

## Bài tập

Các đáp án tạo bảng trong schema `bai_tap`, mỗi đáp án tự tạo lại schema nên chạy độc lập được.

### Cơ bản

**Bài 1.** Với mỗi cặp bảng trong DSC Shop, cho biết loại quan hệ (1-1, 1-n, n-n, tự tham chiếu) và khóa ngoại nằm ở đâu: (a) `customers` và `orders`; (b) `orders` và `products`; (c) `orders` và `payments`; (d) `employees` với chính nó; (e) `employees` và `orders`.

<details>
<summary>Đáp án</summary>

(a) 1-n, `orders.customer_id`. (b) n-n, qua bảng trung gian `order_items` (`order_id`, `product_id`). (c) 1-n, `payments.order_id` (một đơn có 0, 1 hoặc nhiều lần thanh toán). (d) tự tham chiếu 1-n, `employees.manager_id`. (e) `0..1`-n, `orders.employee_id` cho phép NULL vì đơn online không có nhân viên.
</details>

**Bài 2.** Liệu `customer_id → shipping_city` có đúng trong `orders` không? Viết truy vấn kiểm tra trên dữ liệu, rồi cho biết có nên chuyển `shipping_city` sang bảng `customers` không.

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id, count(DISTINCT shipping_city) AS so_thanh_pho
FROM orders
GROUP BY customer_id
HAVING count(DISTINCT shipping_city) > 1;
```

Kết quả: 0 dòng. Dữ liệu hiện tại không bác bỏ phụ thuộc này, nhưng nó **không phải quy tắc nghiệp vụ**: khách hoàn toàn có thể đặt đơn giao về quê hoặc tới công ty. Dữ liệu chỉ bác bỏ được, không chứng minh được một phụ thuộc hàm. Vì vậy giữ `shipping_city` trong `orders`.
</details>

### Vận dụng

**Bài 3.** Bảng sau có những lỗi thiết kế nào? Viết lại bằng DDL PostgreSQL và thử một truy vấn liệt kê nhân viên, phòng ban, quản lý.

```text
employees(id, name, department, manager_name)
```

<details>
<summary>Đáp án</summary>

- `department` là chữ tự do: tên phòng lặp ở mọi nhân viên (dị thường cập nhật khi đổi tên phòng), không thêm được phòng chưa có người. Tách bảng `departments`.
- `manager_name` tham chiếu bằng tên: trùng tên thì mơ hồ, không có khóa ngoại kiểm tra. Đổi thành `manager_id` tự tham chiếu.

```sql
DROP SCHEMA IF EXISTS bai_tap CASCADE;
CREATE SCHEMA bai_tap;

CREATE TABLE bai_tap.departments (
    department_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE bai_tap.employees (
    employee_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    department_id INT NOT NULL REFERENCES bai_tap.departments (department_id),
    manager_id    INT REFERENCES bai_tap.employees (employee_id)
);
CREATE INDEX ON bai_tap.employees (department_id);
CREATE INDEX ON bai_tap.employees (manager_id);

INSERT INTO bai_tap.departments (name) VALUES ('Kinh doanh'), ('Kỹ thuật');
INSERT INTO bai_tap.employees (full_name, department_id, manager_id) VALUES
    ('Lê Thị Hạnh',   1, NULL),
    ('Phạm Thị Thu',  1, 1),
    ('Trần Quốc Bảo', 2, NULL),
    ('Lâm Gia Huy',   2, 3);

SELECT e.full_name, d.name AS phong_ban, m.full_name AS quan_ly
FROM bai_tap.employees AS e
JOIN bai_tap.departments AS d ON d.department_id = e.department_id
LEFT JOIN bai_tap.employees AS m ON m.employee_id = e.manager_id
ORDER BY e.employee_id;
```

Kết quả:

| full_name | phong_ban | quan_ly |
| --- | --- | --- |
| Lê Thị Hạnh | Kinh doanh | |
| Phạm Thị Thu | Kinh doanh | Lê Thị Hạnh |
| Trần Quốc Bảo | Kỹ thuật | |
| Lâm Gia Huy | Kỹ thuật | Trần Quốc Bảo |
</details>

**Bài 4.** Chuẩn hóa bảng sau về 3NF. Viết ra các phụ thuộc hàm, DDL đầy đủ có khóa ngoại, rồi chứng minh thiết kế giữ được giá lúc mua khi giá sản phẩm thay đổi.

```text
orders(order_id, order_date, customer_name, customer_phone, product_name, product_price, quantity)
-- một đơn có thể có nhiều sản phẩm, mỗi sản phẩm một dòng
```

<details>
<summary>Đáp án</summary>

Một đơn nhiều dòng nên `order_id` không còn là khóa; khóa thật là `(order_id, product_name)`. Phụ thuộc hàm (giả sử thêm mã khách, mã sản phẩm làm khóa thay thế): `order_id → order_date, customer_id`; `customer_id → customer_name, customer_phone`; `product_id → product_name, price`; `(order_id, product_id) → quantity, unit_price`.

Bẫy hay gặp: `product_price` trong bảng gốc là giá lúc mua hay giá hiện tại? Phải có **cả hai**: `products.price` (giá hiện tại) và `order_items.unit_price` (giá lúc mua). Và đừng quên bảng `orders` nối khách với các dòng hàng.

```sql
DROP SCHEMA IF EXISTS bai_tap CASCADE;
CREATE SCHEMA bai_tap;

CREATE TABLE bai_tap.customers (
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name   VARCHAR(100) NOT NULL,
    phone       VARCHAR(20)
);

CREATE TABLE bai_tap.products (
    product_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(200)  NOT NULL,
    price      NUMERIC(12,0) NOT NULL CHECK (price >= 0)
);

CREATE TABLE bai_tap.orders (
    order_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT         NOT NULL REFERENCES bai_tap.customers (customer_id),
    order_date  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE bai_tap.order_items (
    order_id   INT           NOT NULL REFERENCES bai_tap.orders (order_id),
    product_id INT           NOT NULL REFERENCES bai_tap.products (product_id),
    quantity   INT           NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12,0) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, product_id)
);
CREATE INDEX ON bai_tap.orders (customer_id);
CREATE INDEX ON bai_tap.order_items (product_id);

INSERT INTO bai_tap.customers (full_name, phone) VALUES ('Trần Thị Bình', '0912345678');
INSERT INTO bai_tap.products (name, price) VALUES ('iPhone 15 128GB', 19990000), ('Cáp USB-C to USB-C 1m', 150000);
INSERT INTO bai_tap.orders (customer_id, order_date) VALUES (1, '2025-04-22 10:00');
INSERT INTO bai_tap.order_items (order_id, product_id, quantity, unit_price)
SELECT 1, product_id, 1, price FROM bai_tap.products;

-- iPhone giảm giá sau khi đơn đã đặt
UPDATE bai_tap.products SET price = 17990000 WHERE product_id = 1;

SELECT p.name, oi.quantity, oi.unit_price AS gia_luc_mua, p.price AS gia_hien_tai
FROM bai_tap.order_items AS oi
JOIN bai_tap.products AS p ON p.product_id = oi.product_id
WHERE oi.order_id = 1
ORDER BY p.product_id;
```

Kết quả:

| name | quantity | gia_luc_mua | gia_hien_tai |
| --- | --- | --- | --- |
| iPhone 15 128GB | 1 | 19990000 | 17990000 |
| Cáp USB-C to USB-C 1m | 1 | 150000 | 150000 |

Không có cột tổng tiền: đó là dữ liệu dẫn xuất. Nếu muốn lưu sẵn thì là phi chuẩn hóa có chủ đích (mục 6), phải đồng bộ bằng trigger hoặc transaction.
</details>

**Bài 5.** DSC Shop thêm hai tính năng: (a) mỗi khách có nhiều địa chỉ giao hàng, tối đa một địa chỉ mặc định; (b) khách đánh giá sản phẩm từ 1 tới 5 sao, mỗi khách chỉ một đánh giá cho mỗi sản phẩm. Thiết kế bảng (trỏ tới `shop.customers`, `shop.products`) sao cho cơ sở dữ liệu tự chặn dữ liệu sai, rồi thử chèn dữ liệu vi phạm.

<details>
<summary>Đáp án</summary>

(a) là quan hệ 1-n; "tối đa một địa chỉ mặc định" dùng partial unique index (Ngày 15). (b) là quan hệ n-n giữa khách và sản phẩm, bảng trung gian `reviews` có khóa chính ghép, chính khóa này giữ quy tắc "một đánh giá mỗi sản phẩm".

```sql
DROP SCHEMA IF EXISTS bai_tap CASCADE;
CREATE SCHEMA bai_tap;

CREATE TABLE bai_tap.addresses (
    address_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT          NOT NULL REFERENCES shop.customers (customer_id) ON DELETE CASCADE,
    line        VARCHAR(200) NOT NULL,
    city        VARCHAR(100) NOT NULL,
    is_default  BOOLEAN      NOT NULL DEFAULT FALSE
);
CREATE INDEX ON bai_tap.addresses (customer_id);
CREATE UNIQUE INDEX ON bai_tap.addresses (customer_id) WHERE is_default;

CREATE TABLE bai_tap.reviews (
    customer_id INT         NOT NULL REFERENCES shop.customers (customer_id),
    product_id  INT         NOT NULL REFERENCES shop.products (product_id),
    rating      SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    content     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (customer_id, product_id)
);
CREATE INDEX ON bai_tap.reviews (product_id);

INSERT INTO bai_tap.addresses (customer_id, line, city, is_default) VALUES
    (2, '12 Láng Hạ',      'Hà Nội', TRUE),
    (2, '5 Trần Duy Hưng', 'Hà Nội', FALSE);

INSERT INTO bai_tap.reviews (customer_id, product_id, rating, content) VALUES
    (2, 23, 5, 'Cáp chắc chắn'),
    (1, 23, 4, NULL),
    (8, 12, 3, 'Tạm ổn');
```

Thử dữ liệu sai, từng lệnh một:

```sql
INSERT INTO bai_tap.addresses (customer_id, line, city, is_default)
VALUES (2, '1 Đại Cồ Việt', 'Hà Nội', TRUE);                               -- địa chỉ mặc định thứ hai
```

```text
ERROR:  duplicate key value violates unique constraint "addresses_customer_id_idx1"
DETAIL:  Key (customer_id)=(2) already exists.
```

```sql
INSERT INTO bai_tap.reviews (customer_id, product_id, rating) VALUES (2, 23, 1);   -- đánh giá lần hai
```

```text
ERROR:  duplicate key value violates unique constraint "reviews_pkey"
DETAIL:  Key (customer_id, product_id)=(2, 23) already exists.
```

```sql
INSERT INTO bai_tap.reviews (customer_id, product_id, rating) VALUES (3, 12, 6);   -- 6 sao
```

```text
ERROR:  new row for relation "reviews" violates check constraint "reviews_rating_check"
DETAIL:  Failing row contains (3, 12, 6, null, 2026-10-17 16:21:30.626+07).
```

(Thời điểm trong `DETAIL` sẽ khác trên máy bạn.) Điểm trung bình mỗi sản phẩm:

```sql
SELECT p.sku, p.name, count(*) AS so_danh_gia, round(avg(r.rating), 2) AS diem_tb
FROM bai_tap.reviews AS r
JOIN products AS p ON p.product_id = r.product_id
GROUP BY p.sku, p.name
ORDER BY p.sku;
```

| sku | name | so_danh_gia | diem_tb |
| --- | --- | --- | --- |
| ACC-008 | Cáp USB-C to USB-C 1m | 2 | 4.50 |
| PHN-003 | Xiaomi Redmi Note 13 | 1 | 3.00 |

Quy tắc "chỉ khách đã mua mới được đánh giá" không diễn đạt được bằng khóa ngoại, vì phải nhìn qua `orders` và `order_items`. Cần trigger (Ngày 18) hoặc kiểm tra trong transaction của ứng dụng. Truy vấn tìm đánh giá vi phạm (ở đây trả về 0 dòng):

```sql
SELECT r.customer_id, r.product_id
FROM bai_tap.reviews AS r
WHERE NOT EXISTS (
    SELECT 1
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.customer_id = r.customer_id AND oi.product_id = r.product_id
);
```
</details>

### Thử thách

**Bài 6.** Bảng `nguon_hang(sku, nha_cung_cap, nguoi_lien_he)` ghi mỗi sản phẩm được nhập từ nhà cung cấp nào, qua người liên hệ nào. Quy tắc: mỗi người liên hệ chỉ làm cho một nhà cung cấp (`nguoi_lien_he → nha_cung_cap`); với mỗi sản phẩm, mỗi nhà cung cấp chỉ cử một người liên hệ (`(sku, nha_cung_cap) → nguoi_lien_he`). Tìm các khóa ứng viên. Bảng đạt dạng chuẩn cao nhất nào? Nếu tách lên BCNF thì mất gì?

<details>
<summary>Đáp án</summary>

- Khóa ứng viên: `{sku, nha_cung_cap}` (theo phụ thuộc thứ hai) và `{sku, nguoi_lien_he}` (vì `nguoi_lien_he → nha_cung_cap`, nên `{sku, nguoi_lien_he}` xác định cả ba cột). Mọi cột đều là thuộc tính khóa.
- 2NF: không có cột không khóa nào, nên không thể có phụ thuộc bộ phận. 3NF: phụ thuộc `nguoi_lien_he → nha_cung_cap` có vế phải là thuộc tính khóa, nên vẫn đạt 3NF.
- BCNF: không đạt, vì `nguoi_lien_he` không phải siêu khóa. Hệ quả: "chị A làm cho công ty X" lặp lại ở mọi sản phẩm chị A phụ trách.
- Tách lên BCNF: `lien_he(nguoi_lien_he PRIMARY KEY, nha_cung_cap)` và `nguon_hang(sku, nguoi_lien_he, PRIMARY KEY (sku, nguoi_lien_he))`. Mất đi: quy tắc `(sku, nha_cung_cap) → nguoi_lien_he` không còn kiểm tra được bằng một `UNIQUE`, vì `nha_cung_cap` nằm ở bảng khác. Đây đúng là tình huống của mục 5.6: chọn giữ 3NF với ràng buộc đơn giản, hoặc lên BCNF và giữ quy tắc bằng trigger.
</details>

**Bài 7.** Trang quản trị cần tổng tiền của mọi đơn, mở hàng trăm lần mỗi phút, chấp nhận số liệu cũ vài phút. Hãy phi chuẩn hóa bằng materialized view (không sửa bảng `orders`), kiểm tra tổng của đơn 12 và 31, và cho thấy view không tự cập nhật khi dữ liệu gốc đổi.

<details>
<summary>Đáp án</summary>

```sql
DROP SCHEMA IF EXISTS bai_tap CASCADE;
CREATE SCHEMA bai_tap;

CREATE MATERIALIZED VIEW bai_tap.order_totals AS
SELECT order_id,
       sum(quantity * unit_price * (1 - discount)) AS tong_tien
FROM order_items
GROUP BY order_id;

-- Bắt buộc có UNIQUE index để REFRESH ... CONCURRENTLY (không khóa người đọc)
CREATE UNIQUE INDEX ON bai_tap.order_totals (order_id);

SELECT * FROM bai_tap.order_totals WHERE order_id IN (12, 31) ORDER BY order_id;
```

| order_id | tong_tien |
| --- | --- |
| 12 | 31880000.00 |
| 31 | 4779000.00 |

Đổi dữ liệu gốc trong transaction rồi `ROLLBACK` để không làm hỏng bộ dữ liệu:

```sql
BEGIN;

UPDATE order_items SET quantity = 2 WHERE order_id = 31 AND product_id = 16;

SELECT * FROM bai_tap.order_totals WHERE order_id = 31;   -- vẫn số cũ

REFRESH MATERIALIZED VIEW CONCURRENTLY bai_tap.order_totals;

SELECT * FROM bai_tap.order_totals WHERE order_id = 31;   -- số mới

ROLLBACK;
```

| order_id | tong_tien |
| --- | --- |
| 31 | 4779000.00 |

| order_id | tong_tien |
| --- | --- |
| 31 | 5178000.00 |

Trước `REFRESH`, view vẫn trả 4.779.000 dù đơn đã thêm một chuột G102 (399.000). Đó là cái giá của phi chuẩn hóa: phải lên lịch `REFRESH`. Nếu cần số mới tức thì, dùng cột lưu sẵn cập nhật bằng trigger, đổi lại ghi chậm hơn và phức tạp hơn.
</details>

### Dọn dẹp

```sql
DROP SCHEMA IF EXISTS thiet_ke CASCADE;
DROP SCHEMA IF EXISTS bai_tap CASCADE;
```

## Tóm tắt

- Thiết kế đi từ khái niệm (ERD) tới logic (bảng, khóa, chuẩn hóa) tới vật lý (kiểu, ràng buộc, index).
- Quan hệ 1-n: khóa ngoại ở phía nhiều. 1-1: khóa ngoại kiêm khóa chính hoặc `UNIQUE`. n-n: bảng trung gian có khóa chính ghép, chứa thuộc tính của chính quan hệ.
- Phụ thuộc hàm X → Y: cùng X thì cùng Y. Là quy tắc nghiệp vụ; dữ liệu chỉ bác bỏ được, kiểm tra bằng `GROUP BY X HAVING count(DISTINCT Y) > 1`.
- 1NF: giá trị nguyên tố. 2NF: không cột không khóa nào phụ thuộc vào một phần khóa ghép. 3NF: không phụ thuộc bắc cầu qua cột không khóa. BCNF: mọi vế trái của phụ thuộc là siêu khóa.
- Mục tiêu thực tế thường là 3NF; BCNF có thể làm mất khả năng kiểm tra một quy tắc bằng ràng buộc đơn giản.
- Giá lúc mua (`unit_price`) là sự thật lịch sử, không phải dư thừa. Tổng tiền là dữ liệu dẫn xuất: tính khi đọc, hoặc phi chuẩn hóa có chủ đích kèm cơ chế đồng bộ.
- NULL dùng cho giá trị chưa biết; không thay bằng giá trị giả. Để cơ sở dữ liệu giữ quy tắc bằng khóa ngoại, `UNIQUE`, `CHECK`, `NOT NULL`.

## Đọc thêm

- [PostgreSQL: Constraints](https://www.postgresql.org/docs/16/ddl-constraints.html)
- [Giới thiệu UUID (Universally Unique Identifier) - Định danh duy nhất toàn cầu](https://tiennhm.io.vn/blog/gioi-thieu-uuid-universally-unique-identifier) — một lựa chọn khóa thay thế khác bên cạnh `IDENTITY`.
- [Thêm 4 index làm INSERT chậm 6 lần: cái giá không ai nhắc khi bảo bạn đánh index](https://tiennhm.io.vn/blog/chi-phi-ghi-cua-index) — Mọi hướng dẫn tối ưu đều bảo thêm index, rất ít bài nói về hoá đơn.
- [Hai giao dịch cùng cộng 100, số dư chỉ tăng 100: isolation level qua thí nghiệm thật](https://tiennhm.io.vn/blog/sql-isolation-level-lost-update-phantom-read) — Hai phiên cùng đọc số dư 1000 rồi cùng ghi 1100.
- [Có index rồi mà truy vấn vẫn quét toàn bảng? Sargability và một hàm bọc quanh cột](https://tiennhm.io.vn/blog/sql-index-khong-duoc-dung-sargable) — Cột đã có index, câu WHERE lọc đúng cột đó, nhưng execution plan vẫn là Seq Scan.
- [Vì sao NOT IN của bạn trả về 0 dòng? Logic ba trị của SQL và cái bẫy NULL](https://tiennhm.io.vn/blog/sql-null-not-in-three-valued-logic) — các bẫy NULL nhắc ở mục 8.

---

[⬅️ Ngày 26: SQL và NoSQL](26-sql-nosql.md) | [📚 Mục lục](../README.md) | [Ngày 28: Tối ưu truy vấn ➡️](28-sql-query-optimization.md)
