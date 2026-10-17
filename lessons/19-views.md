# Ngày 19: View và materialized view

> **Tóm tắt:** View là một truy vấn được đặt tên và lưu trong database, dùng như một bảng ảo. Bài này dạy cách tạo, sửa, xóa view, cập nhật dữ liệu qua view, chặn dữ liệu sai bằng `WITH CHECK OPTION`, và dùng materialized view khi cần lưu sẵn kết quả của một truy vấn nặng.

**Sau bài này bạn có thể:**

- Viết được `CREATE VIEW` để gói một truy vấn JOIN và GROUP BY dài thành một tên ngắn, rồi truy vấn view như một bảng.
- Sửa view đúng luật của PostgreSQL (`CREATE OR REPLACE VIEW` chỉ thêm cột ở cuối) và xóa view khi có view khác phụ thuộc.
- Nhận biết view nào cập nhật được, và dùng `WITH CHECK OPTION` để chặn ghi dữ liệu nằm ngoài view.
- Tạo materialized view, làm mới bằng `REFRESH MATERIALIZED VIEW` (kể cả `CONCURRENTLY`), và giải thích khi nào nên dùng nó thay cho view thường.
- Dùng view để chỉ cho người khác thấy những cột họ cần thấy.

**Cần biết trước:** [Ngày 9](09-group-by-having.md) (GROUP BY), [Ngày 10](10-join.md) (JOIN), [Ngày 15](15-index.md) (index), [Ngày 16](16-transactions-acid.md) (transaction).

## View là gì?

Trong DSC Shop, bảng `orders` không có cột tổng tiền. Muốn biết mỗi đơn bao nhiêu tiền, lần nào bạn cũng phải JOIN với `order_items` rồi `SUM(quantity * unit_price * (1 - discount))`. Viết đi viết lại đoạn đó vừa mỏi tay vừa dễ sai (quên trừ `discount` chẳng hạn).

**View** (khung nhìn) giải quyết việc này: bạn đặt tên cho truy vấn đó một lần, sau này chỉ cần gọi tên.

```sql
CREATE VIEW order_totals AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS total_amount
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.status;
```

Giờ `order_totals` dùng được như một bảng:

```sql
SELECT * FROM order_totals ORDER BY order_id LIMIT 5;
```

| order_id | customer_id | order_date | status | total_amount |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2025-01-12 10:15:00+07 | delivered | 699000 |
| 2 | 2 | 2025-01-20 14:30:00+07 | delivered | 26990000 |
| 3 | 3 | 2025-02-03 09:00:00+07 | delivered | 5780000 |
| 4 | 1 | 2025-02-14 19:45:00+07 | delivered | 7881000 |
| 5 | 4 | 2025-03-02 21:10:00+07 | cancelled | 32990000 |

Bạn có thể lọc, nhóm, JOIN view với bảng khác như bình thường:

```sql
SELECT status, COUNT(*) AS so_don, SUM(total_amount) AS doanh_thu
FROM order_totals
GROUP BY status
ORDER BY doanh_thu DESC;
```

| status | so_don | doanh_thu |
| --- | --- | --- |
| delivered | 33 | 478681000 |
| paid | 2 | 47970000 |
| cancelled | 3 | 38170000 |
| shipped | 1 | 9640000 |
| pending | 1 | 4890000 |

Điều quan trọng nhất cần nhớ: **view thường không chứa dữ liệu**. PostgreSQL chỉ lưu câu `SELECT`. Mỗi lần bạn truy vấn `order_totals`, PostgreSQL thay tên view bằng câu `SELECT` đã lưu rồi chạy trên bảng gốc. Vì vậy:

- Dữ liệu qua view luôn mới nhất: thêm một đơn vào `orders` thì view thấy ngay.
- View **không làm truy vấn nhanh hơn**. Truy vấn qua view tốn công đúng bằng khi bạn tự viết lại đoạn JOIN và GROUP BY đó.

Ích lợi của view nằm ở chỗ khác:

| Ích lợi | Ví dụ trong DSC Shop |
| --- | --- |
| Viết một lần, dùng nhiều nơi | Công thức tổng tiền đơn chỉ nằm trong `order_totals`, mọi báo cáo gọi lại nó |
| Che bớt độ phức tạp | Người làm báo cáo không cần biết `order_items` có cột `discount` |
| Giới hạn những gì người khác thấy | View chỉ có tên và thành phố khách, không có email và số điện thoại |
| Giữ "giao diện" ổn định | Đổi cấu trúc bảng bên dưới, sửa view cho khớp, các truy vấn dùng view không phải sửa |

## Xem, sửa và xóa view

### Xem danh sách và định nghĩa

Trong psql, `\dv` liệt kê các view:

```sql
\dv
```

| Schema | Name | Type | Owner |
| --- | --- | --- | --- |
| shop | order_totals | view | postgres |

Xem lại câu `SELECT` của view bằng `\d+ order_totals` hoặc hàm `pg_get_viewdef`:

```sql
SELECT pg_get_viewdef('order_totals', true);
```

```text
 SELECT o.order_id,
    o.customer_id,
    o.order_date,
    o.status,
    round(sum(oi.quantity::numeric * oi.unit_price * (1::numeric - oi.discount))) AS total_amount
   FROM orders o
     JOIN order_items oi ON oi.order_id = o.order_id
  GROUP BY o.order_id, o.customer_id, o.order_date, o.status;
```

PostgreSQL lưu câu truy vấn ở dạng đã phân tích, nên khi in ra nó viết lại theo kiểu của nó (chữ thường, thêm ép kiểu `::numeric`). Ý nghĩa không đổi.

### View dựng trên view

View có thể dùng view khác. Ví dụ tổng chi tiêu của từng khách. Theo quy ước của khóa học, chỉ tính đơn đã thanh toán, tức bỏ đơn `pending` (chưa trả tiền) và `cancelled` (đã hủy); đây cũng là cách tính doanh thu trong mọi bài:

```sql
CREATE VIEW customer_spending AS
SELECT
    c.customer_id,
    c.full_name,
    COUNT(t.order_id)                AS order_count,
    COALESCE(SUM(t.total_amount), 0) AS total_spent
FROM customers AS c
LEFT JOIN order_totals AS t
       ON t.customer_id = c.customer_id
      AND t.status NOT IN ('pending', 'cancelled')
GROUP BY c.customer_id, c.full_name;
```

Hai chi tiết đáng chú ý:

- `LEFT JOIN` giữ lại khách chưa mua gì. Nếu dùng `JOIN`, khách 16 và 17 biến mất khỏi view.
- Điều kiện `t.status NOT IN ('pending', 'cancelled')` đặt ở `ON` chứ không ở `WHERE`. Đặt ở `WHERE` sẽ loại luôn khách chỉ có đơn chưa thanh toán hoặc đã hủy, biến LEFT JOIN thành INNER JOIN (đã gặp ở [Ngày 10](10-join.md)).

```sql
SELECT * FROM customer_spending ORDER BY total_spent DESC LIMIT 5;
```

| customer_id | full_name | order_count | total_spent |
| --- | --- | --- | --- |
| 10 | Dương Minh Khoa | 2 | 63220500 |
| 15 | Nguyễn Văn An | 2 | 58970000 |
| 2 | Trần Thị Bình | 4 | 58262500 |
| 18 | Mai Đức Uy | 2 | 46980000 |
| 14 | Huỳnh Tấn Phát | 2 | 45880500 |

```sql
SELECT * FROM customer_spending WHERE order_count = 0;
```

| customer_id | full_name | order_count | total_spent |
| --- | --- | --- | --- |
| 16 | Tạ Quang Sơn | 0 | 0 |
| 17 | Châu Ngọc Trâm | 0 | 0 |

### Sửa view: `CREATE OR REPLACE VIEW`

Muốn thêm cột `channel` vào `order_totals`, cách tự nhiên là chèn nó vào giữa:

```sql
CREATE OR REPLACE VIEW order_totals AS
SELECT
    o.order_id,
    o.customer_id,
    o.channel,
    o.order_date,
    o.status,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS total_amount
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.channel, o.order_date, o.status;
```

```text
ERROR:  cannot change name of view column "order_date" to "channel"
HINT:  Use ALTER VIEW ... RENAME COLUMN ... to change name of view column instead.
```

PostgreSQL có luật chặt: `CREATE OR REPLACE VIEW` phải giữ nguyên tên, thứ tự và kiểu của mọi cột cũ, **chỉ được thêm cột mới ở cuối**. Cách đúng:

```sql
CREATE OR REPLACE VIEW order_totals AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS total_amount,
    o.channel,
    COUNT(*) AS item_lines
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.status, o.channel;

SELECT * FROM order_totals WHERE order_id IN (12, 31);
```

| order_id | customer_id | order_date | status | total_amount | channel | item_lines |
| --- | --- | --- | --- | --- | --- | --- |
| 12 | 10 | 2025-06-30 22:05:00+07 | delivered | 31880000 | online | 2 |
| 31 | 4 | 2026-04-01 08:15:00+07 | delivered | 4779000 | online | 3 |

Muốn đổi thứ tự cột, bỏ cột hoặc đổi kiểu thì phải `DROP VIEW` rồi `CREATE VIEW` lại. Đổi tên cột hoặc tên view thì dùng `ALTER VIEW ... RENAME`.

> **Ghi chú dialect:** MySQL có `CREATE OR REPLACE VIEW` và cho thay cả danh sách cột. SQL Server không có `CREATE OR REPLACE VIEW`, thay vào đó dùng `ALTER VIEW` hoặc `CREATE OR ALTER VIEW` (từ SQL Server 2016 SP1).

### Xóa view

```sql
DROP VIEW order_totals;
```

```text
ERROR:  cannot drop view order_totals because other objects depend on it
DETAIL:  view customer_spending depends on view order_totals
HINT:  Use DROP ... CASCADE to drop the dependent objects too.
```

PostgreSQL không cho xóa view khi `customer_spending` đang dựa vào nó. Bạn có hai lựa chọn: xóa view phụ thuộc trước (`DROP VIEW customer_spending; DROP VIEW order_totals;`), hoặc dùng `DROP VIEW order_totals CASCADE;` để xóa cả hai. Hãy đọc kỹ danh sách trong `DETAIL` trước khi dùng `CASCADE`, vì nó xóa luôn mọi thứ phụ thuộc. Khi viết script chạy lại nhiều lần, dùng `DROP VIEW IF EXISTS`.

Các ví dụ phía sau dùng `order_totals` bản 5 cột ở đầu bài. Nếu bạn đã thêm `channel` và `item_lines`, chạy lại như sau:

```sql
DROP VIEW IF EXISTS customer_spending;
DROP VIEW IF EXISTS order_totals;

CREATE VIEW order_totals AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS total_amount
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.status;

CREATE VIEW customer_spending AS
SELECT
    c.customer_id,
    c.full_name,
    COUNT(t.order_id)                AS order_count,
    COALESCE(SUM(t.total_amount), 0) AS total_spent
FROM customers AS c
LEFT JOIN order_totals AS t
       ON t.customer_id = c.customer_id
      AND t.status NOT IN ('pending', 'cancelled')
GROUP BY c.customer_id, c.full_name;
```

## Cập nhật dữ liệu qua view

### View nào cập nhật được?

PostgreSQL tự cho `INSERT`, `UPDATE`, `DELETE` qua view nếu view đủ "đơn giản" để biết chắc mỗi dòng của view ứng với đúng một dòng của một bảng gốc. Cụ thể, view phải:

- có đúng một bảng (hoặc một view cập nhật được) trong `FROM`, không JOIN;
- không có `GROUP BY`, `HAVING`, `DISTINCT`, hàm tổng hợp, `LIMIT`/`OFFSET`, `UNION`/`INTERSECT`/`EXCEPT`.

Cột tính toán (như `SUBSTRING(email, 1, 3) || '***'`) vẫn được phép có trong view, chỉ là bạn không ghi được vào chính cột đó.

Ví dụ một view đơn giản chỉ lấy sản phẩm đang kinh doanh:

```sql
CREATE VIEW active_products AS
SELECT product_id, sku, name, category_id, price, stock_quantity
FROM products
WHERE is_active;
```

Cập nhật qua view thực chất là cập nhật bảng `products`. Các ví dụ dưới đây bọc trong `BEGIN ... ROLLBACK` để không làm đổi dữ liệu gốc:

```sql
BEGIN;

UPDATE active_products
SET price = 4590000
WHERE sku = 'PHN-003';

SELECT sku, name, price FROM products WHERE sku = 'PHN-003';

ROLLBACK;
```

| sku | name | price |
| --- | --- | --- |
| PHN-003 | Xiaomi Redmi Note 13 | 4590000 |

Nokia 105 4G (`PHN-004`) có `is_active = FALSE`, nên nó không nằm trong view. `UPDATE` qua view không "thấy" dòng đó:

```sql
BEGIN;
UPDATE active_products SET price = 1 WHERE sku = 'PHN-004';
ROLLBACK;
```

```text
UPDATE 0
```

`INSERT` qua view cũng được, các cột không có trong view nhận giá trị `DEFAULT` của bảng (`is_active` là `TRUE`, `created_at` là `now()`):

```sql
BEGIN;

INSERT INTO active_products (sku, name, category_id, price, stock_quantity)
VALUES ('ACC-010', 'Hub USB-C 6 cổng', 12, 590000, 25)
RETURNING *;

ROLLBACK;
```

| product_id | sku | name | category_id | price | stock_quantity |
| --- | --- | --- | --- | --- | --- |
| 25 | ACC-010 | Hub USB-C 6 cổng | 12 | 590000 | 25 |

(`product_id` trên máy bạn có thể khác: `ROLLBACK` hủy dòng nhưng không trả lại số đã lấy từ IDENTITY.)

Nếu view thiếu một cột `NOT NULL` không có `DEFAULT` (ví dụ bỏ `category_id` khỏi view), `INSERT` qua view sẽ lỗi vi phạm `NOT NULL`, vì PostgreSQL không có giá trị nào để điền vào cột đó.

Còn `order_totals` có `JOIN` và `GROUP BY` thì không cập nhật được:

```sql
UPDATE order_totals SET status = 'paid' WHERE order_id = 40;
```

```text
ERROR:  cannot update view "order_totals"
DETAIL:  Views containing GROUP BY are not automatically updatable.
HINT:  To enable updating the view, provide an INSTEAD OF UPDATE trigger or an unconditional ON UPDATE DO INSTEAD rule.
```

Điều này hợp lý: một dòng của `order_totals` gộp từ nhiều dòng `order_items`, nên "sửa `total_amount` thành 500" không có nghĩa rõ ràng. Muốn cập nhật trạng thái đơn, hãy `UPDATE orders` trực tiếp. Nếu thật sự cần ghi qua một view phức tạp, bạn viết trigger `INSTEAD OF` (trigger đã học ở [Ngày 18](18-triggers.md)) để tự quyết định ghi vào bảng nào.

Muốn biết nhanh view nào cập nhật được, hỏi `information_schema.views` (xem bài tập 6).

> **Ghi chú dialect:** MySQL và SQL Server cho `UPDATE` qua view có JOIN nếu câu lệnh chỉ sửa cột của một bảng gốc. PostgreSQL thì không: view có JOIN không tự cập nhật được, phải dùng trigger `INSTEAD OF`.

### `WITH CHECK OPTION`: không cho dòng "trốn" khỏi view

Một view sản phẩm giá rẻ:

```sql
CREATE VIEW cheap_products AS
SELECT product_id, sku, name, price
FROM products
WHERE price < 1000000;

SELECT * FROM cheap_products ORDER BY price;
```

| product_id | sku | name | price |
| --- | --- | --- | --- |
| 23 | ACC-008 | Cáp USB-C to USB-C 1m | 150000 |
| 24 | ACC-009 | Lót chuột DSC XXL | 250000 |
| 16 | ACC-001 | Chuột Logitech G102 | 399000 |
| 13 | PHN-004 | Nokia 105 4G | 690000 |
| 22 | ACC-007 | Sạc Anker 65W | 890000 |

Điều gì xảy ra nếu sửa giá sạc Anker thành 1.290.000 qua view này?

```sql
BEGIN;

UPDATE cheap_products SET price = 1290000 WHERE sku = 'ACC-007';

SELECT * FROM cheap_products ORDER BY price;

ROLLBACK;
```

| product_id | sku | name | price |
| --- | --- | --- | --- |
| 23 | ACC-008 | Cáp USB-C to USB-C 1m | 150000 |
| 24 | ACC-009 | Lót chuột DSC XXL | 250000 |
| 16 | ACC-001 | Chuột Logitech G102 | 399000 |
| 13 | PHN-004 | Nokia 105 4G | 690000 |

Lệnh chạy thành công, rồi sạc Anker biến mất khỏi view vì giá không còn dưới 1 triệu. Người dùng view "làm mất" một dòng mà không hề biết. Thêm `WITH CHECK OPTION` để PostgreSQL từ chối mọi `INSERT`/`UPDATE` tạo ra dòng không thỏa `WHERE` của view:

```sql
CREATE OR REPLACE VIEW cheap_products AS
SELECT product_id, sku, name, price
FROM products
WHERE price < 1000000
WITH CHECK OPTION;

UPDATE cheap_products SET price = 1290000 WHERE sku = 'ACC-007';
```

```text
ERROR:  new row violates check option for view "cheap_products"
DETAIL:  Failing row contains (22, ACC-007, Sạc Anker 65W, 12, 1290000, 600000, 40, {"watt": 65, "brand": "Anker"}, t, 2024-11-01 00:00:00+07).
```

Sửa giá mà vẫn dưới 1 triệu thì vẫn được:

```sql
BEGIN;
UPDATE cheap_products SET price = 790000 WHERE sku = 'ACC-007';
ROLLBACK;
```

```text
UPDATE 1
```

Khi view dựng trên view khác, `WITH CASCADED CHECK OPTION` (mặc định khi chỉ viết `WITH CHECK OPTION`) kiểm tra điều kiện của cả view bên dưới, còn `WITH LOCAL CHECK OPTION` chỉ kiểm tra điều kiện của view hiện tại.

## View để giới hạn những gì người khác thấy

Bảng `customers` có email, số điện thoại, ngày sinh. Một bạn thực tập làm báo cáo theo thành phố không cần những thông tin đó. Bạn tạo view chỉ chứa phần cần thiết, và che bớt email:

```sql
CREATE VIEW customer_directory AS
SELECT
    customer_id,
    full_name,
    city,
    SUBSTRING(email, 1, 3) || '***' AS email_hint,
    EXTRACT(YEAR FROM birth_date)  AS birth_year
FROM customers;

SELECT * FROM customer_directory ORDER BY customer_id LIMIT 5;
```

| customer_id | full_name | city | email_hint | birth_year |
| --- | --- | --- | --- | --- |
| 1 | Nguyễn Văn An | TP. Hồ Chí Minh | an.*** | 2002 |
| 2 | Trần Thị Bình | Hà Nội | bin*** | 2001 |
| 3 | Lê Hoàng Cường | Đà Nẵng | cuo*** | 1999 |
| 4 | Phạm Minh Duy | TP. Hồ Chí Minh | duy*** | 2003 |
| 5 | Hoàng Thị Em | Cần Thơ |  |  |

(Khách 5 không có email và ngày sinh, nên hai cột đó là NULL.)

Riêng việc tạo view **chưa bảo vệ được gì**: ai có quyền đọc bảng `customers` vẫn đọc thẳng bảng. View chỉ thành lớp bảo vệ khi kết hợp với phân quyền: cấp cho tài khoản của bạn thực tập quyền `SELECT` trên `customer_directory` (dạng `GRANT SELECT ON customer_directory TO <tài khoản>`) và không cấp quyền nào trên bảng `customers`. PostgreSQL kiểm tra quyền trên bảng gốc theo chủ sở hữu view, nên người đó đọc được view mà không đọc được bảng. Cách tạo tài khoản (role), `GRANT` và `REVOKE` sẽ học kỹ ở [Ngày 30](30-database-security.md).

## Materialized view: lưu sẵn kết quả

### Ý tưởng

View thường tính lại mọi thứ mỗi lần truy vấn. Với một báo cáo doanh thu theo tháng chạy trên hàng triệu đơn, việc đó tốn vài trăm mili giây mỗi lần, trong khi số liệu tháng trước gần như không đổi. **Materialized view** chạy truy vấn một lần, **ghi kết quả ra đĩa như một bảng thật**, rồi các truy vấn sau chỉ đọc bản lưu đó. Đổi lại, bản lưu không tự cập nhật: bạn phải ra lệnh làm mới.

![Hai cột so sánh. Bên trái là view thường order_totals: truy vấn SELECT * FROM order_totals được viết lại thành câu SELECT đã lưu (view không chứa dòng nào), câu đó chạy mỗi lần trên bảng gốc orders và order_items, JOIN và GROUP BY lại từ đầu, nên kết quả luôn mới nhưng tốn công như tự viết truy vấn. Bên phải là materialized view monthly_revenue: lệnh REFRESH MATERIALIZED VIEW chạy truy vấn một lần trên bảng gốc và ghi kết quả thành bản lưu trên đĩa gồm 22 dòng, tạo index được; truy vấn SELECT * FROM monthly_revenue đọc thẳng bản lưu nên rất nhanh nhưng chỉ mới tới lần REFRESH gần nhất.](img/view-va-materialized-view.png#gh-light-mode-only)
![Hai cột so sánh. Bên trái là view thường order_totals: truy vấn SELECT * FROM order_totals được viết lại thành câu SELECT đã lưu (view không chứa dòng nào), câu đó chạy mỗi lần trên bảng gốc orders và order_items, JOIN và GROUP BY lại từ đầu, nên kết quả luôn mới nhưng tốn công như tự viết truy vấn. Bên phải là materialized view monthly_revenue: lệnh REFRESH MATERIALIZED VIEW chạy truy vấn một lần trên bảng gốc và ghi kết quả thành bản lưu trên đĩa gồm 22 dòng, tạo index được; truy vấn SELECT * FROM monthly_revenue đọc thẳng bản lưu nên rất nhanh nhưng chỉ mới tới lần REFRESH gần nhất.](img/view-va-materialized-view-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/views/view-va-materialized-view.html) · [nền tối](../diagrams/views/view-va-materialized-view-dark.html)</small>

### Tạo và truy vấn

```sql
CREATE MATERIALIZED VIEW monthly_revenue AS
SELECT
    DATE_TRUNC('month', order_date)::DATE AS month,
    COUNT(*)                              AS order_count,
    SUM(total_amount)                     AS revenue
FROM order_totals
WHERE status NOT IN ('pending', 'cancelled')
GROUP BY DATE_TRUNC('month', order_date)::DATE;
```

```text
SELECT 22
```

PostgreSQL chạy truy vấn ngay lúc tạo và lưu 22 dòng (mỗi tháng có ít nhất một đơn đã thanh toán là một dòng). Trong psql, `\dm` liệt kê các materialized view.

```sql
SELECT * FROM monthly_revenue WHERE month >= '2026-06-01' ORDER BY month;
```

| month | order_count | revenue |
| --- | --- | --- |
| 2026-06-01 | 1 | 1640000 |
| 2026-07-01 | 1 | 17091000 |
| 2026-08-01 | 1 | 29990000 |
| 2026-09-01 | 2 | 17630000 |
| 2026-10-01 | 1 | 39980000 |

### Dữ liệu cũ và `REFRESH`

Thử thêm một đơn mới trong tháng 10/2026 (bọc trong transaction để hủy sau):

```sql
BEGIN;

INSERT INTO orders (customer_id, order_date, status, channel, shipping_city)
VALUES (16, '2026-10-16 10:00+07', 'paid', 'online', 'Cần Thơ');

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES ((SELECT MAX(order_id) FROM orders), 17, 1, 2490000);

-- View thường thấy ngay đơn mới
SELECT COUNT(*) AS order_count, SUM(total_amount) AS revenue
FROM order_totals
WHERE status NOT IN ('pending', 'cancelled')
  AND order_date >= '2026-10-01';

-- Materialized view vẫn là số cũ
SELECT * FROM monthly_revenue WHERE month = '2026-10-01';

REFRESH MATERIALIZED VIEW monthly_revenue;

-- Sau REFRESH thì khớp
SELECT * FROM monthly_revenue WHERE month = '2026-10-01';

ROLLBACK;
```

Ba kết quả lần lượt là:

| order_count | revenue |
| --- | --- |
| 2 | 42470000 |

| month | order_count | revenue |
| --- | --- | --- |
| 2026-10-01 | 1 | 39980000 |

| month | order_count | revenue |
| --- | --- | --- |
| 2026-10-01 | 2 | 42470000 |

`REFRESH` cũng nằm trong transaction, nên sau `ROLLBACK` materialized view quay về số cũ (1 đơn, 39.980.000).

`REFRESH MATERIALIZED VIEW` khóa materialized view trong lúc làm mới, ai đang đọc phải chờ. Với `CONCURRENTLY`, PostgreSQL tính kết quả mới ở bên cạnh rồi đổi từng dòng, người khác vẫn đọc được trong lúc đó. Điều kiện là materialized view phải có một **UNIQUE index** (không có `WHERE`):

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_revenue;
```

```text
ERROR:  cannot refresh materialized view "shop.monthly_revenue" concurrently
HINT:  Create a unique index with no WHERE clause on one or more columns of the materialized view.
```

```sql
CREATE UNIQUE INDEX ON monthly_revenue (month);

REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_revenue;
```

```text
CREATE INDEX
REFRESH MATERIALIZED VIEW
```

Vì materialized view là dữ liệu thật trên đĩa, bạn tạo index trên nó được như trên bảng. View thường thì không.

PostgreSQL không tự `REFRESH`. Trong thực tế, người ta gọi `REFRESH` theo lịch (cron, extension `pg_cron`, hoặc job của ứng dụng), ví dụ mỗi đêm hoặc mỗi 15 phút, tùy báo cáo chấp nhận số liệu cũ đến mức nào.

### Đo trên dữ liệu lớn

Trên 40 đơn của DSC Shop, view hay materialized view đều nhanh. Khác biệt chỉ lộ ra trên schema `perf` (1 triệu đơn, xem [setup/README.md](../setup/README.md) nếu chưa nạp). `\timing on` của psql in thời gian chạy mỗi câu lệnh:

```sql
CREATE VIEW perf.monthly_revenue_v AS
SELECT
    DATE_TRUNC('month', order_date)::DATE AS month,
    COUNT(*)                              AS order_count,
    SUM(total_amount)                     AS revenue
FROM perf.orders
WHERE status NOT IN ('pending', 'cancelled')
GROUP BY DATE_TRUNC('month', order_date)::DATE;

CREATE MATERIALIZED VIEW perf.monthly_revenue_mv AS
SELECT * FROM perf.monthly_revenue_v;

\timing on
SELECT * FROM perf.monthly_revenue_v  WHERE month = '2025-06-01';
SELECT * FROM perf.monthly_revenue_mv WHERE month = '2025-06-01';
REFRESH MATERIALIZED VIEW perf.monthly_revenue_mv;
\timing off
```

Cả hai truy vấn trả về cùng một dòng:

| month | order_count | revenue |
| --- | --- | --- |
| 2025-06-01 | 19955 | 301134916000 |

Thời gian đo trên máy mình (PostgreSQL 16 trong Docker, chạy mỗi câu 5 lần):

| Câu lệnh | Thời gian |
| --- | --- |
| Đọc view thường `monthly_revenue_v` | khoảng 100-220 ms |
| Tự viết lại truy vấn GROUP BY trên `perf.orders` (không qua view) | khoảng 95-150 ms |
| Đọc materialized view `monthly_revenue_mv` (46 dòng) | dưới 1 ms |
| `REFRESH MATERIALIZED VIEW` | khoảng 340-620 ms |

Số trên máy bạn sẽ khác, nhưng tỉ lệ thì tương tự: view thường tốn ngang truy vấn gốc (phải quét cả triệu đơn), materialized view nhanh hơn hàng trăm lần, còn cái giá phải trả là mỗi lần `REFRESH` tốn công hơn một lần chạy truy vấn gốc.

Dọn dẹp sau khi đo, để schema `perf` sạch cho các bài sau:

```sql
DROP MATERIALIZED VIEW perf.monthly_revenue_mv;
DROP VIEW perf.monthly_revenue_v;
```

### Chọn view hay materialized view?

| | View thường | Materialized view |
| --- | --- | --- |
| Lưu gì | Câu `SELECT` | Câu `SELECT` và kết quả |
| Dữ liệu | Luôn mới | Mới tới lần `REFRESH` gần nhất |
| Tốc độ đọc | Như truy vấn gốc | Như đọc một bảng nhỏ |
| Tạo index | Không | Được |
| Ghi qua view | Được, nếu view đơn giản | Không |
| Hợp với | Gói truy vấn hay dùng, che cột | Báo cáo nặng, dashboard chấp nhận số liệu trễ |

> **Ghi chú dialect:** MySQL không có materialized view (thường thay bằng bảng tổng hợp tự cập nhật). SQL Server có indexed view: tạo `UNIQUE CLUSTERED INDEX` trên view thì SQL Server lưu kết quả và tự cập nhật khi bảng gốc đổi, đổi lại có nhiều giới hạn về cú pháp.

## Lỗi thường gặp

**1. Nghĩ rằng view làm truy vấn nhanh hơn.** View thường chỉ là truy vấn được đặt tên; PostgreSQL vẫn chạy toàn bộ JOIN và GROUP BY bên dưới. Truy vấn chậm thì xem index ([Ngày 15](15-index.md)) và plan ([Ngày 20](20-query-performance.md)), hoặc cân nhắc materialized view nếu chấp nhận số liệu trễ.

**2. Chèn cột vào giữa khi `CREATE OR REPLACE VIEW`.** Báo lỗi `cannot change name of view column`. Thêm cột mới ở cuối, hoặc `DROP VIEW` rồi tạo lại.

**3. `SELECT *` trong view không tự có cột mới.** Khi tạo view, PostgreSQL thay `*` bằng danh sách cột lúc đó. Sau này bảng có thêm cột thì view không thấy. Liệt kê cột rõ ràng trong view để tránh bất ngờ, và tạo lại view khi muốn thêm cột.

**4. Dùng `JOIN` làm mất dòng trong view tổng hợp.** View tổng chi tiêu viết bằng `JOIN` sẽ không có khách chưa mua gì:

```sql
-- Sai: khách 16, 17 không có trong kết quả
SELECT c.customer_id, c.full_name, SUM(t.total_amount) AS total_spent
FROM customers AS c
JOIN order_totals AS t ON t.customer_id = c.customer_id
WHERE c.customer_id IN (16, 17)
GROUP BY c.customer_id, c.full_name;
```

Kết quả rỗng (0 dòng). Dùng `LEFT JOIN` và `COALESCE(SUM(...), 0)` như `customer_spending`.

**5. Cập nhật qua view làm dòng "biến mất".** Không có `WITH CHECK OPTION`, `UPDATE` qua view có thể sửa dòng sao cho nó không còn thỏa `WHERE` của view. Thêm `WITH CHECK OPTION` cho view dùng để ghi.

**6. Quên `REFRESH` materialized view.** Báo cáo hiện số cũ mà không báo lỗi gì. Ghi rõ lịch làm mới, và cân nhắc thêm cột thời điểm tính (ví dụ `now() AS refreshed_at`) vào materialized view để người xem biết số liệu tính lúc nào.

**7. Tưởng view đã bảo vệ dữ liệu.** View che cột chỉ có tác dụng khi người dùng không có quyền đọc bảng gốc. Phân quyền học ở Ngày 30.

## Bài tập

Các bài tập dùng `order_totals` và `customer_spending` bản ở đầu bài. Nếu cần làm lại từ đầu, chạy lại script init (xem mục "Làm lại từ đầu" trong [setup/README.md](../setup/README.md)) rồi tạo lại hai view đó.

### Cơ bản

**Bài 1.** Tạo view `product_catalog` gồm `sku`, tên sản phẩm (`product_name`), tên danh mục (`category_name`), `price`, `stock_quantity`, chỉ lấy sản phẩm đang kinh doanh và còn hàng. Dùng view để liệt kê điện thoại (danh mục `Điện thoại`), giá giảm dần.

<details>
<summary>Đáp án</summary>

```sql
CREATE VIEW product_catalog AS
SELECT
    p.sku,
    p.name AS product_name,
    c.name AS category_name,
    p.price,
    p.stock_quantity
FROM products AS p
JOIN categories AS c ON c.category_id = p.category_id
WHERE p.is_active
  AND p.stock_quantity > 0;

SELECT sku, product_name, price, stock_quantity
FROM product_catalog
WHERE category_name = 'Điện thoại'
ORDER BY price DESC;
```

Kết quả:

| sku | product_name | price | stock_quantity |
| --- | --- | --- | --- |
| PHN-001 | iPhone 15 128GB | 19990000 | 15 |
| PHN-002 | Samsung Galaxy S24 | 18990000 | 9 |
| PHN-003 | Xiaomi Redmi Note 13 | 4890000 | 25 |

Nokia 105 4G không xuất hiện vì vừa ngừng kinh doanh vừa hết hàng.
</details>

**Bài 2.** Tạo view `employee_sales` cho biết mỗi nhân viên đã bán bao nhiêu đơn offline (không tính đơn `pending` và `cancelled`) và tổng doanh thu, giữ cả nhân viên chưa bán đơn nào (doanh thu 0). Sắp xếp theo doanh thu giảm dần.

<details>
<summary>Đáp án</summary>

```sql
CREATE VIEW employee_sales AS
SELECT
    e.employee_id,
    e.full_name,
    COUNT(t.order_id)                AS order_count,
    COALESCE(SUM(t.total_amount), 0) AS revenue
FROM employees AS e
LEFT JOIN orders AS o
       ON o.employee_id = e.employee_id
LEFT JOIN order_totals AS t
       ON t.order_id = o.order_id
      AND t.status NOT IN ('pending', 'cancelled')
GROUP BY e.employee_id, e.full_name;

SELECT * FROM employee_sales ORDER BY revenue DESC;
```

Kết quả:

| employee_id | full_name | order_count | revenue |
| --- | --- | --- | --- |
| 6 | Vũ Hoài Nam | 4 | 82907500 |
| 4 | Phạm Thị Thu | 5 | 63700000 |
| 5 | Đỗ Minh Tuấn | 5 | 63401000 |
| 8 | Kiều Anh Thư | 1 | 1640000 |
| 2 | Lê Thị Hạnh | 0 | 0 |
| 3 | Trần Quốc Bảo | 0 | 0 |
| 7 | Lâm Gia Huy | 0 | 0 |
| 1 | Nguyễn Thành Long | 0 | 0 |

Cả hai lần JOIN đều phải là `LEFT JOIN`; chỉ cần một `JOIN` thường là bốn nhân viên chưa bán hàng biến mất.
</details>

**Bài 3.** Thêm cột `channel` vào view `order_totals` mà không làm lỗi và không phải xóa `customer_spending`. Sau đó dùng view tính số đơn và doanh thu (không tính đơn `pending` và `cancelled`) theo kênh bán.

<details>
<summary>Đáp án</summary>

Thêm `channel` ở **cuối** danh sách cột:

```sql
CREATE OR REPLACE VIEW order_totals AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.status,
    ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS total_amount,
    o.channel
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date, o.status, o.channel;

SELECT channel, COUNT(*) AS order_count, SUM(total_amount) AS revenue
FROM order_totals
WHERE status NOT IN ('pending', 'cancelled')
GROUP BY channel;
```

Kết quả:

| channel | order_count | revenue |
| --- | --- | --- |
| online | 21 | 324642500 |
| offline | 15 | 211648500 |

`customer_spending` vẫn chạy bình thường vì các cột nó dùng không đổi.
</details>

### Vận dụng

**Bài 4.** Tạo view `hcm_customers` gồm `customer_id`, `full_name`, `email`, `phone`, `city` của khách ở TP. Hồ Chí Minh (dữ liệu có ba cách viết: `TP. Hồ Chí Minh`, `Hồ Chí Minh`, `TP.HCM`). View phải chặn việc thêm qua nó một khách ở thành phố khác. Thử thêm khách `Lê Thị Hoa` ở `Hà Nội` rồi ở `TP. Hồ Chí Minh`.

<details>
<summary>Đáp án</summary>

```sql
CREATE VIEW hcm_customers AS
SELECT customer_id, full_name, email, phone, city
FROM customers
WHERE city IN ('TP. Hồ Chí Minh', 'Hồ Chí Minh', 'TP.HCM')
WITH CHECK OPTION;

SELECT customer_id, full_name, city FROM hcm_customers ORDER BY customer_id;
```

| customer_id | full_name | city |
| --- | --- | --- |
| 1 | Nguyễn Văn An | TP. Hồ Chí Minh |
| 4 | Phạm Minh Duy | TP. Hồ Chí Minh |
| 6 | Võ Quốc Phong | Hồ Chí Minh |
| 10 | Dương Minh Khoa | TP. Hồ Chí Minh |
| 14 | Huỳnh Tấn Phát | TP.HCM |

```sql
INSERT INTO hcm_customers (full_name, email, city)
VALUES ('Lê Thị Hoa', 'hoa.le@gmail.com', 'Hà Nội');
```

```text
ERROR:  new row violates check option for view "hcm_customers"
```

```sql
BEGIN;

INSERT INTO hcm_customers (full_name, email, city)
VALUES ('Lê Thị Hoa', 'hoa.le@gmail.com', 'TP. Hồ Chí Minh')
RETURNING customer_id, full_name, city;

ROLLBACK;
```

Lệnh thứ hai thành công (trả về một dòng với `city = 'TP. Hồ Chí Minh'`); `ROLLBACK` hủy nó để giữ dữ liệu gốc.
</details>

**Bài 5.** Dựa trên `customer_spending`, tạo view `vip_customers` gồm khách có tổng chi tiêu từ 50 triệu trở lên. Liệt kê theo chi tiêu giảm dần.

<details>
<summary>Đáp án</summary>

```sql
CREATE VIEW vip_customers AS
SELECT *
FROM customer_spending
WHERE total_spent >= 50000000;

SELECT * FROM vip_customers ORDER BY total_spent DESC;
```

Kết quả:

| customer_id | full_name | order_count | total_spent |
| --- | --- | --- | --- |
| 10 | Dương Minh Khoa | 2 | 63220500 |
| 15 | Nguyễn Văn An | 2 | 58970000 |
| 2 | Trần Thị Bình | 4 | 58262500 |

Lưu ý: `SELECT *` ở đây được PostgreSQL thay bằng 4 cột của `customer_spending` lúc tạo view (lỗi thường gặp số 3).
</details>

**Bài 6.** Không cần thử từng lệnh `UPDATE`, hãy liệt kê mọi view trong schema `shop` và cho biết view nào cập nhật được, view nào `INSERT` được. Giải thích vì sao `customer_directory` cập nhật được dù có cột tính toán.

<details>
<summary>Đáp án</summary>

```sql
SELECT table_name, is_updatable, is_insertable_into
FROM information_schema.views
WHERE table_schema = 'shop'
ORDER BY table_name;
```

Kết quả (nếu bạn đã tạo đủ các view trong bài):

| table_name | is_updatable | is_insertable_into |
| --- | --- | --- |
| active_products | YES | YES |
| cheap_products | YES | YES |
| customer_directory | YES | YES |
| customer_spending | NO | NO |
| employee_sales | NO | NO |
| hcm_customers | YES | YES |
| order_totals | NO | NO |
| product_catalog | NO | NO |
| vip_customers | NO | NO |

`customer_directory` chỉ đọc từ một bảng, không JOIN, không GROUP BY, nên mỗi dòng view ứng với đúng một dòng `customers`. Bạn sửa được `full_name`, `city` qua view; chỉ riêng `email_hint` và `birth_year` là cột tính toán nên không ghi vào được. `product_catalog` không cập nhật được vì có JOIN, các view còn lại vì có GROUP BY (hoặc dựng trên view có GROUP BY).
</details>

### Thử thách

**Bài 7.** Tạo materialized view `product_sales` gồm `product_id`, `sku`, `name`, `units_sold`, `revenue` cho **mọi** sản phẩm (sản phẩm chưa bán có 0), chỉ tính đơn đã thanh toán (không tính `pending` và `cancelled`). Tạo index để làm mới được bằng `CONCURRENTLY`. In top 5 theo doanh thu. Sau đó, trong một transaction, thêm 2 cái `Lót chuột DSC XXL` (product_id 24, giá 250.000) vào đơn 38 (đơn đã thanh toán), cho thấy materialized view chỉ cập nhật sau khi `REFRESH`, rồi `ROLLBACK`.

<details>
<summary>Đáp án</summary>

Lọc trạng thái đơn trong subquery trước, rồi mới `LEFT JOIN` vào `products`. Nếu `LEFT JOIN` thẳng `order_items` và `orders` rồi lọc `status` ở `WHERE`, sản phẩm chưa bán (có `status` NULL) sẽ bị loại.

```sql
CREATE MATERIALIZED VIEW product_sales AS
SELECT
    p.product_id,
    p.sku,
    p.name,
    COALESCE(s.units_sold, 0) AS units_sold,
    COALESCE(s.revenue, 0)    AS revenue
FROM products AS p
LEFT JOIN (
    SELECT
        oi.product_id,
        SUM(oi.quantity) AS units_sold,
        ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS revenue
    FROM order_items AS oi
    JOIN orders AS o ON o.order_id = oi.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY oi.product_id
) AS s ON s.product_id = p.product_id;

CREATE UNIQUE INDEX ON product_sales (product_id);

SELECT sku, name, units_sold, revenue
FROM product_sales
ORDER BY revenue DESC
LIMIT 5;
```

| sku | name | units_sold | revenue |
| --- | --- | --- | --- |
| PHN-001 | iPhone 15 128GB | 4 | 78960500 |
| LAP-002 | Lenovo Legion 5 | 2 | 59980000 |
| LAP-005 | MacBook Air M2 13 inch | 2 | 50730500 |
| LAP-003 | Acer Nitro V 15 | 2 | 43830500 |
| LAP-004 | Dell Inspiron 14 | 2 | 36980000 |

```sql
BEGIN;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (38, 24, 2, 250000);

SELECT sku, units_sold, revenue FROM product_sales WHERE sku = 'ACC-009';

REFRESH MATERIALIZED VIEW CONCURRENTLY product_sales;

SELECT sku, units_sold, revenue FROM product_sales WHERE sku = 'ACC-009';

ROLLBACK;
```

Trước `REFRESH`:

| sku | units_sold | revenue |
| --- | --- | --- |
| ACC-009 | 0 | 0 |

Sau `REFRESH`:

| sku | units_sold | revenue |
| --- | --- | --- |
| ACC-009 | 2 | 500000 |
</details>

**Bài 8.** Trên schema `perf`, tạo view `perf.city_revenue_v` tính số đơn và doanh thu (không tính đơn `pending` và `cancelled`) theo thành phố của khách (JOIN `perf.orders` với `perf.customers`), và materialized view `perf.city_revenue_mv` từ view đó. Dùng `\timing` so sánh thời gian lấy top 3 thành phố qua hai cách và thời gian `REFRESH`. Xong thì xóa cả hai.

<details>
<summary>Đáp án</summary>

```sql
CREATE VIEW perf.city_revenue_v AS
SELECT
    c.city,
    COUNT(*)            AS order_count,
    SUM(o.total_amount) AS revenue
FROM perf.orders AS o
JOIN perf.customers AS c ON c.customer_id = o.customer_id
WHERE o.status NOT IN ('pending', 'cancelled')
GROUP BY c.city;

CREATE MATERIALIZED VIEW perf.city_revenue_mv AS
SELECT * FROM perf.city_revenue_v;

\timing on
SELECT * FROM perf.city_revenue_v  ORDER BY revenue DESC LIMIT 3;
SELECT * FROM perf.city_revenue_mv ORDER BY revenue DESC LIMIT 3;
REFRESH MATERIALIZED VIEW perf.city_revenue_mv;
\timing off

DROP MATERIALIZED VIEW perf.city_revenue_mv;
DROP VIEW perf.city_revenue_v;
```

Hai truy vấn trả cùng kết quả:

| city | order_count | revenue |
| --- | --- | --- |
| Quy Nhơn | 92899 | 1399739509000 |
| Vũng Tàu | 91947 | 1390873509000 |
| Nha Trang | 91954 | 1387547305000 |

Thời gian trên máy mình: qua view khoảng 180-215 ms, qua materialized view khoảng 0,2-0,5 ms, `REFRESH` khoảng 210 ms. Máy bạn sẽ ra số khác. Kết luận: nếu báo cáo này được mở hàng nghìn lần mỗi ngày và chấp nhận số liệu trễ vài phút, materialized view làm mới định kỳ tiết kiệm rất nhiều; nếu cần số liệu tức thời, dùng view thường (và tối ưu truy vấn bên dưới).
</details>

## Tóm tắt

- View là truy vấn được đặt tên. View thường không lưu dữ liệu, mỗi lần đọc PostgreSQL chạy lại truy vấn gốc, nên dữ liệu luôn mới nhưng không nhanh hơn.
- `CREATE OR REPLACE VIEW` trong PostgreSQL chỉ được thêm cột ở cuối; muốn đổi nhiều hơn thì `DROP VIEW` rồi tạo lại. `DROP VIEW` báo lỗi khi có đối tượng phụ thuộc, `CASCADE` xóa luôn chúng.
- View một bảng, không GROUP BY/DISTINCT/JOIN thì cập nhật được. `WITH CHECK OPTION` chặn ghi dữ liệu nằm ngoài điều kiện của view. View phức tạp cần trigger `INSTEAD OF`.
- View giúp che cột nhạy cảm, nhưng chỉ có tác dụng bảo vệ khi đi kèm phân quyền (Ngày 30).
- Materialized view lưu kết quả ra đĩa: đọc rất nhanh, tạo index được, nhưng phải `REFRESH` (thêm `CONCURRENTLY` và UNIQUE index để không chặn người đọc).

## Đọc thêm

- [PostgreSQL: CREATE VIEW](https://www.postgresql.org/docs/16/sql-createview.html) (mục "Updatable Views")
- [PostgreSQL: Materialized Views](https://www.postgresql.org/docs/16/rules-materializedviews.html)
- [PostgreSQL: REFRESH MATERIALIZED VIEW](https://www.postgresql.org/docs/16/sql-refreshmaterializedview.html)

---

[⬅️ Ngày 18: Trigger](18-triggers.md) | [📚 Mục lục](../README.md) | [Ngày 20: Đọc kế hoạch thực thi với EXPLAIN ➡️](20-query-performance.md)
