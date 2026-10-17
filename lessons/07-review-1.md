# Ngày 7: Ôn tập 1 (Ngày 1 đến 6)

> **Tóm tắt:** Bài ôn tập chặng đầu. Không có kiến thức mới: bạn dùng lại những gì đã học từ Ngày 1 đến Ngày 6 (khám phá schema, kiểu dữ liệu và ràng buộc, SELECT/WHERE/NULL, ORDER BY/LIMIT, biểu thức và hàm, INSERT/UPDATE/DELETE) để giải 16 bài tập trên DSC Shop, chia ba mức độ, có đáp án và kết quả thật để tự chấm.

**Sau bài này bạn có thể:**

- Tự kiểm tra mình đã nắm chắc phần nào của Ngày 1 đến 6 và phần nào cần đọc lại.
- Viết được truy vấn đọc dữ liệu kết hợp lọc, xử lý NULL, sắp xếp, phân trang và cột tính toán.
- Tạo được một bảng nháp có đủ ràng buộc, rồi thêm, sửa, xóa dữ liệu trên đó theo quy trình an toàn.

**Cần biết trước:** [Ngày 1](01-intro-to-sql-and-dbms.md), [Ngày 2](02-table-structure-and-data-types.md), [Ngày 3](03-select-where.md), [Ngày 4](04-order-by-limit.md), [Ngày 5](05-operators-expressions.md), [Ngày 6](06-insert-update-delete.md).

## Cách làm bài

1. Mở psql hoặc Adminer, kết nối database `sql_challenge` (xem [setup/README.md](../setup/README.md)).
2. Tự viết truy vấn trước, chạy thử, rồi mới mở "Đáp án" để so. Kết quả của bạn phải khớp từng dòng (thứ tự dòng khớp khi đề có yêu cầu sắp xếp).
3. Mọi đáp án được chạy trên dữ liệu gốc. Bài nào sửa dữ liệu thì đáp án bọc trong `BEGIN ... ROLLBACK` hoặc làm trên bảng nháp, nên làm xong dữ liệu shop vẫn như cũ. Nếu lỡ sửa thật, chạy lại script init:

```sh
docker compose exec -T db psql -U postgres -d sql_challenge -f /docker-entrypoint-initdb.d/01_schema.sql -f /docker-entrypoint-initdb.d/02_seed.sql
```

4. Chỉ dùng kiến thức đến Ngày 6: chưa dùng `COUNT`/`SUM` (Ngày 8), `GROUP BY` (Ngày 9) hay JOIN (Ngày 10).

Gợi ý tự chấm: làm đúng 12/16 bài trở lên là sẵn sàng sang chặng 2. Sai bài nào, đọc lại ngày ghi trong ngoặc ở đầu bài đó.

## Ôn nhanh

| Ngày | Ý chính cần nhớ |
| --- | --- |
| 1 | SQL là ngôn ngữ khai báo: bạn nói muốn gì, database tự tìm cách lấy. `\dt` liệt kê bảng, `\d ten_bang` xem cấu trúc. Nhóm lệnh: DDL (`CREATE`, `ALTER`, `DROP`), DML (`SELECT`, `INSERT`, `UPDATE`, `DELETE`), DCL (`GRANT`, `REVOKE`), TCL (`BEGIN`, `COMMIT`, `ROLLBACK`) |
| 2 | Tiền dùng `NUMERIC`, không dùng `FLOAT`. Khóa chính `GENERATED ALWAYS AS IDENTITY`. Ràng buộc `NOT NULL`, `UNIQUE`, `CHECK`, `DEFAULT`, khóa ngoại `REFERENCES ... ON DELETE` |
| 3 | `SELECT ... FROM ... WHERE`; `IN`, `BETWEEN`, `LIKE`/`ILIKE`; `IS NULL`, không bao giờ `= NULL`; `NOT` > `AND` > `OR`, nên dùng ngoặc khi trộn `AND`/`OR` |
| 4 | `ORDER BY` nhiều cột, `ASC`/`DESC`, `NULLS FIRST/LAST`; `LIMIT ... OFFSET ...`; phân trang cần `ORDER BY` xác định duy nhất thứ tự |
| 5 | `INT / INT` chia nguyên; `||` nối chuỗi; `UPPER`, `TRIM`, `REPLACE`, `SUBSTRING`; `EXTRACT`, `AGE`, `INTERVAL`; `::kieu`; `ROUND`; `COALESCE`, `NULLIF` |
| 6 | `INSERT ... RETURNING`, `INSERT ... SELECT`, `ON CONFLICT`; `UPDATE ... FROM`; `DELETE`; `TRUNCATE`. Quy trình an toàn: SELECT xem trước, `BEGIN`, kiểm tra, `COMMIT`/`ROLLBACK` |

## Lỗi thường gặp (tổng hợp chặng 1)

| Lỗi | Ví dụ sai | Cách đúng |
| --- | --- | --- |
| So sánh với NULL bằng `=` | `WHERE phone = NULL` (luôn 0 dòng) | `WHERE phone IS NULL` |
| Quên rằng `<>` bỏ qua NULL | `WHERE city <> 'Hà Nội'` không trả khách chưa có city | thêm `OR city IS NULL` nếu muốn lấy cả họ (Bài 7) |
| Trộn `AND`/`OR` không ngoặc | `status = 'paid' OR status = 'shipped' AND ...` | `(status = 'paid' OR status = 'shipped') AND ...` (Bài 8) |
| Chia nguyên | `(price - cost_price) / price` ra 0 | nhân `100.0` hoặc ép `::NUMERIC` trước khi chia (Bài 9) |
| Phân trang không có thứ tự duy nhất | `ORDER BY price LIMIT 5 OFFSET 5` khi nhiều sản phẩm cùng giá | thêm cột khóa: `ORDER BY price DESC, product_id` (Bài 11) |
| Dùng `FLOAT` cho tiền | `price FLOAT` | `price NUMERIC(12,0)` |
| `UPDATE`/`DELETE` không xem trước | sửa theo tên, sửa nhầm hai "Nguyễn Văn An" | SELECT trước, lọc theo khóa chính, chạy trong `BEGIN` |

## Bài tập

### Cơ bản

**Bài 1 (Ngày 1, 2).** Không đọc file schema, dùng lệnh psql để xem cấu trúc bảng `order_items`. Trả lời: khóa chính gồm những cột nào? Cột `discount` có kiểu gì, mặc định bao nhiêu, bị ràng buộc gì? Xóa một đơn hàng thì các dòng của nó trong `order_items` ra sao?

<details>
<summary>Đáp án</summary>

```text
\d order_items
```

Kết quả:

```text
                  Table "shop.order_items"
   Column   |     Type      | Collation | Nullable | Default
------------+---------------+-----------+----------+---------
 order_id   | integer       |           | not null |
 product_id | integer       |           | not null |
 quantity   | integer       |           | not null |
 unit_price | numeric(12,0) |           | not null |
 discount   | numeric(3,2)  |           | not null | 0
Indexes:
    "order_items_pkey" PRIMARY KEY, btree (order_id, product_id)
    "order_items_product_id_idx" btree (product_id)
Check constraints:
    "order_items_discount_check" CHECK (discount >= 0::numeric AND discount <= 1::numeric)
    "order_items_quantity_check" CHECK (quantity > 0)
    "order_items_unit_price_check" CHECK (unit_price >= 0::numeric)
Foreign-key constraints:
    "order_items_order_id_fkey" FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
    "order_items_product_id_fkey" FOREIGN KEY (product_id) REFERENCES products(product_id)
```

- Khóa chính ghép từ hai cột `(order_id, product_id)`: một sản phẩm chỉ xuất hiện một lần trong mỗi đơn.
- `discount` là `numeric(3,2)` (tối đa 9.99, hai chữ số thập phân), mặc định `0`, `CHECK` trong khoảng 0 đến 1.
- `ON DELETE CASCADE`: xóa đơn thì các dòng hàng của đơn bị xóa theo.
</details>

**Bài 2 (Ngày 3, 4).** Liệt kê `sku`, `name`, `price` của các sản phẩm có giá từ 5 triệu đến 10 triệu (tính cả hai đầu), giá cao xếp trước.

<details>
<summary>Đáp án</summary>

```sql
SELECT sku, name, price
FROM products
WHERE price BETWEEN 5000000 AND 10000000
ORDER BY price DESC;
```

Kết quả:

| sku | name | price |
| --- | --- | --- |
| PC-003 | PC văn phòng DSC Basic | 9990000 |
| TAB-002 | Samsung Galaxy Tab S9 FE | 9490000 |
| ACC-004 | Tai nghe Sony WH-1000XM5 | 7990000 |
| PC-001 | Màn hình LG UltraGear 27 inch | 6490000 |
| ACC-005 | Tai nghe AirPods Pro 2 | 5990000 |
</details>

**Bài 3 (Ngày 3).** Bộ phận chăm sóc khách cần danh sách khách thiếu số điện thoại hoặc thiếu email: `customer_id`, `full_name`, `email`, `phone`, sắp theo `customer_id`.

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id, full_name, email, phone
FROM customers
WHERE phone IS NULL OR email IS NULL
ORDER BY customer_id;
```

Kết quả:

| customer_id | full_name | email | phone |
| --- | --- | --- | --- |
| 3 | Lê Hoàng Cường | cuong.le@outlook.com | NULL |
| 5 | Hoàng Thị Em | NULL | 0934567890 |
| 7 | Đặng Thu Giang | giang.dang@gmail.com | NULL |
| 13 | Phan Thị Oanh | oanh.phan@hotmail.com | NULL |
| 17 | Châu Ngọc Trâm | NULL | NULL |
</details>

**Bài 4 (Ngày 3, 4).** 5 sản phẩm đắt nhất đang kinh doanh (`is_active = TRUE`).

<details>
<summary>Đáp án</summary>

```sql
SELECT sku, name, price
FROM products
WHERE is_active = TRUE
ORDER BY price DESC
LIMIT 5;
```

Kết quả:

| sku | name | price |
| --- | --- | --- |
| LAP-001 | ASUS ROG Strix G16 | 32990000 |
| LAP-002 | Lenovo Legion 5 | 29990000 |
| LAP-005 | MacBook Air M2 13 inch | 24990000 |
| LAP-003 | Acer Nitro V 15 | 21990000 |
| PHN-001 | iPhone 15 128GB | 19990000 |
</details>

**Bài 5 (Ngày 3).** Tìm các khách là sinh viên HCMUTE (email kết thúc bằng `@student.hcmute.edu.vn`).

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id, full_name, email
FROM customers
WHERE email LIKE '%@student.hcmute.edu.vn'
ORDER BY customer_id;
```

Kết quả:

| customer_id | full_name | email |
| --- | --- | --- |
| 6 | Võ Quốc Phong | phong.vo@student.hcmute.edu.vn |
| 10 | Dương Minh Khoa | khoa.duong@student.hcmute.edu.vn |
| 14 | Huỳnh Tấn Phát | phat.huynh@student.hcmute.edu.vn |
</details>

**Bài 6 (Ngày 3, 4).** Tìm sản phẩm của Logitech hoặc Samsung dựa vào tên, không phân biệt hoa thường (người dùng có thể gõ `logitech`). Sắp theo giá tăng dần.

<details>
<summary>Đáp án</summary>

```sql
SELECT sku, name, price
FROM products
WHERE name ILIKE '%logitech%'
   OR name ILIKE '%samsung%'
ORDER BY price;
```

Kết quả:

| sku | name | price |
| --- | --- | --- |
| ACC-001 | Chuột Logitech G102 | 399000 |
| ACC-002 | Chuột Logitech MX Master 3S | 2490000 |
| TAB-002 | Samsung Galaxy Tab S9 FE | 9490000 |
| PHN-002 | Samsung Galaxy S24 | 18990000 |

`ILIKE` là của PostgreSQL. Ở hệ khác, viết `LOWER(name) LIKE '%logitech%'`.
</details>

### Vận dụng

**Bài 7 (Ngày 3, logic ba trị).** Viết truy vấn "khách không ở Hà Nội" bằng `WHERE city <> 'Hà Nội'`. So với số khách thực tế (18 khách, 4 người ở Hà Nội), kết quả thiếu ai? Sửa lại để lấy cả những người đó.

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id, full_name, city
FROM customers
WHERE city <> 'Hà Nội'
ORDER BY customer_id;
```

Kết quả: 12 dòng, trong khi `18 - 4 = 14`. Thiếu khách 11 và 17 vì `city` của họ là NULL: `NULL <> 'Hà Nội'` cho ra `UNKNOWN`, không phải `TRUE`, nên `WHERE` loại dòng đó.

```sql
SELECT customer_id, full_name, city
FROM customers
WHERE city <> 'Hà Nội' OR city IS NULL
ORDER BY customer_id;
```

| customer_id | full_name | city |
| --- | --- | --- |
| 1 | Nguyễn Văn An | TP. Hồ Chí Minh |
| 3 | Lê Hoàng Cường | Đà Nẵng |
| 4 | Phạm Minh Duy | TP. Hồ Chí Minh |
| 5 | Hoàng Thị Em | Cần Thơ |
| 6 | Võ Quốc Phong | Hồ Chí Minh |
| 8 | Bùi Văn Hùng | đà nẵng |
| 9 | Ngô Thị Lan | Hải Phòng |
| 10 | Dương Minh Khoa | TP. Hồ Chí Minh |
| 11 | Lý Thanh Mai | NULL |
| 12 | Trịnh Công Nam | Biên Hòa |
| 14 | Huỳnh Tấn Phát | TP.HCM |
| 16 | Tạ Quang Sơn | Cần Thơ |
| 17 | Châu Ngọc Trâm | NULL |
| 18 | Mai Đức Uy | Đà Nẵng |

(14 dòng.) Câu hỏi nghiệp vụ quyết định có lấy khách NULL hay không; điều quan trọng là bạn chọn có chủ đích.
</details>

**Bài 8 (Ngày 3, thứ tự ưu tiên).** Tìm các đơn đang xử lý (trạng thái `paid` hoặc `shipped`) giao tới `TP. Hồ Chí Minh`. Viết thử không có ngoặc và có ngoặc, giải thích vì sao kết quả khác nhau.

<details>
<summary>Đáp án</summary>

Sai (không ngoặc):

```sql
SELECT order_id, status, shipping_city
FROM orders
WHERE status = 'paid' OR status = 'shipped' AND shipping_city = 'TP. Hồ Chí Minh'
ORDER BY order_id;
```

| order_id | status | shipping_city |
| --- | --- | --- |
| 37 | shipped | TP. Hồ Chí Minh |
| 38 | paid | Hà Nội |
| 39 | paid | Hà Nội |

`AND` ưu tiên hơn `OR`, nên câu trên được hiểu là `status = 'paid' OR (status = 'shipped' AND shipping_city = '...')`: mọi đơn `paid` đều lọt vào, kể cả đơn giao Hà Nội.

Đúng:

```sql
SELECT order_id, status, shipping_city
FROM orders
WHERE (status = 'paid' OR status = 'shipped')
  AND shipping_city = 'TP. Hồ Chí Minh'
ORDER BY order_id;
```

| order_id | status | shipping_city |
| --- | --- | --- |
| 37 | shipped | TP. Hồ Chí Minh |

Gọn hơn: `WHERE status IN ('paid', 'shipped') AND shipping_city = 'TP. Hồ Chí Minh'`.
</details>

**Bài 9 (Ngày 4, 5).** Với mỗi sản phẩm, tính tiền lãi `price - cost_price` và tỉ lệ lãi trên giá bán (%, làm tròn 1 chữ số). Lấy 5 sản phẩm có tỉ lệ lãi cao nhất; sản phẩm chưa có giá nhập phải nằm cuối, không được chiếm chỗ đầu bảng.

<details>
<summary>Đáp án</summary>

```sql
SELECT sku, name, price, cost_price,
       price - cost_price                            AS lai,
       ROUND((price - cost_price) * 100.0 / price, 1) AS ti_le_lai
FROM products
ORDER BY ti_le_lai DESC NULLS LAST
LIMIT 5;
```

Kết quả:

| sku | name | price | cost_price | lai | ti_le_lai |
| --- | --- | --- | --- | --- | --- |
| ACC-008 | Cáp USB-C to USB-C 1m | 150000 | 60000 | 90000 | 60.0 |
| ACC-001 | Chuột Logitech G102 | 399000 | 250000 | 149000 | 37.3 |
| ACC-007 | Sạc Anker 65W | 890000 | 600000 | 290000 | 32.6 |
| PHN-004 | Nokia 105 4G | 690000 | 500000 | 190000 | 27.5 |
| ACC-003 | Bàn phím cơ Keychron K2 | 1890000 | 1500000 | 390000 | 20.6 |

Hai điểm cần chú ý: với `DESC`, PostgreSQL mặc định đặt NULL lên đầu, nên phải ghi `NULLS LAST`; nhân `100.0` trước khi chia để không bị chia nguyên. `ORDER BY` dùng được alias `ti_le_lai` vì nó chạy sau `SELECT`.
</details>

**Bài 10 (Ngày 5).** Tính tuổi của 5 khách trẻ nhất (bỏ qua khách chưa có ngày sinh). Để kết quả cố định, tính tuổi tại ngày `2026-10-17`.

<details>
<summary>Đáp án</summary>

```sql
SELECT full_name, birth_date,
       EXTRACT(YEAR FROM AGE(DATE '2026-10-17', birth_date)) AS tuoi
FROM customers
WHERE birth_date IS NOT NULL
ORDER BY birth_date DESC
LIMIT 5;
```

Kết quả:

| full_name | birth_date | tuoi |
| --- | --- | --- |
| Dương Minh Khoa | 2005-02-14 | 21 |
| Huỳnh Tấn Phát | 2004-08-20 | 22 |
| Võ Quốc Phong | 2004-05-12 | 22 |
| Phạm Minh Duy | 2003-01-30 | 23 |
| Tạ Quang Sơn | 2002-12-12 | 23 |

Trong thực tế bạn viết `AGE(CURRENT_DATE, birth_date)` hoặc `AGE(birth_date)`; khi đó kết quả thay đổi theo ngày chạy. Trẻ nhất nghĩa là sinh muộn nhất, nên sắp `birth_date DESC`.
</details>

**Bài 11 (Ngày 4).** Trang sản phẩm hiển thị 5 sản phẩm mỗi trang, sắp giá giảm dần. Viết truy vấn lấy trang 2. Vì sao cần thêm `product_id` vào `ORDER BY`?

<details>
<summary>Đáp án</summary>

```sql
SELECT product_id, sku, name, price
FROM products
ORDER BY price DESC, product_id
LIMIT 5 OFFSET 5;
```

Kết quả:

| product_id | sku | name | price |
| --- | --- | --- | --- |
| 11 | PHN-002 | Samsung Galaxy S24 | 18990000 |
| 4 | LAP-004 | Dell Inspiron 14 | 18490000 |
| 6 | LAP-006 | HP Pavilion 15 | 16990000 |
| 14 | TAB-001 | iPad Air M2 11 inch | 16990000 |
| 9 | PC-003 | PC văn phòng DSC Basic | 9990000 |

`HP Pavilion 15` và `iPad Air M2 11 inch` cùng giá 16.990.000. Nếu chỉ `ORDER BY price DESC`, thứ tự giữa chúng không được đảm bảo, và khi chúng nằm ở ranh giới trang, một sản phẩm có thể hiện ở cả hai trang hoặc biến mất. Thêm cột khóa chính làm thứ tự xác định duy nhất. Trang `n` dùng `OFFSET (n - 1) * 5`.
</details>

**Bài 12 (Ngày 5).** Tạo danh bạ khách ở `Hà Nội` dạng một cột `Tên - Số điện thoại`; ai chưa có số thì ghi `chưa có SĐT`. Sắp theo tên.

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id,
       full_name || ' - ' || COALESCE(phone, 'chưa có SĐT') AS danh_ba
FROM customers
WHERE city = 'Hà Nội'
ORDER BY full_name;
```

Kết quả:

| customer_id | danh_ba |
| --- | --- |
| 7 | Đặng Thu Giang - chưa có SĐT |
| 15 | Nguyễn Văn An - 0966777888 |
| 13 | Phan Thị Oanh - chưa có SĐT |
| 2 | Trần Thị Bình - 0912345678 |

Không có `COALESCE`, `full_name || ' - ' || NULL` cho ra NULL cả chuỗi: khách 7 và 13 sẽ có danh bạ trống. (`CONCAT` thì bỏ qua NULL, nhưng khi đó dòng kết thúc bằng `' - '` lơ lửng.)
</details>

**Bài 13 (Ngày 5).** Liệt kê 5 dòng hàng có giảm giá mang lại thành tiền lớn nhất: `order_id`, `product_id`, `quantity`, `unit_price`, mức giảm dạng chữ như `5%`, và thành tiền `quantity * unit_price * (1 - discount)` làm tròn đến đồng.

<details>
<summary>Đáp án</summary>

```sql
SELECT order_id, product_id, quantity, unit_price,
       (discount * 100)::INT || '%'                    AS giam,
       ROUND(quantity * unit_price * (1 - discount)) AS thanh_tien
FROM order_items
WHERE discount > 0
ORDER BY thanh_tien DESC
LIMIT 5;
```

Kết quả:

| order_id | product_id | quantity | unit_price | giam | thanh_tien |
| --- | --- | --- | --- | --- | --- |
| 27 | 1 | 1 | 32990000 | 5% | 31340500 |
| 18 | 5 | 1 | 24990000 | 5% | 23740500 |
| 7 | 3 | 1 | 22990000 | 5% | 21840500 |
| 24 | 10 | 1 | 19990000 | 5% | 18990500 |
| 35 | 11 | 1 | 18990000 | 10% | 17091000 |

`discount * 100` là `5.00`; ép `::INT` để thành `5` trước khi nối chuỗi.
</details>

**Bài 14 (Ngày 5).** Liệt kê các đơn đặt trong tháng 11/2025: `order_id`, ngày đặt (chỉ phần ngày), giờ đặt (chỉ phần giờ) và ghi chú. Lọc bằng điều kiện khoảng trên `order_date`.

<details>
<summary>Đáp án</summary>

```sql
SELECT order_id,
       order_date::DATE AS ngay,
       order_date::TIME AS gio,
       note
FROM orders
WHERE order_date >= '2025-11-01'
  AND order_date <  '2025-12-01'
ORDER BY order_date;
```

Kết quả:

| order_id | ngay | gio | note |
| --- | --- | --- | --- |
| 21 | 2025-11-11 | 19:00:00 | NULL |
| 22 | 2025-11-11 | 23:30:00 | Săn sale 11/11 |
| 23 | 2025-11-25 | 14:45:00 | NULL |

Điều kiện khoảng `>= ngày đầu tháng AND < ngày đầu tháng sau` không bỏ sót đơn đặt lúc 23:30 ngày cuối tháng, khác với `BETWEEN '2025-11-01' AND '2025-11-30'` (chỉ tới 00:00 ngày 30). Giờ hiển thị theo múi giờ của phiên làm việc; môi trường Docker của khóa học đặt sẵn `Asia/Ho_Chi_Minh`.
</details>

### Thử thách

**Bài 15 (Ngày 2, 6).** Cửa hàng muốn thử tính năng mã giảm giá. Trên một bảng nháp `review_vouchers`:

1. Tạo bảng với các cột: `voucher_id` (khóa chính tự sinh), `code` (tối đa 20 ký tự, bắt buộc, không trùng), `discount_percent` (số nguyên, bắt buộc, từ 1 đến 50), `min_order` (tiền, mặc định 0, không âm), `valid_until` (ngày, bắt buộc), `is_used` (mặc định chưa dùng).
2. Thêm 3 mã trong một lệnh và trả về id: `DSC10` giảm 10%, không có đơn tối thiểu, hạn 31/12/2026; `SINHVIEN15` giảm 15%, đơn tối thiểu 2 triệu, hạn 30/11/2026; `BLACKFRIDAY` giảm 30%, đơn tối thiểu 10 triệu, hạn 28/11/2026.
3. Thử thêm mã `SALE70` giảm 70% và đọc thông báo lỗi.
4. Dùng UPSERT để "phát hành lại" `DSC10`: giảm 12%, hạn mới 31/01/2027.
5. Xóa các mã hết hạn trước 01/12/2026 (xem trước bằng SELECT), rồi xóa bảng nháp.

<details>
<summary>Đáp án</summary>

```sql
DROP TABLE IF EXISTS review_vouchers;
CREATE TABLE review_vouchers (
    voucher_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code             VARCHAR(20)   NOT NULL UNIQUE,
    discount_percent INT           NOT NULL CHECK (discount_percent BETWEEN 1 AND 50),
    min_order        NUMERIC(12,0) NOT NULL DEFAULT 0 CHECK (min_order >= 0),
    valid_until      DATE          NOT NULL,
    is_used          BOOLEAN       NOT NULL DEFAULT FALSE
);

INSERT INTO review_vouchers (code, discount_percent, min_order, valid_until)
VALUES
    ('DSC10',       10,        0, '2026-12-31'),
    ('SINHVIEN15',  15,  2000000, '2026-11-30'),
    ('BLACKFRIDAY', 30, 10000000, '2026-11-28')
RETURNING voucher_id, code, discount_percent, min_order, is_used;
```

| voucher_id | code | discount_percent | min_order | is_used |
| --- | --- | --- | --- | --- |
| 1 | DSC10 | 10 | 0 | f |
| 2 | SINHVIEN15 | 15 | 2000000 | f |
| 3 | BLACKFRIDAY | 30 | 10000000 | f |

```sql
INSERT INTO review_vouchers (code, discount_percent, valid_until)
VALUES ('SALE70', 70, '2026-12-31');
```

```text
ERROR:  new row for relation "review_vouchers" violates check constraint "review_vouchers_discount_percent_check"
DETAIL:  Failing row contains (4, SALE70, 70, 0, 2026-12-31, f).
```

```sql
INSERT INTO review_vouchers (code, discount_percent, valid_until)
VALUES ('DSC10', 12, '2027-01-31')
ON CONFLICT (code) DO UPDATE
SET discount_percent = EXCLUDED.discount_percent,
    valid_until      = EXCLUDED.valid_until
RETURNING voucher_id, code, discount_percent, valid_until;
```

| voucher_id | code | discount_percent | valid_until |
| --- | --- | --- | --- |
| 1 | DSC10 | 12 | 2027-01-31 |

`DSC10` giữ nguyên `voucher_id = 1`: dòng cũ được cập nhật, không có dòng mới.

```sql
SELECT code, discount_percent, valid_until
FROM review_vouchers
WHERE valid_until < '2026-12-01'
ORDER BY valid_until;

DELETE FROM review_vouchers
WHERE valid_until < '2026-12-01'
RETURNING code;

DROP TABLE review_vouchers;
```

Xem trước và kết quả `RETURNING` đều là 2 mã:

| code | discount_percent | valid_until |
| --- | --- | --- |
| BLACKFRIDAY | 30 | 2026-11-28 |
| SINHVIEN15 | 15 | 2026-11-30 |

| code |
| --- |
| SINHVIEN15 |
| BLACKFRIDAY |

(Thứ tự dòng của `RETURNING` theo thứ tự dòng được xóa, không theo `ORDER BY` nào.)
</details>

**Bài 16 (Ngày 6).** Sếp muốn tăng 3% giá (làm tròn đến nghìn) cho mọi sản phẩm thuộc danh mục `Chuột & Bàn phím`, chỉ biết tên danh mục. Làm đủ quy trình an toàn: xem trước, chạy `UPDATE ... FROM` trong transaction với `RETURNING`, kiểm tra số dòng. Ở bài ôn tập này, kết thúc bằng `ROLLBACK`.

<details>
<summary>Đáp án</summary>

Xem trước:

```sql
SELECT category_id FROM categories WHERE name = 'Chuột & Bàn phím';   -- 10

SELECT sku, name, price
FROM products
WHERE category_id = 10
ORDER BY sku;
```

| sku | name | price |
| --- | --- | --- |
| ACC-001 | Chuột Logitech G102 | 399000 |
| ACC-002 | Chuột Logitech MX Master 3S | 2490000 |
| ACC-003 | Bàn phím cơ Keychron K2 | 1890000 |
| ACC-009 | Lót chuột DSC XXL | 250000 |

Chạy thử:

```sql
BEGIN;

UPDATE products
SET price = ROUND(products.price * 1.03, -3)
FROM categories
WHERE categories.category_id = products.category_id
  AND categories.name = 'Chuột & Bàn phím'
RETURNING products.sku, products.name, products.price;

ROLLBACK;
```

| sku | name | price |
| --- | --- | --- |
| ACC-001 | Chuột Logitech G102 | 411000 |
| ACC-002 | Chuột Logitech MX Master 3S | 2565000 |
| ACC-003 | Bàn phím cơ Keychron K2 | 1947000 |
| ACC-009 | Lót chuột DSC XXL | 258000 |

psql báo `UPDATE 4`, khớp 4 dòng xem trước. Nếu là thật, thay `ROLLBACK` bằng `COMMIT`.
</details>

## Tóm tắt

- Đọc dữ liệu: `SELECT` cột cần dùng, `WHERE` để lọc (nhớ ngoặc khi trộn `AND`/`OR`), `ORDER BY` + `LIMIT/OFFSET` để sắp và phân trang với thứ tự xác định duy nhất.
- NULL là "chưa biết": dùng `IS NULL`/`IS NOT NULL`, nhớ rằng `<>` và phép nối chuỗi cũng gặp NULL; `COALESCE` để thay giá trị mặc định, `NULLS LAST` khi sắp xếp.
- Biểu thức: cẩn thận chia nguyên, dùng `ROUND`, ép kiểu `::`, lọc ngày bằng điều kiện khoảng.
- Ghi dữ liệu: ràng buộc là người gác cổng; sửa/xóa theo khóa chính, xem trước bằng SELECT, chạy trong `BEGIN`, kiểm tra rồi mới `COMMIT`.
- Chặng 2 bắt đầu từ [Ngày 8](08-aggregate-functions.md): gom nhiều dòng thành con số thống kê.

## Đọc thêm

- [PostgreSQL tutorial: The SQL Language](https://www.postgresql.org/docs/16/tutorial-sql.html)
- [PostgreSQL: Comparison Functions and Operators](https://www.postgresql.org/docs/16/functions-comparison.html) (`IS NULL`, `IS DISTINCT FROM`)
- [Vì sao NOT IN của bạn trả về 0 dòng? Logic ba trị của SQL và cái bẫy NULL](https://tiennhm.io.vn/blog/sql-null-not-in-three-valued-logic) — đọc trước để chuẩn bị cho Ngày 11.

---

[⬅️ Ngày 6: Thêm, sửa, xóa dữ liệu (INSERT, UPDATE, DELETE)](06-insert-update-delete.md) | [📚 Mục lục](../README.md) | [Ngày 8: Hàm tổng hợp (COUNT, SUM, AVG, MIN, MAX) ➡️](08-aggregate-functions.md)
