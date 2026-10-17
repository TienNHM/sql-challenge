# Ngày 21: Ôn tập 3 (Ngày 15-20)

> **Tóm tắt:** Bài ôn tập chặng 3: index, transaction, function và procedure, trigger, view, đọc plan bằng `EXPLAIN`. Phần đầu là bảng tóm tắt và câu hỏi kiểm tra khái niệm, phần sau là 10 bài tập chạy trên DSC Shop (schema `shop`) và dữ liệu lớn (schema `perf`), có đáp án và số đo thật.

**Sau bài này bạn có thể:**

- Đo một truy vấn trên 1 triệu dòng bằng `EXPLAIN ANALYZE` trước và sau khi tạo index, và giải thích vì sao plan thay đổi.
- Chọn đúng loại index (một cột, nhiều cột, partial) cho một truy vấn và nhận ra khi nào index không được dùng.
- Viết một quy trình đặt hàng an toàn bằng transaction, rồi gói nó thành procedure PL/pgSQL có kiểm tra lỗi.
- Nhận ra xung đột giữa trigger và code ứng dụng (trừ kho hai lần) và chọn một nơi duy nhất cho mỗi quy tắc.
- Dùng view để gói truy vấn JOIN nhiều bảng và viết điều kiện thời gian bằng khoảng nửa mở.

**Cần biết trước:** [Ngày 15](15-index.md), [Ngày 16](16-transactions-acid.md), [Ngày 17](17-stored-procedures-functions.md), [Ngày 18](18-triggers.md), [Ngày 19](19-views.md), [Ngày 20](20-query-performance.md).

## Chuẩn bị

- Database DSC Shop ở trạng thái gốc. Nếu đã sửa dữ liệu ở các bài trước, chạy lại script init (mục "Làm lại từ đầu" trong [setup/README.md](../setup/README.md)).
- Schema `perf` (100.000 khách, 1.000.000 đơn) đã được nạp bằng `setup/perf_seed.sql`. Bảng `perf.orders` chỉ có index khóa chính.
- Mọi bài tập sửa dữ liệu shop đều kết thúc bằng `ROLLBACK`, và mọi index tạo trên `perf` đều được xóa ở cuối bài, để bài sau chạy trên cùng một trạng thái.

## Tóm tắt kiến thức chặng 3

| Ngày | Chủ đề | Ý chính cần nhớ |
| --- | --- | --- |
| 15 | Index | B-tree giúp tìm ít dòng trong bảng lớn. Index nhiều cột dùng được khi điều kiện chạm cột đầu tiên (tiền tố trái). Partial index chỉ chứa dòng thỏa `WHERE`. Mỗi index làm chậm `INSERT`/`UPDATE` và tốn chỗ. PostgreSQL không tự tạo index cho khóa ngoại. |
| 16 | Transaction | `BEGIN` ... `COMMIT`/`ROLLBACK`: tất cả hoặc không gì cả. Một lệnh lỗi làm transaction hỏng, chỉ còn `ROLLBACK` được. `SELECT ... FOR UPDATE` khóa dòng để tránh lost update. |
| 17 | Function, procedure | Function trả về giá trị, gọi trong `SELECT`. Procedure gọi bằng `CALL`, được `COMMIT` bên trong. `RAISE EXCEPTION` dừng và hủy mọi thay đổi chưa commit. |
| 18 | Trigger | Chạy tự động trước/sau `INSERT`/`UPDATE`/`DELETE`. Tiện nhưng là "logic ẩn": người gọi không thấy, dễ trùng việc với code ứng dụng. |
| 19 | View | View thường chỉ lưu câu `SELECT`, không nhanh hơn. Materialized view lưu kết quả, phải `REFRESH`. `WITH CHECK OPTION` chặn ghi dữ liệu ngoài view. |
| 20 | EXPLAIN | `EXPLAIN` cho plan ước lượng, `EXPLAIN ANALYZE` chạy thật và cho số thật. So `rows` ước lượng với `actual rows`. Seq Scan không phải lúc nào cũng xấu. |

## Câu hỏi kiểm tra khái niệm

Tự trả lời trước khi mở đáp án.

**Câu 1.** Bảng `categories` có 13 dòng. Bạn tạo index trên `categories (name)` rồi chạy `EXPLAIN SELECT * FROM categories WHERE name = 'Laptop'`, plan vẫn là `Seq Scan`. Có phải index bị hỏng?

<details>
<summary>Đáp án</summary>

Không. Bảng 13 dòng nằm gọn trong một trang (page) dữ liệu; đọc thẳng trang đó rẻ hơn đi qua index rồi mới đọc bảng. Planner so chi phí ước lượng và chọn cách rẻ hơn. Index chỉ có lợi khi bảng đủ lớn và điều kiện lọc ra một phần nhỏ số dòng.
</details>

**Câu 2.** Có index `(customer_id, order_date)` trên `perf.orders`. Truy vấn nào dùng được index này một cách hiệu quả: (a) `WHERE customer_id = 4242`, (b) `WHERE order_date >= '2025-06-15' AND order_date < '2025-06-16'`, (c) `WHERE customer_id = 4242 AND order_date >= '2025-01-01'`?

<details>
<summary>Đáp án</summary>

(a) và (c). Index nhiều cột được sắp xếp theo `customer_id` trước, trong cùng một khách mới theo `order_date`, giống danh bạ sắp theo họ rồi mới tới tên. Điều kiện chỉ có `order_date` (b) không có điểm bắt đầu trong index, nên planner thường chọn quét cả bảng. Bài tập 8 đo điều này.
</details>

**Câu 3.** Vì sao `WHERE DATE_TRUNC('day', order_date) = '2025-06-15'` không dùng được index B-tree trên `order_date`? Viết lại thế nào?

<details>
<summary>Đáp án</summary>

Index lưu giá trị `order_date`, không lưu `DATE_TRUNC('day', order_date)`. Khi cột bị bọc trong hàm, PostgreSQL phải tính hàm cho từng dòng rồi mới so sánh. Viết lại thành khoảng trên chính cột: `order_date >= '2025-06-15' AND order_date < '2025-06-16'`. Bài tập 10 đo điều này.
</details>

**Câu 4.** Trong một transaction, lệnh thứ hai báo lỗi vi phạm `CHECK`. Bạn gõ tiếp một lệnh `SELECT` thì nhận được gì? `COMMIT` lúc này có lưu được lệnh thứ nhất không?

<details>
<summary>Đáp án</summary>

`SELECT` báo `ERROR: current transaction is aborted, commands ignored until end of transaction block`. Transaction đã hỏng, mọi lệnh bị bỏ qua cho tới khi kết thúc. Gõ `COMMIT` lúc này PostgreSQL thực chất thực hiện `ROLLBACK` (psql in ra `ROLLBACK`), nên lệnh thứ nhất cũng không được lưu. Muốn giữ phần đã làm trước chỗ lỗi thì phải đặt `SAVEPOINT` và `ROLLBACK TO SAVEPOINT`.
</details>

**Câu 5.** Hai nhân viên cùng bán chiếc Lenovo Legion 5 cuối cùng (`stock_quantity = 1`). Mỗi người chạy `SELECT stock_quantity` thấy 1, rồi chạy `UPDATE products SET stock_quantity = 0`. Hiện tượng này tên gì, và sửa thế nào?

<details>
<summary>Đáp án</summary>

Lost update: cả hai đọc cùng một giá trị cũ rồi ghi đè lên nhau, kho bán ra 2 cái mà chỉ trừ 1. Cách sửa: (1) đọc bằng `SELECT ... FOR UPDATE` trong transaction, người thứ hai phải chờ người thứ nhất xong và sẽ thấy 0; hoặc (2) trừ trực tiếp và để ràng buộc kiểm tra: `UPDATE products SET stock_quantity = stock_quantity - 1 WHERE ...`, khi đó `CHECK (stock_quantity >= 0)` chặn lần bán thứ hai. Procedure ở bài tập 6 dùng cách (1).
</details>

**Câu 6.** Function và procedure khác nhau thế nào trong PostgreSQL? Khi nào dùng cái nào?

<details>
<summary>Đáp án</summary>

Function trả về một giá trị (hoặc một bảng với `RETURNS TABLE`) và được gọi bên trong câu lệnh SQL, ví dụ `SELECT monthly_revenue(2025, 11)`. Procedure không trả giá trị theo kiểu đó, được gọi bằng `CALL`, và có thể `COMMIT`/`ROLLBACK` bên trong (khi không bị gọi trong một transaction đang mở). Tính toán và tra cứu dùng function; một quy trình nhiều bước có ghi dữ liệu (như đặt hàng) hợp với procedure.
</details>

**Câu 7.** Báo cáo doanh thu theo tháng trên 1 triệu đơn mất khoảng 100-200 ms. Bạn tạo một view thường cho nó. Báo cáo có nhanh hơn không? Nếu cần nhanh hơn thì làm gì, và phải trả giá gì?

<details>
<summary>Đáp án</summary>

Không nhanh hơn: view thường chỉ là câu `SELECT` được đặt tên, mỗi lần đọc vẫn quét cả triệu đơn. Muốn nhanh thì dùng materialized view (đọc dưới 1 ms trong phép đo ở Ngày 19), đổi lại số liệu chỉ mới tới lần `REFRESH` gần nhất, và mỗi lần `REFRESH` tốn công chạy lại truy vấn gốc.
</details>

**Câu 8.** Trong output của `EXPLAIN ANALYZE`, dòng `Seq Scan on orders (cost=0.00..13405.33 rows=4014 ...) (actual time=... rows=3287 loops=3)` cho bạn biết những gì? Khi `rows` ước lượng lệch rất xa `actual rows`, bạn làm gì đầu tiên?

<details>
<summary>Đáp án</summary>

Planner ước lượng mỗi lần quét trả về khoảng 4014 dòng với chi phí tới 13405 đơn vị; thực tế mỗi lần trả 3287 dòng và nút này chạy 3 lần (`loops=3`, do 2 worker song song cộng tiến trình chính), tổng khoảng 9860 dòng. Ước lượng lệch nhẹ như vậy là bình thường. Nếu lệch hàng chục, hàng trăm lần, việc đầu tiên là chạy `ANALYZE tên_bảng` để cập nhật thống kê rồi xem lại plan, vì plan tệ thường bắt nguồn từ ước lượng sai.
</details>

## Bài tập

### Cơ bản

**Bài 1. Index một cột (perf).** Tìm mọi đơn của khách `customer_id = 4242` trong `perf.orders`. Chạy `EXPLAIN ANALYZE` trước khi có index, tạo index trên `customer_id`, chạy lại và so sánh. Cuối bài xóa index.

<details>
<summary>Đáp án</summary>

```sql
EXPLAIN ANALYZE
SELECT order_id, order_date, status, total_amount
FROM perf.orders
WHERE customer_id = 4242;
```

```text
 Gather  (cost=1000.00..14406.43 rows=11 width=27) (actual time=4.476..17.265 rows=9 loops=1)
   Workers Planned: 2
   Workers Launched: 2
   ->  Parallel Seq Scan on orders  (cost=0.00..13405.33 rows=5 width=27) (actual time=1.651..13.257 rows=3 loops=3)
         Filter: (customer_id = 4242)
         Rows Removed by Filter: 333330
 Planning Time: 0.052 ms
 Execution Time: 17.278 ms
```

Không có index, PostgreSQL chia bảng cho 3 tiến trình quét song song, mỗi tiến trình bỏ đi khoảng 333 nghìn dòng để giữ lại tổng cộng 9 dòng.

```sql
CREATE INDEX idx_perf_orders_customer ON perf.orders (customer_id);

EXPLAIN ANALYZE
SELECT order_id, order_date, status, total_amount
FROM perf.orders
WHERE customer_id = 4242;
```

```text
 Bitmap Heap Scan on orders  (cost=4.51..47.44 rows=11 width=27) (actual time=0.017..0.029 rows=9 loops=1)
   Recheck Cond: (customer_id = 4242)
   Heap Blocks: exact=9
   ->  Bitmap Index Scan on idx_perf_orders_customer  (cost=0.00..4.51 rows=11 width=0) (actual time=0.011..0.011 rows=9 loops=1)
         Index Cond: (customer_id = 4242)
 Planning Time: 0.044 ms
 Execution Time: 0.041 ms
```

Trên máy mình: khoảng 17-35 ms trước, 0,04-0,2 ms sau (lần đầu chậm hơn vì dữ liệu chưa nằm trong bộ nhớ đệm). Máy bạn sẽ ra số khác. Plan chuyển sang Bitmap Index Scan: tìm 9 vị trí trong index, rồi chỉ đọc 9 trang của bảng (`Heap Blocks: exact=9`). Index này nặng khoảng 9 MB, bảng 64 MB (`pg_size_pretty(pg_relation_size('perf.idx_perf_orders_customer'))`).

```sql
DROP INDEX perf.idx_perf_orders_customer;
```
</details>

**Bài 2. Transaction đặt hàng.** Khách 16 (chưa từng mua) đặt 2 chuột Logitech G102 (`ACC-001`, đang còn 60 cái), đơn online, giao tới Cần Thơ. Viết transaction tạo đơn, tạo dòng hàng theo giá hiện tại và trừ kho. Kiểm tra kết quả trước khi kết thúc. (Kết thúc bằng `ROLLBACK` để giữ dữ liệu gốc; khi làm thật thì dùng `COMMIT`.)

<details>
<summary>Đáp án</summary>

```sql
BEGIN;

INSERT INTO orders (customer_id, order_date, status, channel, shipping_city)
VALUES (16, now(), 'pending', 'online', 'Cần Thơ');

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT currval(pg_get_serial_sequence('orders', 'order_id')), product_id, 2, price
FROM products
WHERE sku = 'ACC-001';

UPDATE products
SET stock_quantity = stock_quantity - 2
WHERE sku = 'ACC-001';

SELECT o.order_id, o.customer_id, oi.product_id, oi.quantity, oi.unit_price
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.customer_id = 16;

SELECT sku, stock_quantity FROM products WHERE sku = 'ACC-001';

ROLLBACK;
```

| order_id | customer_id | product_id | quantity | unit_price |
| --- | --- | --- | --- | --- |
| 41 | 16 | 16 | 2 | 399000 |

| sku | stock_quantity |
| --- | --- |
| ACC-001 | 58 |

`currval(pg_get_serial_sequence('orders', 'order_id'))` là mã đơn vừa được sinh **trong phiên của bạn**. Đừng dùng `SELECT MAX(order_id) FROM orders`: nếu cùng lúc có người khác đặt hàng, `MAX` có thể là đơn của họ. (Mã đơn trên máy bạn có thể khác 41, vì `ROLLBACK` không trả lại số đã cấp.)
</details>

**Bài 3. View nhiều bảng.** Tạo view `order_lines` gộp `orders`, `customers`, `order_items`, `products`, mỗi dòng là một dòng hàng với tên khách, tên sản phẩm và thành tiền `line_total` (đã trừ chiết khấu). Dùng view liệt kê các dòng hàng của khách 1, rồi tính tổng tiền từng đơn của khách này.

<details>
<summary>Đáp án</summary>

```sql
CREATE VIEW order_lines AS
SELECT
    o.order_id,
    o.order_date,
    o.status,
    c.customer_id,
    c.full_name AS customer_name,
    p.sku,
    p.name      AS product_name,
    oi.quantity,
    oi.unit_price,
    oi.discount,
    ROUND(oi.quantity * oi.unit_price * (1 - oi.discount)) AS line_total
FROM orders AS o
JOIN customers   AS c  ON c.customer_id = o.customer_id
JOIN order_items AS oi ON oi.order_id   = o.order_id
JOIN products    AS p  ON p.product_id  = oi.product_id;

SELECT order_id, order_date::DATE AS ngay, product_name, quantity, line_total
FROM order_lines
WHERE customer_id = 1
ORDER BY order_date, product_name;
```

| order_id | ngay | product_name | quantity | line_total |
| --- | --- | --- | --- | --- |
| 1 | 2025-01-12 | Cáp USB-C to USB-C 1m | 2 | 300000 |
| 1 | 2025-01-12 | Chuột Logitech G102 | 1 | 399000 |
| 4 | 2025-02-14 | Chuột Logitech MX Master 3S | 1 | 2490000 |
| 4 | 2025-02-14 | Tai nghe AirPods Pro 2 | 1 | 5391000 |
| 13 | 2025-07-08 | Cáp USB-C to USB-C 1m | 3 | 450000 |
| 13 | 2025-07-08 | Sạc Anker 65W | 2 | 1780000 |
| 25 | 2025-12-24 | iPad Air M2 11 inch | 1 | 16990000 |
| 25 | 2025-12-24 | Tai nghe Sony WH-1000XM5 | 1 | 7990000 |
| 37 | 2026-09-02 | Cáp USB-C to USB-C 1m | 1 | 150000 |
| 37 | 2026-09-02 | Samsung Galaxy Tab S9 FE | 1 | 9490000 |

```sql
SELECT order_id, SUM(line_total) AS total_amount
FROM order_lines
WHERE customer_id = 1
GROUP BY order_id
ORDER BY order_id;
```

| order_id | total_amount |
| --- | --- |
| 1 | 699000 |
| 4 | 7881000 |
| 13 | 2230000 |
| 25 | 24980000 |
| 37 | 9640000 |

View có JOIN nên không cập nhật được qua nó; muốn sửa đơn thì sửa bảng gốc.
</details>

**Bài 4. Function và khoảng thời gian nửa mở.** Viết function `monthly_revenue(p_year INT, p_month INT)` trả về doanh thu (không tính đơn `pending` và `cancelled`) của một tháng. Gọi cho tháng 11/2025, 10/2026 và 1/2024. Sau đó giải thích vì sao truy vấn `WHERE order_date BETWEEN '2025-11-01' AND '2025-11-11'` không tìm thấy hai đơn ngày 11/11/2025.

<details>
<summary>Đáp án</summary>

```sql
CREATE OR REPLACE FUNCTION monthly_revenue(p_year INT, p_month INT)
RETURNS NUMERIC
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))), 0)
    FROM orders AS o
    JOIN order_items AS oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
      AND o.order_date >= make_date(p_year, p_month, 1)
      AND o.order_date <  make_date(p_year, p_month, 1) + INTERVAL '1 month';
$$;

SELECT monthly_revenue(2025, 11) AS t11_2025,
       monthly_revenue(2026, 10) AS t10_2026,
       monthly_revenue(2024, 1)  AS t01_2024;
```

| t11_2025 | t10_2026 | t01_2024 |
| --- | --- | --- |
| 40762500 | 39980000 | 0 |

`make_date(năm, tháng, ngày)` tạo một giá trị `DATE`. Điều kiện `>= ngày đầu tháng AND < ngày đầu tháng sau` là **khoảng nửa mở**: lấy trọn mọi thời điểm trong tháng, kể cả 23:59:59 ngày cuối tháng. `COALESCE(..., 0)` để tháng không có đơn trả 0 thay vì NULL. `STABLE` báo cho PostgreSQL biết function chỉ đọc dữ liệu, không sửa gì.

Bẫy `BETWEEN` với cột thời gian:

```sql
SELECT order_id, order_date FROM orders
WHERE order_date BETWEEN '2025-11-01' AND '2025-11-11';
```

Kết quả: 0 dòng. `'2025-11-11'` được hiểu là `2025-11-11 00:00:00`, nên đơn 21 (19:00) và đơn 22 (23:30) cùng ngày nằm ngoài khoảng. Viết lại bằng khoảng nửa mở:

```sql
SELECT order_id, order_date FROM orders
WHERE order_date >= '2025-11-01' AND order_date < '2025-11-12';
```

| order_id | order_date |
| --- | --- |
| 21 | 2025-11-11 19:00:00+07 |
| 22 | 2025-11-11 23:30:00+07 |
</details>

### Vận dụng

**Bài 5. Transaction thất bại.** Lặp lại bài 2 nhưng khách 16 đặt 1 laptop Acer Nitro V 15 (`LAP-003`, tồn kho 0). Chuyện gì xảy ra ở lệnh trừ kho? Gõ thêm một `SELECT` trong transaction đó thì sao? Sau `ROLLBACK`, khách 16 có đơn nào không?

<details>
<summary>Đáp án</summary>

```sql
BEGIN;

INSERT INTO orders (customer_id, order_date, status, channel, shipping_city)
VALUES (16, now(), 'pending', 'online', 'Cần Thơ');

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT currval(pg_get_serial_sequence('orders', 'order_id')), product_id, 1, price
FROM products
WHERE sku = 'LAP-003';

UPDATE products
SET stock_quantity = stock_quantity - 1
WHERE sku = 'LAP-003';
```

```text
ERROR:  new row for relation "products" violates check constraint "products_stock_quantity_check"
DETAIL:  Failing row contains (3, LAP-003, Acer Nitro V 15, 3, 21990000, 19000000, -1, {"cpu": "Intel Core i5-13420H", "gpu": "RTX 3050", "brand": "Ace..., t, 2024-11-15 00:00:00+07).
```

```sql
SELECT COUNT(*) FROM orders;
```

```text
ERROR:  current transaction is aborted, commands ignored until end of transaction block
```

```sql
ROLLBACK;

SELECT COUNT(*) AS so_don_cua_khach_16 FROM orders WHERE customer_id = 16;
```

| so_don_cua_khach_16 |
| --- |
| 0 |

Ràng buộc `CHECK (stock_quantity >= 0)` của bảng `products` chặn tồn kho âm. Vì cả ba lệnh nằm chung một transaction, đơn và dòng hàng đã chèn trước đó cũng bị hủy theo: đúng tính nguyên tử (Atomicity) của ACID. Nếu chạy ba lệnh này **không** có `BEGIN` (chế độ autocommit), đơn và dòng hàng đã được lưu từ trước khi lệnh trừ kho lỗi, và bạn có một đơn hàng "ma" không trừ kho.
</details>

**Bài 6. Procedure đặt hàng.** Gói quy trình đặt hàng thành procedure `place_order(p_customer_id INT, p_sku VARCHAR, p_quantity INT)` bằng PL/pgSQL:

- báo lỗi nếu số lượng không dương;
- báo lỗi nếu không có sản phẩm đang kinh doanh với `sku` đó;
- khóa dòng sản phẩm khi đọc tồn kho, báo lỗi rõ ràng nếu không đủ hàng;
- tạo đơn online `pending`, dòng hàng theo giá hiện tại, trừ kho, in ra mã đơn.

Thử gọi với `ACC-001` (2 cái), `LAP-003` (hết hàng), `PHN-004` (ngừng kinh doanh), và số lượng 0.

<details>
<summary>Đáp án</summary>

```sql
CREATE OR REPLACE PROCEDURE place_order(
    p_customer_id INT,
    p_sku         VARCHAR,
    p_quantity    INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_id INT;
    v_price      NUMERIC(12,0);
    v_stock      INT;
    v_order_id   INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Số lượng phải lớn hơn 0 (nhận %)', p_quantity;
    END IF;

    SELECT product_id, price, stock_quantity
    INTO v_product_id, v_price, v_stock
    FROM products
    WHERE sku = p_sku AND is_active
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Không có sản phẩm % đang kinh doanh', p_sku;
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Sản phẩm % chỉ còn % cái, không đủ %', p_sku, v_stock, p_quantity;
    END IF;

    INSERT INTO orders (customer_id, order_date, status, channel)
    VALUES (p_customer_id, now(), 'pending', 'online')
    RETURNING order_id INTO v_order_id;

    INSERT INTO order_items (order_id, product_id, quantity, unit_price)
    VALUES (v_order_id, v_product_id, p_quantity, v_price);

    UPDATE products
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = v_product_id;

    RAISE NOTICE 'Đã tạo đơn % cho khách %', v_order_id, p_customer_id;
END;
$$;
```

Gọi thử trong transaction để hủy được:

```sql
BEGIN;
CALL place_order(16, 'ACC-001', 2);
SELECT sku, stock_quantity FROM products WHERE sku = 'ACC-001';
ROLLBACK;
```

```text
NOTICE:  Đã tạo đơn 41 cho khách 16
```

| sku | stock_quantity |
| --- | --- |
| ACC-001 | 58 |

(Mã đơn trên máy bạn có thể lớn hơn 41 nếu bạn đã chạy các bài trước, vì IDENTITY không lùi lại sau `ROLLBACK`.)

Ba lần gọi sai:

```sql
CALL place_order(16, 'LAP-003', 1);
CALL place_order(16, 'PHN-004', 1);
CALL place_order(16, 'ACC-001', 0);
```

```text
ERROR:  Sản phẩm LAP-003 chỉ còn 0 cái, không đủ 1
CONTEXT:  PL/pgSQL function place_order(integer,character varying,integer) line 23 at RAISE
ERROR:  Không có sản phẩm PHN-004 đang kinh doanh
CONTEXT:  PL/pgSQL function place_order(integer,character varying,integer) line 19 at RAISE
ERROR:  Số lượng phải lớn hơn 0 (nhận 0)
CONTEXT:  PL/pgSQL function place_order(integer,character varying,integer) line 9 at RAISE
```

Mỗi lần `RAISE EXCEPTION`, mọi thứ procedure đã làm trong lần gọi đó bị hủy, nên khách 16 vẫn có 0 đơn. `FOR UPDATE` khóa dòng sản phẩm tới khi transaction kết thúc: hai người cùng mua món cuối cùng thì người thứ hai phải chờ, rồi đọc được tồn kho đã bị trừ (câu 5 ở trên).
</details>

**Bài 7. Trigger và bẫy trừ kho hai lần.** Tạo trigger `AFTER INSERT` trên `order_items` tự trừ `stock_quantity` theo `NEW.quantity`. Sau đó gọi lại `place_order(16, 'ACC-001', 2)` từ bài 6. Tồn kho còn bao nhiêu, đúng không? Sửa thế nào? Cuối bài xóa trigger.

<details>
<summary>Đáp án</summary>

```sql
CREATE OR REPLACE FUNCTION trg_decrease_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER order_items_decrease_stock
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION trg_decrease_stock();

BEGIN;
CALL place_order(16, 'ACC-001', 2);
SELECT sku, stock_quantity FROM products WHERE sku = 'ACC-001';
ROLLBACK;
```

| sku | stock_quantity |
| --- | --- |
| ACC-001 | 56 |

Khách mua 2 cái mà kho giảm từ 60 xuống 56: trigger trừ 2, rồi lệnh `UPDATE products` trong procedure trừ thêm 2. Không có lỗi nào được báo, nên bug này rất khó thấy. Đây chính là nhược điểm "logic ẩn" của trigger.

Cách sửa: mỗi quy tắc chỉ nằm ở **một** chỗ. Hoặc giữ trigger và bỏ lệnh `UPDATE products` khỏi procedure; hoặc (thường dễ hiểu hơn) bỏ trigger, để procedure lo việc trừ kho. Nếu giữ trigger, chèn dòng hàng trực tiếp cũng tự trừ kho, và `CHECK (stock_quantity >= 0)` vẫn chặn được tồn kho âm:

```sql
BEGIN;
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
VALUES (40, 3, 1, 21990000);
ROLLBACK;
```

```text
ERROR:  new row for relation "products" violates check constraint "products_stock_quantity_check"
CONTEXT:  SQL statement "UPDATE products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE product_id = NEW.product_id"
PL/pgSQL function trg_decrease_stock() line 3 at SQL statement
```

Xóa trigger để các bài sau không bị ảnh hưởng:

```sql
DROP TRIGGER order_items_decrease_stock ON order_items;
```
</details>

**Bài 8. Index nhiều cột và quy tắc tiền tố trái (perf).** Tạo index `(customer_id, order_date)` trên `perf.orders`. Dùng `EXPLAIN ANALYZE` cho hai truy vấn: (a) đơn của khách 4242 trong năm 2025; (b) số đơn trong ngày 15/6/2025 (mọi khách). Truy vấn nào dùng index? Vì sao? Cuối bài xóa index.

<details>
<summary>Đáp án</summary>

```sql
CREATE INDEX idx_perf_orders_cust_date ON perf.orders (customer_id, order_date);

EXPLAIN ANALYZE
SELECT order_id, order_date, total_amount
FROM perf.orders
WHERE customer_id = 4242
  AND order_date >= '2025-01-01'
  AND order_date <  '2026-01-01';
```

```text
 Index Scan using idx_perf_orders_cust_date on orders  (cost=0.42..16.49 rows=3 width=18) (actual time=0.038..0.045 rows=4 loops=1)
   Index Cond: ((customer_id = 4242) AND (order_date >= '2025-01-01 00:00:00+07'::timestamp with time zone) AND (order_date < '2026-01-01 00:00:00+07'::timestamp with time zone))
 Planning Time: 0.300 ms
 Execution Time: 0.061 ms
```

Cả hai điều kiện đều nằm trong `Index Cond`: PostgreSQL nhảy tới đoạn index của khách 4242, trong đoạn đó các đơn đã xếp theo ngày, nên chỉ đọc đúng 4 đơn của năm 2025.

```sql
EXPLAIN ANALYZE
SELECT COUNT(*) FROM perf.orders
WHERE order_date >= '2025-06-15'
  AND order_date <  '2025-06-16';
```

```text
 Finalize Aggregate  (cost=15447.99..15448.00 rows=1 width=8) (actual time=31.279..34.744 rows=1 loops=1)
   ->  Gather  (cost=15447.77..15447.98 rows=2 width=8) (actual time=31.114..34.735 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=14447.77..14447.78 rows=1 width=8) (actual time=27.326..27.328 rows=1 loops=3)
               ->  Parallel Seq Scan on orders  (cost=0.00..14447.00 rows=309 width=0) (actual time=0.432..27.271 rows=251 loops=3)
                     Filter: ((order_date >= '2025-06-15 00:00:00+07'::timestamp with time zone) AND (order_date < '2025-06-16 00:00:00+07'::timestamp with time zone))
                     Rows Removed by Filter: 333082
 Planning Time: 0.086 ms
 Execution Time: 34.744 ms
```

Truy vấn (b) quay về Seq Scan. Trong index, đơn ngày 15/6/2025 nằm rải rác trong đoạn của từng khách trong số 100.000 khách, nên không có "đoạn liền" nào để nhảy tới. Muốn (b) nhanh thì cần index có `order_date` đứng đầu (bài 10 dùng index như vậy).

```sql
DROP INDEX perf.idx_perf_orders_cust_date;
```
</details>

### Thử thách

**Bài 9. Partial index (perf).** Màn hình "đơn chờ xử lý" cần 20 đơn `pending` mới nhất. Chỉ khoảng 1% đơn ở trạng thái `pending`. Đo truy vấn trước, rồi tạo một partial index phù hợp và đo lại. So kích thước partial index với một index thường trên `order_date`. Truy vấn tương tự cho `status = 'shipped'` có dùng partial index không?

<details>
<summary>Đáp án</summary>

```sql
EXPLAIN ANALYZE
SELECT order_id, customer_id, order_date, total_amount
FROM perf.orders
WHERE status = 'pending'
ORDER BY order_date DESC
LIMIT 20;
```

```text
 Limit  (cost=14512.17..14514.50 rows=20 width=22) (actual time=18.690..20.762 rows=20 loops=1)
   ->  Gather Merge  (cost=14512.17..15448.83 rows=8028 width=22) (actual time=18.688..20.757 rows=20 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Sort  (cost=13512.14..13522.18 rows=4014 width=22) (actual time=16.424..16.426 rows=16 loops=3)
               Sort Key: order_date DESC
               Sort Method: top-N heapsort  Memory: 27kB
               ...
               ->  Parallel Seq Scan on orders  (cost=0.00..13405.33 rows=4014 width=22) (actual time=0.040..16.087 rows=3287 loops=3)
                     Filter: ((status)::text = 'pending'::text)
                     Rows Removed by Filter: 330047
 Planning Time: 0.311 ms
 Execution Time: 20.846 ms
```

Quét cả triệu dòng, giữ 9860 đơn `pending`, rồi sắp xếp để lấy 20 đơn mới nhất.

```sql
CREATE INDEX idx_perf_orders_pending
    ON perf.orders (order_date)
    WHERE status = 'pending';

EXPLAIN ANALYZE
SELECT order_id, customer_id, order_date, total_amount
FROM perf.orders
WHERE status = 'pending'
ORDER BY order_date DESC
LIMIT 20;
```

```text
 Limit  (cost=0.29..51.22 rows=20 width=22) (actual time=0.023..0.234 rows=20 loops=1)
   ->  Index Scan Backward using idx_perf_orders_pending on orders  (cost=0.29..24532.36 rows=9633 width=22) (actual time=0.022..0.231 rows=20 loops=1)
 Planning Time: 0.136 ms
 Execution Time: 0.245 ms
```

Từ khoảng 20-33 ms xuống 0,2 ms trên máy mình (đo nhiều lần). Index chỉ chứa đơn `pending`, đã xếp theo `order_date`, nên PostgreSQL đọc ngược từ cuối index (`Index Scan Backward`) và dừng sau 20 dòng, không cần sắp xếp.

So kích thước (tạo tạm một index thường để so, rồi xóa):

```sql
CREATE INDEX idx_perf_orders_date_full ON perf.orders (order_date);

SELECT relname, pg_size_pretty(pg_relation_size(oid)) AS size
FROM pg_class
WHERE relname IN ('idx_perf_orders_pending', 'idx_perf_orders_date_full');

DROP INDEX perf.idx_perf_orders_date_full;
```

| relname | size |
| --- | --- |
| idx_perf_orders_pending | 232 kB |
| idx_perf_orders_date_full | 21 MB |

Partial index nhỏ hơn khoảng 90 lần và chỉ phải cập nhật khi có đơn `pending` thay đổi. Truy vấn với `status = 'shipped'` thì **không** dùng được nó, vì điều kiện không khớp `WHERE status = 'pending'` của index; plan vẫn là Parallel Seq Scan và Sort (khoảng 25-31 ms trên máy mình):

```sql
EXPLAIN ANALYZE
SELECT order_id, customer_id, order_date, total_amount
FROM perf.orders
WHERE status = 'shipped'
ORDER BY order_date DESC
LIMIT 20;

DROP INDEX perf.idx_perf_orders_pending;
```
</details>

**Bài 10. Hàm bọc cột làm mất index (perf).** Có index thường trên `perf.orders (order_date)`. Đồng nghiệp viết báo cáo một ngày như sau:

```sql
SELECT COUNT(*), SUM(total_amount)
FROM perf.orders
WHERE DATE_TRUNC('day', order_date) = '2025-06-15';
```

Đo truy vấn này, viết lại để dùng được index và đo lại. Thử tạo expression index trên `DATE_TRUNC('day', order_date)` và giải thích kết quả. Cuối bài xóa index.

<details>
<summary>Đáp án</summary>

```sql
CREATE INDEX idx_perf_orders_date ON perf.orders (order_date);

EXPLAIN ANALYZE
SELECT COUNT(*), SUM(total_amount)
FROM perf.orders
WHERE DATE_TRUNC('day', order_date) = '2025-06-15';
```

```text
 Finalize Aggregate  (cost=15457.65..15457.66 rows=1 width=40) (actual time=81.743..84.987 rows=1 loops=1)
   ->  Gather  (cost=15457.42..15457.63 rows=2 width=40) (actual time=81.486..84.923 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial Aggregate  (cost=14457.42..14457.43 rows=1 width=40) (actual time=78.174..78.175 rows=1 loops=3)
               ->  Parallel Seq Scan on orders  (cost=0.00..14447.00 rows=2083 width=6) (actual time=0.623..78.043 rows=251 loops=3)
                     Filter: (date_trunc('day'::text, order_date) = '2025-06-15 00:00:00+07'::timestamp with time zone)
                     Rows Removed by Filter: 333082
 Planning Time: 0.362 ms
 Execution Time: 85.066 ms
```

Index có sẵn nhưng không được dùng: PostgreSQL phải tính `DATE_TRUNC` cho cả triệu dòng. Để ý thêm `rows=2083` ước lượng so với `rows=251` thực tế mỗi tiến trình: với điều kiện bọc hàm, planner không có thống kê nên đoán theo tỉ lệ mặc định.

Viết lại bằng khoảng nửa mở trên chính cột:

```sql
EXPLAIN ANALYZE
SELECT COUNT(*), SUM(total_amount)
FROM perf.orders
WHERE order_date >= '2025-06-15'
  AND order_date <  '2025-06-16';
```

```text
 Aggregate  (cost=2245.29..2245.30 rows=1 width=40) (actual time=5.904..5.906 rows=1 loops=1)
   ->  Bitmap Heap Scan on orders  (cost=20.02..2241.58 rows=741 width=6) (actual time=0.289..5.729 rows=754 loops=1)
         Recheck Cond: ((order_date >= '2025-06-15 00:00:00+07'::timestamp with time zone) AND (order_date < '2025-06-16 00:00:00+07'::timestamp with time zone))
         Heap Blocks: exact=721
         ->  Bitmap Index Scan on idx_perf_orders_date  (cost=0.00..19.84 rows=741 width=0) (actual time=0.167..0.168 rows=754 loops=1)
               Index Cond: ((order_date >= '2025-06-15 00:00:00+07'::timestamp with time zone) AND (order_date < '2025-06-16 00:00:00+07'::timestamp with time zone))
 Planning Time: 0.179 ms
 Execution Time: 5.938 ms
```

Kết quả hai cách giống nhau (754 đơn, tổng `10883531000`), nhưng thời gian giảm từ khoảng 80 ms xuống 1-6 ms (đo nhiều lần trên máy mình), và ước lượng `rows=741` sát thực tế 754.

Thử expression index:

```sql
CREATE INDEX ON perf.orders (DATE_TRUNC('day', order_date));
```

```text
ERROR:  functions in index expression must be marked IMMUTABLE
```

Với `TIMESTAMPTZ`, "đầu ngày" phụ thuộc múi giờ của phiên (`DATE_TRUNC('day', ...)` ở Việt Nam và ở Anh cho kết quả khác nhau), nên hàm không phải IMMUTABLE và PostgreSQL không cho đưa vào index. Đây là thêm một lý do để ưu tiên viết điều kiện dạng khoảng trên chính cột. (Với cột kiểu `DATE` hoặc biểu thức như `LOWER(email)` thì expression index dùng được bình thường.)

```sql
DROP INDEX perf.idx_perf_orders_date;
```
</details>

## Tóm tắt

- Index giúp khi lấy ít dòng từ bảng lớn. Kiểm tra bằng `EXPLAIN ANALYZE`, không đoán. Index nhiều cột theo quy tắc tiền tố trái; partial index nhỏ và nhanh cho tập con hay truy vấn.
- Cột bọc trong hàm (`DATE_TRUNC`, `EXTRACT`, ép kiểu) thường làm mất index. Viết điều kiện thời gian bằng khoảng nửa mở `>= đầu AND < cuối`, không dùng `BETWEEN` với cột thời gian.
- Transaction đảm bảo tất cả hoặc không gì cả; sau một lỗi chỉ còn `ROLLBACK`. Dùng `currval(...)` hoặc `RETURNING`, không dùng `MAX(id)`, để lấy mã vừa tạo.
- Procedure PL/pgSQL gói quy trình nhiều bước với `RAISE EXCEPTION` và `SELECT ... FOR UPDATE`. Ràng buộc `CHECK` là lưới an toàn cuối cùng.
- Mỗi quy tắc nghiệp vụ chỉ nên nằm ở một nơi: trigger và code cùng trừ kho là trừ hai lần.
- View gói truy vấn nhiều bảng; materialized view đánh đổi độ mới của dữ liệu lấy tốc độ.

## Đọc thêm

- [PostgreSQL: Using EXPLAIN](https://www.postgresql.org/docs/16/using-explain.html)
- [PostgreSQL: Partial Indexes](https://www.postgresql.org/docs/16/indexes-partial.html)
- [PostgreSQL: Multicolumn Indexes](https://www.postgresql.org/docs/16/indexes-multicolumn.html)

---

[⬅️ Ngày 20: Đọc kế hoạch thực thi với EXPLAIN](20-query-performance.md) | [📚 Mục lục](../README.md) | [Ngày 22: Làm việc với JSON và JSONB ➡️](22-sql-json-practice.md)
