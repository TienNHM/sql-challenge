# Ngày 5: Toán tử, biểu thức và hàm thường dùng

> **Tóm tắt:** Truy vấn không chỉ lấy dữ liệu ra mà còn biến đổi nó: tính tiền, ghép chuỗi, tách ngày tháng, đổi kiểu, thay `NULL` bằng giá trị mặc định. Bài này đi qua các toán tử số học (và cái bẫy chia số nguyên), hàm chuỗi, hàm ngày giờ, `CAST`, `ROUND`, `COALESCE`, `NULLIF`, rồi dùng chúng để làm sạch cột `customers.city` đang bị viết lộn xộn.

**Sau bài này bạn có thể:**

- Tính toán đúng trên cột số, biết khi nào `/` là chia nguyên và cách lấy kết quả thập phân.
- Ghép, cắt, đổi hoa thường và thay thế chuỗi bằng `||`, `CONCAT`, `UPPER`, `LOWER`, `TRIM`, `LENGTH`, `SUBSTRING`, `REPLACE`.
- Lấy phần năm/tháng, làm tròn về đầu tháng, cộng trừ khoảng thời gian và tính tuổi bằng `EXTRACT`, `DATE_TRUNC`, `INTERVAL`, `AGE`.
- Đổi kiểu bằng `CAST`/`::`, làm tròn bằng `ROUND`, xử lý `NULL` bằng `COALESCE` và tránh chia cho 0 bằng `NULLIF`.
- Viết được một biểu thức làm sạch dữ liệu chuỗi nhập tay không thống nhất.

**Cần biết trước:** [Ngày 3](03-select-where.md) (`SELECT`, alias, `WHERE`, `NULL`), [Ngày 4](04-order-by-limit.md) (`ORDER BY`, `LIMIT`).

## 1. Toán tử số học

| Toán tử | Ý nghĩa | Ví dụ | Kết quả |
| --- | --- | --- | --- |
| `+` | cộng | `7 + 2` | 9 |
| `-` | trừ | `7 - 2` | 5 |
| `*` | nhân | `7 * 2` | 14 |
| `/` | chia | `7 / 2` | 3 (!) |
| `%` | chia lấy dư | `7 % 2` | 1 |

```sql
SELECT 7 + 2  AS cong,
       7 - 2  AS tru,
       7 * 2  AS nhan,
       7 / 2  AS chia,
       7 % 2  AS du;
```

| cong | tru | nhan | chia | du |
| --- | --- | --- | --- | --- |
| 9 | 5 | 14 | 3 | 1 |

### Chia số nguyên cho số nguyên ra số nguyên

`7 / 2` ra `3`, không phải `3.5`. Trong PostgreSQL, khi **cả hai vế** là số nguyên (`INT`, `BIGINT`, ...) thì `/` là **chia nguyên**, phần thập phân bị cắt bỏ (cắt về phía 0, nên `-7 / 2` là `-3`). Chỉ cần **một** vế là số thập phân (`NUMERIC`) là kết quả có phần thập phân:

```sql
SELECT 7 / 2         AS int_int,
       7 / 2.0       AS int_numeric,
       7::numeric / 2 AS ep_kieu,
       -7 / 2        AS am,
       -7 % 2        AS du_am;
```

| int_int | int_numeric | ep_kieu | am | du_am |
| --- | --- | --- | --- | --- |
| 3 | 3.5000000000000000 | 3.5000000000000000 | -3 | -1 |

(`7::numeric` là ép kiểu sang `NUMERIC`, xem mục 5. Dấu của phần dư theo dấu của số bị chia: `-7 % 2` là `-1`.)

Chia nguyên rất có ích khi đó đúng là điều bạn muốn. Cáp sạc đóng hộp 12 cái, mỗi mã còn được bao nhiêu hộp nguyên và bao nhiêu cái lẻ?

```sql
SELECT sku,
       name,
       stock_quantity,
       stock_quantity / 12 AS so_hop_12,
       stock_quantity % 12 AS con_le
FROM products
WHERE category_id = 12;
```

| sku | name | stock_quantity | so_hop_12 | con_le |
| --- | --- | --- | --- | --- |
| ACC-007 | Sạc Anker 65W | 40 | 3 | 4 |
| ACC-008 | Cáp USB-C to USB-C 1m | 200 | 16 | 8 |

Nhưng khi tính **tỉ lệ phần trăm**, chia nguyên là một lỗi âm thầm. Kho chứa tối đa 200 cái mỗi mã, mỗi mã đang lấp bao nhiêu phần trăm?

```sql
SELECT sku,
       stock_quantity,
       stock_quantity / 200 * 100       AS sai_phan_tram,
       stock_quantity * 100.0 / 200     AS dung_phan_tram
FROM products
WHERE category_id = 12;
```

| sku | stock_quantity | sai_phan_tram | dung_phan_tram |
| --- | --- | --- | --- |
| ACC-007 | 40 | 0 | 20.0000000000000000 |
| ACC-008 | 200 | 100 | 100.0000000000000000 |

`40 / 200` là `0` (chia nguyên), nhân 100 vẫn là `0`. Viết `100.0` (có dấu chấm) để biến phép tính thành số thập phân ngay từ đầu.

> **Ghi chú dialect:** SQL Server và SQLite cũng chia nguyên khi hai vế là số nguyên. MySQL thì khác: `/` luôn trả số thập phân (`7 / 2` ra `3.5000`), muốn chia nguyên phải viết `7 DIV 2`. Code chuyển từ MySQL sang PostgreSQL rất hay dính lỗi này.

### Toán tử % không chỉ cho số nguyên

`%` (hoặc hàm `MOD(a, b)`) lấy phần dư, dùng được cả với `NUMERIC`:

```sql
SELECT 5.5 % 2     AS du_thap_phan,
       MOD(17, 5)  AS ham_mod;
```

| du_thap_phan | ham_mod |
| --- | --- |
| 1.5 | 2 |

Thực tế `%` thường dùng để kiểm tra chẵn lẻ (`order_id % 2 = 0`) hoặc chia vòng (chính file seed của DSC Shop dùng `order_id % 3` để chọn phương thức thanh toán).

### Thứ tự ưu tiên và ngoặc

Như toán phổ thông: `*`, `/`, `%` trước `+`, `-`. Toàn bộ phép toán được tính trước phép so sánh (`=`, `<`, ...), rồi mới tới `NOT`, `AND`, `OR` (đã học ở [Ngày 3](03-select-where.md)).

```sql
SELECT 2 + 3 * 4   AS khong_ngoac,
       (2 + 3) * 4 AS co_ngoac;
```

| khong_ngoac | co_ngoac |
| --- | --- |
| 14 | 20 |

Ví dụ thật: tiền một dòng hàng là `quantity * unit_price * (1 - discount)`. Ngoặc quanh `1 - discount` là bắt buộc.

```sql
SELECT order_id,
       product_id,
       quantity,
       unit_price,
       discount,
       quantity * unit_price * (1 - discount) AS line_total
FROM order_items
WHERE order_id IN (4, 22);
```

| order_id | product_id | quantity | unit_price | discount | line_total |
| --- | --- | --- | --- | --- | --- |
| 4 | 20 | 1 | 5990000 | 0.10 | 5391000.00 |
| 4 | 17 | 1 | 2490000 | 0.00 | 2490000.00 |
| 22 | 20 | 1 | 5990000 | 0.15 | 5091500.00 |
| 22 | 12 | 1 | 4890000 | 0.10 | 4401000.00 |

### Chia cho 0

```sql
SELECT price / stock_quantity
FROM products;
```

```text
ERROR:  division by zero
```

Chỉ cần một sản phẩm hết hàng (`stock_quantity = 0`) là cả câu truy vấn thất bại. Cách xử lý gọn ở mục 6 (`NULLIF`).

## 2. NULL trong biểu thức

Ở [Ngày 3](03-select-where.md) bạn đã thấy so sánh với `NULL` cho ra `UNKNOWN`. Phép tính cũng vậy: **hầu hết phép toán và hàm gặp `NULL` đều trả `NULL`**. "Giá bán trừ một số chưa biết" thì vẫn là chưa biết.

```sql
SELECT name,
       price,
       cost_price,
       price - cost_price AS profit
FROM products
WHERE cost_price IS NULL;
```

| name | price | cost_price | profit |
| --- | --- | --- | --- |
| HP Pavilion 15 | 16990000 | NULL | NULL |
| Lót chuột DSC XXL | 250000 | NULL | NULL |

```sql
SELECT NULL + 1          AS cong_null,
       NULL * 0          AS nhan_khong,
       'DSC' || NULL     AS noi_null,
       CONCAT('DSC', NULL) AS concat_null;
```

| cong_null | nhan_khong | noi_null | concat_null |
| --- | --- | --- | --- |
| NULL | NULL | NULL | DSC |

Kể cả `NULL * 0` cũng là `NULL`. Ngoại lệ đáng nhớ là hàm `CONCAT`: nó bỏ qua các đối số `NULL`. Mục tiếp theo nói rõ hơn.

## 3. Hàm chuỗi

### Nối chuỗi: `||` và CONCAT

```sql
SELECT sku || ' - ' || name AS san_pham,
       CONCAT(name, ' (', price, ' đ)') AS nhan_gia
FROM products
WHERE category_id = 8;
```

| san_pham | nhan_gia |
| --- | --- |
| TAB-001 - iPad Air M2 11 inch | iPad Air M2 11 inch (16990000 đ) |
| TAB-002 - Samsung Galaxy Tab S9 FE | Samsung Galaxy Tab S9 FE (9490000 đ) |

`CONCAT` tự đổi số sang chuỗi. Khác biệt quan trọng nằm ở `NULL`:

```sql
SELECT full_name,
       full_name || ' <' || email || '>'       AS dung_noi,
       CONCAT(full_name, ' <', email, '>')     AS dung_concat
FROM customers
WHERE customer_id IN (1, 5, 17);
```

| full_name | dung_noi | dung_concat |
| --- | --- | --- |
| Nguyễn Văn An | Nguyễn Văn An &lt;an.nguyen@gmail.com&gt; | Nguyễn Văn An &lt;an.nguyen@gmail.com&gt; |
| Hoàng Thị Em | NULL | Hoàng Thị Em <> |
| Châu Ngọc Trâm | NULL | Châu Ngọc Trâm <> |

`||` gặp `NULL` thì mất cả chuỗi. `CONCAT` giữ được tên nhưng để lại cặp `<>` trống. Cách đẹp nhất là thay `NULL` bằng một chữ có nghĩa bằng `COALESCE` (mục 6, và Bài tập 2).

> **Ghi chú dialect:** Trong MySQL, `||` mặc định là phép **OR logic** chứ không phải nối chuỗi (trừ khi bật chế độ `PIPES_AS_CONCAT`), nên ở MySQL hãy dùng `CONCAT`. SQL Server nối chuỗi bằng `+` hoặc `CONCAT`. `CONCAT` chạy được ở cả ba hệ.

### Hoa thường, khoảng trắng, độ dài

| Hàm | Ý nghĩa |
| --- | --- |
| `UPPER(s)`, `LOWER(s)` | viết hoa hết, viết thường hết |
| `INITCAP(s)` | viết hoa chữ cái đầu mỗi từ (riêng PostgreSQL) |
| `TRIM(s)` | bỏ khoảng trắng hai đầu (`LTRIM`, `RTRIM` cho từng đầu) |
| `LENGTH(s)` | số ký tự |

Các hàm này xử lý đúng chữ tiếng Việt có dấu:

```sql
SELECT city,
       UPPER(city)   AS hoa,
       LOWER(city)   AS thuong,
       INITCAP(city) AS hoa_dau_tu
FROM customers
WHERE customer_id IN (3, 8);
```

| city | hoa | thuong | hoa_dau_tu |
| --- | --- | --- | --- |
| Đà Nẵng | ĐÀ NẴNG | đà nẵng | Đà Nẵng |
| đà nẵng | ĐÀ NẴNG | đà nẵng | Đà Nẵng |

Hai cách viết khác nhau, qua `LOWER` hay `INITCAP` thì thành một. Đây là chìa khóa để làm sạch dữ liệu ở mục 7.

```sql
SELECT '[' || '  Hà Nội  ' || ']'         AS goc,
       '[' || TRIM('  Hà Nội  ') || ']'   AS da_trim,
       LENGTH('  Hà Nội  ')               AS do_dai_goc,
       LENGTH(TRIM('  Hà Nội  '))         AS do_dai_trim;
```

| goc | da_trim | do_dai_goc | do_dai_trim |
| --- | --- | --- | --- |
| [  Hà Nội  ] | [Hà Nội] | 10 | 6 |

`LENGTH` đếm **ký tự**, không phải byte. Chữ có dấu trong UTF-8 chiếm nhiều byte hơn:

```sql
SELECT name,
       LENGTH(name)       AS so_ky_tu,
       OCTET_LENGTH(name) AS so_byte
FROM products
WHERE sku IN ('PC-003', 'ACC-001');
```

| name | so_ky_tu | so_byte |
| --- | --- | --- |
| PC văn phòng DSC Basic | 22 | 24 |
| Chuột Logitech G102 | 19 | 21 |

### Cắt chuỗi: SUBSTRING, LEFT, RIGHT, POSITION

`SUBSTRING(s FROM vi_tri FOR so_ky_tu)` lấy một đoạn, vị trí đếm từ 1. Cũng viết được `SUBSTRING(s, vi_tri, so_ky_tu)`. `LEFT(s, n)`/`RIGHT(s, n)` lấy n ký tự đầu/cuối.

```sql
SELECT sku,
       SUBSTRING(sku FROM 1 FOR 3) AS loai,
       SUBSTRING(sku, 5)           AS so_thu_tu,
       LEFT(sku, 3)                AS loai_left
FROM products
WHERE product_id IN (1, 7, 10, 16);
```

| sku | loai | so_thu_tu | loai_left |
| --- | --- | --- | --- |
| LAP-001 | LAP | 001 | LAP |
| PC-001 | PC- | 01 | PC- |
| PHN-001 | PHN | 001 | PHN |
| ACC-001 | ACC | 001 | ACC |

Dòng `PC-001` cho thấy giới hạn của việc cắt theo vị trí cố định: mã `PC` chỉ có 2 chữ nên lấy 3 ký tự bị dính dấu `-`. Khi độ dài thay đổi, hãy cắt theo **vị trí của một ký tự mốc**. `POSITION('@' IN email)` cho biết `@` nằm ở đâu, từ đó lấy tên miền email:

```sql
SELECT email,
       POSITION('@' IN email)                        AS vi_tri_a_cong,
       SUBSTRING(email FROM POSITION('@' IN email) + 1) AS ten_mien
FROM customers
WHERE customer_id IN (1, 3, 6, 8);
```

| email | vi_tri_a_cong | ten_mien |
| --- | --- | --- |
| an.nguyen@gmail.com | 10 | gmail.com |
| cuong.le@outlook.com | 9 | outlook.com |
| phong.vo@student.hcmute.edu.vn | 9 | student.hcmute.edu.vn |
| hung.bui@yahoo.com | 9 | yahoo.com |

### Thay thế: REPLACE

`REPLACE(s, tu, thanh)` thay **mọi** chỗ xuất hiện của `tu` bằng `thanh`, có phân biệt hoa thường:

```sql
SELECT name,
       REPLACE(name, 'inch', '"') AS ten_ngan
FROM products
WHERE name LIKE '%inch%';
```

| name | ten_ngan |
| --- | --- |
| MacBook Air M2 13 inch | MacBook Air M2 13 " |
| Màn hình LG UltraGear 27 inch | Màn hình LG UltraGear 27 " |
| iPad Air M2 11 inch | iPad Air M2 11 " |

## 4. Hàm ngày giờ

Nhắc lại kiểu dữ liệu ([Ngày 2](02-table-structure-and-data-types.md)): `DATE` chỉ có ngày (`birth_date`), `TIMESTAMPTZ` có ngày, giờ và múi giờ (`order_date`, `created_at`). Database DSC Shop đặt múi giờ `Asia/Ho_Chi_Minh`, nên giờ hiện ra kèm `+07`.

### Thời điểm hiện tại

```sql
SELECT CURRENT_DATE AS hom_nay,
       now()        AS bay_gio;
```

| hom_nay | bay_gio |
| --- | --- |
| 2026-10-17 | 2026-10-17 16:12:13.443293+07 |

Kết quả tùy lúc bạn chạy. `now()` (hoặc `CURRENT_TIMESTAMP`) trả thời điểm **bắt đầu transaction**, nên gọi nhiều lần trong một câu truy vấn vẫn ra cùng một giá trị.

### EXTRACT: lấy một phần của ngày giờ

```sql
SELECT order_id,
       order_date,
       EXTRACT(YEAR FROM order_date)  AS nam,
       EXTRACT(MONTH FROM order_date) AS thang,
       EXTRACT(HOUR FROM order_date)  AS gio
FROM orders
WHERE order_id IN (1, 22, 40);
```

| order_id | order_date | nam | thang | gio |
| --- | --- | --- | --- | --- |
| 1 | 2025-01-12 10:15:00+07 | 2025 | 1 | 10 |
| 22 | 2025-11-11 23:30:00+07 | 2025 | 11 | 23 |
| 40 | 2026-10-14 22:00:00+07 | 2026 | 10 | 22 |

Các phần hay dùng khác: `DAY`, `MINUTE`, `QUARTER` (quý), `ISODOW` (thứ trong tuần, 1 là thứ Hai, 7 là Chủ nhật), `EPOCH` (số giây từ 1970).

> **Ghi chú dialect:** MySQL và SQL Server có hàm riêng `YEAR(d)`, `MONTH(d)`, `DAY(d)`. PostgreSQL **không có** các hàm này (báo lỗi `function year(...) does not exist`), hãy dùng `EXTRACT(YEAR FROM d)`, cú pháp chuẩn SQL mà MySQL cũng hiểu.

### DATE_TRUNC và ép về ngày

`DATE_TRUNC('month', t)` cắt về **đầu tháng** (tương tự `'year'`, `'week'`, `'day'`, `'hour'`). Rất hay dùng để gom dữ liệu theo tháng khi học `GROUP BY` ở [Ngày 9](09-group-by-having.md). `order_date::date` bỏ phần giờ, chỉ giữ ngày.

```sql
SELECT order_id,
       order_date,
       DATE_TRUNC('month', order_date) AS dau_thang,
       order_date::date                AS chi_ngay
FROM orders
WHERE order_id IN (1, 22, 40);
```

| order_id | order_date | dau_thang | chi_ngay |
| --- | --- | --- | --- |
| 1 | 2025-01-12 10:15:00+07 | 2025-01-01 00:00:00+07 | 2025-01-12 |
| 22 | 2025-11-11 23:30:00+07 | 2025-11-01 00:00:00+07 | 2025-11-11 |
| 40 | 2026-10-14 22:00:00+07 | 2026-10-01 00:00:00+07 | 2026-10-14 |

### TO_CHAR: định dạng để hiển thị

```sql
SELECT order_id,
       TO_CHAR(order_date, 'DD/MM/YYYY HH24:MI') AS ngay_dat
FROM orders
WHERE order_id IN (1, 22, 40);
```

| order_id | ngay_dat |
| --- | --- |
| 1 | 12/01/2025 10:15 |
| 22 | 11/11/2025 23:30 |
| 40 | 14/10/2026 22:00 |

Kết quả của `TO_CHAR` là **chuỗi**: đẹp để hiển thị nhưng đừng dùng nó để so sánh hay sắp xếp ngày (chuỗi `'12/01/2025'` đứng trước `'14/10/2024'` khi sắp theo chữ).

### INTERVAL: cộng trừ thời gian

`INTERVAL '3 days'`, `INTERVAL '2 hours'`, `INTERVAL '1 month'` là các **khoảng thời gian**. Cộng vào ngày giờ để ra ngày giờ mới:

```sql
SELECT order_id,
       order_date,
       order_date + INTERVAL '3 days'   AS du_kien_giao,
       order_date - INTERVAL '2 hours'  AS truoc_2_gio
FROM orders
WHERE order_id IN (1, 40);
```

| order_id | order_date | du_kien_giao | truoc_2_gio |
| --- | --- | --- | --- |
| 1 | 2025-01-12 10:15:00+07 | 2025-01-15 10:15:00+07 | 2025-01-12 08:15:00+07 |
| 40 | 2026-10-14 22:00:00+07 | 2026-10-17 22:00:00+07 | 2026-10-14 20:00:00+07 |

Trừ hai `DATE` ra **số ngày** (số nguyên). Trừ hai `TIMESTAMPTZ` ra một `INTERVAL`:

```sql
SELECT DATE '2026-10-17' - DATE '2026-09-02'       AS so_ngay,
       TIMESTAMPTZ '2026-10-17 12:00+07'
         - TIMESTAMPTZ '2026-10-14 22:00+07'       AS khoang_thoi_gian;
```

| so_ngay | khoang_thoi_gian |
| --- | --- |
| 45 | 2 days 14:00:00 |

(`DATE '2026-10-17'` là cách viết một hằng ngày tháng có kiểu rõ ràng.)

Kết hợp với `now()` để lọc "30 ngày gần đây":

```sql
SELECT order_id, order_date, status
FROM orders
WHERE order_date >= now() - INTERVAL '30 days';
```

Kết quả khi chạy ngày 17/10/2026 (bạn chạy ngày khác sẽ ra khác, có thể 0 dòng):

| order_id | order_date | status |
| --- | --- | --- |
| 38 | 2026-09-20 16:30:00+07 | paid |
| 39 | 2026-10-05 09:00:00+07 | paid |
| 40 | 2026-10-14 22:00:00+07 | pending |

### AGE: tính tuổi

`AGE(moc, ngay_sinh)` trả khoảng cách dạng năm/tháng/ngày. Lấy phần năm bằng `EXTRACT` là ra tuổi. Ví dụ dùng mốc cố định 17/10/2026 để ai chạy cũng ra cùng kết quả; thực tế bạn dùng `AGE(birth_date)` (mốc là hôm nay).

```sql
SELECT full_name,
       birth_date,
       AGE(DATE '2026-10-17', birth_date)                   AS tuoi_day_du,
       EXTRACT(YEAR FROM AGE(DATE '2026-10-17', birth_date)) AS tuoi
FROM customers
WHERE customer_id IN (1, 8, 10);
```

| full_name | birth_date | tuoi_day_du | tuoi |
| --- | --- | --- | --- |
| Nguyễn Văn An | 2002-03-15 | 24 years 7 mons 2 days | 24 |
| Bùi Văn Hùng | 1985-04-18 | 41 years 5 mons 29 days | 41 |
| Dương Minh Khoa | 2005-02-14 | 21 years 8 mons 3 days | 21 |

### Lọc theo năm, tháng: dùng khoảng thay vì EXTRACT

`WHERE EXTRACT(YEAR FROM order_date) = 2026` cho kết quả đúng, nhưng khi bảng lớn và có index trên `order_date`, PostgreSQL không dùng được index đó vì cột đã bị bọc trong hàm. Thói quen tốt là lọc bằng khoảng nửa mở như ở [Ngày 3](03-select-where.md). Đơn quý 1/2026:

```sql
SELECT order_id, order_date
FROM orders
WHERE order_date >= '2026-01-01'
  AND order_date <  '2026-04-01';
```

| order_id | order_date |
| --- | --- |
| 26 | 2026-01-08 09:30:00+07 |
| 27 | 2026-01-20 15:00:00+07 |
| 28 | 2026-02-02 10:45:00+07 |
| 29 | 2026-02-25 13:30:00+07 |
| 30 | 2026-03-15 21:00:00+07 |

Lý do chi tiết (gọi là *sargability*) sẽ được đo bằng số liệu ở [Ngày 15](15-index.md) và [Ngày 28](28-sql-query-optimization.md).

## 5. Ép kiểu và làm tròn

### CAST và `::`

`CAST(gia_tri AS kieu)` là cú pháp chuẩn. PostgreSQL có cách viết ngắn `gia_tri::kieu`, hai cách như nhau.

```sql
SELECT CAST('123' AS INT)       AS chuoi_sang_so,
       '2026-10-17'::DATE        AS chuoi_sang_ngay,
       2.5::INT                  AS lam_tron_2_5,
       3.49::INT                 AS lam_tron_3_49,
       price::TEXT || ' đ'        AS so_sang_chuoi
FROM products
WHERE product_id = 1;
```

| chuoi_sang_so | chuoi_sang_ngay | lam_tron_2_5 | lam_tron_3_49 | so_sang_chuoi |
| --- | --- | --- | --- | --- |
| 123 | 2026-10-17 | 3 | 3 | 32990000 đ |

Đổi `NUMERIC` sang `INT` là **làm tròn** (2.5 thành 3), không phải cắt.

Với cột ngày giờ, `::DATE` giữ phần ngày, `::TIME` giữ phần giờ (theo múi giờ của phiên, ở đây là `+07`):

```sql
SELECT order_id,
       order_date,
       order_date::DATE AS ngay,
       order_date::TIME AS gio
FROM orders
WHERE order_id IN (1, 22);
```

| order_id | order_date | ngay | gio |
| --- | --- | --- | --- |
| 1 | 2025-01-12 10:15:00+07 | 2025-01-12 | 10:15:00 |
| 22 | 2025-11-11 23:30:00+07 | 2025-11-11 | 23:30:00 |

Chuỗi không hợp lệ thì báo lỗi ngay:

```sql
SELECT CAST('abc' AS INT);
```

```text
ERROR:  invalid input syntax for type integer: "abc"
LINE 1: SELECT CAST('abc' AS INT);
                    ^
```

> **Ghi chú dialect:** `::` chỉ có trong PostgreSQL. Code cần chạy trên nhiều hệ thì dùng `CAST(... AS ...)`. MySQL ép sang số nguyên bằng `CAST(x AS SIGNED)` chứ không phải `AS INT`.

### ROUND

`ROUND(x)` làm tròn tới số nguyên, `ROUND(x, n)` giữ `n` chữ số thập phân. `n` âm thì làm tròn sang trái dấu phẩy: `-3` là tròn nghìn, rất hợp với tiền VNĐ.

```sql
SELECT order_id,
       product_id,
       quantity * unit_price * (1 - discount)            AS line_total,
       ROUND(quantity * unit_price * (1 - discount))     AS lam_tron_dong,
       ROUND(quantity * unit_price * (1 - discount), -3) AS lam_tron_nghin
FROM order_items
WHERE order_id IN (4, 22);
```

| order_id | product_id | line_total | lam_tron_dong | lam_tron_nghin |
| --- | --- | --- | --- | --- |
| 4 | 20 | 5391000.00 | 5391000 | 5391000 |
| 4 | 17 | 2490000.00 | 2490000 | 2490000 |
| 22 | 20 | 5091500.00 | 5091500 | 5092000 |
| 22 | 12 | 4401000.00 | 4401000 | 4401000 |

Chỉ làm tròn ở bước **hiển thị cuối cùng**. Làm tròn từng dòng rồi mới cộng tổng có thể lệch so với cộng rồi mới làm tròn.

## 6. COALESCE và NULLIF

### COALESCE: giá trị đầu tiên không NULL

`COALESCE(a, b, c, ...)` trả đối số **đầu tiên khác `NULL`**. Dùng để thay `NULL` bằng giá trị mặc định, hoặc chọn nguồn dự phòng:

```sql
SELECT full_name,
       COALESCE(phone, 'chưa có')             AS phone,
       COALESCE(email, phone, 'không liên lạc được') AS lien_he
FROM customers
WHERE customer_id IN (3, 5, 17);
```

| full_name | phone | lien_he |
| --- | --- | --- |
| Lê Hoàng Cường | chưa có | cuong.le@outlook.com |
| Hoàng Thị Em | 0934567890 | 0934567890 |
| Châu Ngọc Trâm | chưa có | không liên lạc được |

Các đối số phải cùng kiểu (hoặc đổi được về cùng kiểu). `COALESCE(cost_price, 'chưa có')` sẽ lỗi vì trộn số với chữ; muốn vậy phải ép số sang chuỗi trước (Bài tập 6).

**Cẩn thận: thay NULL bằng 0 có thể nói dối.**

```sql
SELECT name,
       price,
       cost_price,
       price - COALESCE(cost_price, 0) AS profit_sai
FROM products
WHERE cost_price IS NULL;
```

| name | price | cost_price | profit_sai |
| --- | --- | --- | --- |
| HP Pavilion 15 | 16990000 | NULL | 16990000 |
| Lót chuột DSC XXL | 250000 | NULL | 250000 |

Báo cáo này nói chiếc HP lãi gần 17 triệu, điều không thể đúng. "Chưa biết giá nhập" không phải "giá nhập bằng 0". Chỉ thay `NULL` bằng 0 khi 0 thật sự đúng nghĩa (ví dụ "chưa có đơn nào" thì số đơn là 0).

### NULLIF: biến một giá trị thành NULL

`NULLIF(a, b)` trả `NULL` nếu `a = b`, ngược lại trả `a`. Công dụng phổ biến nhất là **tránh chia cho 0**: biến mẫu số 0 thành `NULL`, phép chia ra `NULL` thay vì làm sập cả truy vấn.

```sql
SELECT NULLIF(5, 5)     AS bang_nhau,
       NULLIF(5, 0)     AS khac_nhau,
       10 / NULLIF(0, 0) AS chia_an_toan;
```

| bang_nhau | khac_nhau | chia_an_toan |
| --- | --- | --- |
| NULL | 5 | NULL |

Quay lại câu bị lỗi `division by zero` ở mục 1:

```sql
SELECT sku,
       price,
       stock_quantity,
       price / NULLIF(stock_quantity, 0) AS gia_chia_ton
FROM products
WHERE category_id = 11;
```

| sku | price | stock_quantity | gia_chia_ton |
| --- | --- | --- | --- |
| ACC-004 | 7990000 | 8 | 998750.000000000000 |
| ACC-005 | 5990000 | 12 | 499166.666666666667 |
| ACC-006 | 2690000 | 0 | NULL |

Công dụng thứ hai: biến chuỗi rỗng thành `NULL`, ví dụ `NULLIF(TRIM(note), '')` coi ghi chú chỉ có dấu cách như không có ghi chú.

## 7. Thực hành: làm sạch customers.city

Từ [Ngày 3](03-select-where.md) ta đã biết cột `city` được nhập tay và rất lộn xộn:

```sql
SELECT DISTINCT city
FROM customers
ORDER BY city;
```

| city |
| --- |
| Biên Hòa |
| Cần Thơ |
| đà nẵng |
| Đà Nẵng |
| Hải Phòng |
| Hà Nội |
| Hồ Chí Minh |
| TP.HCM |
| TP. Hồ Chí Minh |
| NULL |

10 giá trị, nhưng thực ra chỉ có 6 thành phố cộng với "chưa rõ". Mục tiêu: viết **một biểu thức** biến mọi cách viết về một dạng chuẩn. Ta chọn dạng chuẩn là `Hồ Chí Minh`, `Đà Nẵng`, ... và `Chưa rõ` cho `NULL`.

**Thử lần 1:** `TRIM` rồi `INITCAP` để thống nhất hoa thường.

```sql
SELECT DISTINCT
       city,
       INITCAP(TRIM(city)) AS buoc_1
FROM customers
ORDER BY city;
```

| city | buoc_1 |
| --- | --- |
| Biên Hòa | Biên Hòa |
| Cần Thơ | Cần Thơ |
| đà nẵng | Đà Nẵng |
| Đà Nẵng | Đà Nẵng |
| Hải Phòng | Hải Phòng |
| Hà Nội | Hà Nội |
| Hồ Chí Minh | Hồ Chí Minh |
| TP.HCM | Tp.Hcm |
| TP. Hồ Chí Minh | Tp. Hồ Chí Minh |
| NULL | NULL |

Đà Nẵng đã ổn. Nhưng `INITCAP` biến `TP.HCM` thành `Tp.Hcm`: nếu sau đó mới `REPLACE(..., 'TP.HCM', ...)` thì không khớp nữa vì `REPLACE` phân biệt hoa thường. **Thứ tự gọi hàm quan trọng.**

**Thử lần 2:** `REPLACE` các dạng viết tắt trước, `INITCAP` sau. Hai lần `REPLACE` lồng nhau: trong cùng đổi `TP.HCM` thành `Hồ Chí Minh`, ngoài đó bỏ tiền tố `TP. `.

```sql
SELECT DISTINCT
       city,
       INITCAP(REPLACE(REPLACE(TRIM(city), 'TP.HCM', 'Hồ Chí Minh'), 'TP. ', '')) AS buoc_2
FROM customers
ORDER BY buoc_2;
```

| city | buoc_2 |
| --- | --- |
| Biên Hòa | Biên Hòa |
| Cần Thơ | Cần Thơ |
| đà nẵng | Đà Nẵng |
| Đà Nẵng | Đà Nẵng |
| Hải Phòng | Hải Phòng |
| Hà Nội | Hà Nội |
| Hồ Chí Minh | Hồ Chí Minh |
| TP.HCM | Hồ Chí Minh |
| TP. Hồ Chí Minh | Hồ Chí Minh |
| NULL | NULL |

**Bước cuối:** bọc ngoài bằng `COALESCE` cho `NULL`, rồi xem còn bao nhiêu giá trị khác nhau:

```sql
SELECT DISTINCT
       COALESCE(
           INITCAP(REPLACE(REPLACE(TRIM(city), 'TP.HCM', 'Hồ Chí Minh'), 'TP. ', '')),
           'Chưa rõ'
       ) AS city_clean
FROM customers
ORDER BY city_clean;
```

| city_clean |
| --- |
| Biên Hòa |
| Cần Thơ |
| Chưa rõ |
| Đà Nẵng |
| Hải Phòng |
| Hà Nội |
| Hồ Chí Minh |

Từ 10 còn 7, đúng 6 thành phố và một nhóm "Chưa rõ".

![Biểu thức làm sạch cột customers.city chạy từ trong ra ngoài qua 5 bước: TRIM bỏ khoảng trắng thừa; REPLACE đổi 'TP.HCM' thành 'Hồ Chí Minh'; REPLACE bỏ tiền tố 'TP. ' nên 'TP. Hồ Chí Minh' thành 'Hồ Chí Minh'; INITCAP đổi 'đà nẵng' thành 'Đà Nẵng'; COALESCE đổi NULL thành 'Chưa rõ'. Sáu cách viết gốc 'TP. Hồ Chí Minh', 'Hồ Chí Minh', 'TP.HCM', 'Đà Nẵng', 'đà nẵng', NULL thu về ba giá trị 'Hồ Chí Minh', 'Đà Nẵng', 'Chưa rõ'. Cả cột có 10 giá trị khác nhau, còn 7 sau khi làm sạch. Nếu INITCAP chạy trước REPLACE thì 'TP.HCM' thành 'Tp.Hcm' và không khớp nữa.](img/lam-sach-city.png#gh-light-mode-only)
![Biểu thức làm sạch cột customers.city chạy từ trong ra ngoài qua 5 bước: TRIM bỏ khoảng trắng thừa; REPLACE đổi 'TP.HCM' thành 'Hồ Chí Minh'; REPLACE bỏ tiền tố 'TP. ' nên 'TP. Hồ Chí Minh' thành 'Hồ Chí Minh'; INITCAP đổi 'đà nẵng' thành 'Đà Nẵng'; COALESCE đổi NULL thành 'Chưa rõ'. Sáu cách viết gốc 'TP. Hồ Chí Minh', 'Hồ Chí Minh', 'TP.HCM', 'Đà Nẵng', 'đà nẵng', NULL thu về ba giá trị 'Hồ Chí Minh', 'Đà Nẵng', 'Chưa rõ'. Cả cột có 10 giá trị khác nhau, còn 7 sau khi làm sạch. Nếu INITCAP chạy trước REPLACE thì 'TP.HCM' thành 'Tp.Hcm' và không khớp nữa.](img/lam-sach-city-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/operators-expressions/lam-sach-city.html) · [nền tối](../diagrams/operators-expressions/lam-sach-city-dark.html)</small>

Giờ tìm "mọi khách ở TP. Hồ Chí Minh" chỉ cần một điều kiện:

```sql
SELECT customer_id,
       full_name,
       city,
       COALESCE(
           INITCAP(REPLACE(REPLACE(TRIM(city), 'TP.HCM', 'Hồ Chí Minh'), 'TP. ', '')),
           'Chưa rõ'
       ) AS city_clean
FROM customers
WHERE INITCAP(REPLACE(REPLACE(TRIM(city), 'TP.HCM', 'Hồ Chí Minh'), 'TP. ', '')) = 'Hồ Chí Minh'
ORDER BY customer_id;
```

| customer_id | full_name | city | city_clean |
| --- | --- | --- | --- |
| 1 | Nguyễn Văn An | TP. Hồ Chí Minh | Hồ Chí Minh |
| 4 | Phạm Minh Duy | TP. Hồ Chí Minh | Hồ Chí Minh |
| 6 | Võ Quốc Phong | Hồ Chí Minh | Hồ Chí Minh |
| 10 | Dương Minh Khoa | TP. Hồ Chí Minh | Hồ Chí Minh |
| 14 | Huỳnh Tấn Phát | TP.HCM | Hồ Chí Minh |

Lưu ý:

- Đây mới chỉ là `SELECT`: bảng gốc **không đổi**. Ghi giá trị sạch vào bảng bằng `UPDATE` là việc của [Ngày 6](06-insert-update-delete.md).
- Phải lặp lại biểu thức trong `WHERE` vì alias `city_clean` chưa tồn tại lúc `WHERE` chạy ([Ngày 3](03-select-where.md)).
- Chuỗi `REPLACE` lồng nhau chỉ hợp với vài trường hợp. Khi có nhiều quy tắc hơn, `CASE` ([Ngày 13](13-case-when.md)) hoặc một bảng ánh xạ "cách viết → tên chuẩn" kết hợp `JOIN` ([Ngày 10](10-join.md)) sẽ dễ bảo trì hơn. Còn cách bền vững nhất là chặn dữ liệu bẩn từ đầu: bảng `cities` riêng và khóa ngoại ([Ngày 27](27-database-design-best-practices.md)).

## Lỗi thường gặp

**1. Chia số nguyên ra 0.** `stock_quantity / 200 * 100` ra 0 với mọi giá trị dưới 200.

```sql
-- Sai: Sạc Anker 40 cái ra 0%
SELECT sku, stock_quantity / 200 * 100 FROM products WHERE category_id = 12;
-- Đúng: ra 20%
SELECT sku, stock_quantity * 100.0 / 200 FROM products WHERE category_id = 12;
```

**2. Quên NULL lan truyền.** `price - cost_price`, `'Tên: ' || email` đều thành `NULL` khi một vế là `NULL`. Kiểm tra cột nào có thể `NULL` trước khi tính.

**3. Lạm dụng COALESCE(x, 0).** Giá nhập chưa biết không phải bằng 0; thay bừa sẽ ra lãi ảo. Hỏi "0 có đúng nghĩa không?" trước khi viết.

**4. Chia cho 0 làm sập cả truy vấn.** Bọc mẫu số bằng `NULLIF(mau_so, 0)`.

**5. Dùng hàm của MySQL trong PostgreSQL.** `YEAR(order_date)`, `DATE_ADD(...)`, `IFNULL(...)` không có trong PostgreSQL. Dùng `EXTRACT(YEAR FROM ...)`, `+ INTERVAL '...'`, `COALESCE(...)`.

**6. So sánh và sắp xếp bằng chuỗi ngày đã định dạng.** `TO_CHAR(order_date, 'DD/MM/YYYY')` là chuỗi; sắp theo nó sẽ sai thứ tự. Sắp và lọc trên cột ngày gốc, chỉ `TO_CHAR` khi hiển thị.

**7. Gọi hàm sai thứ tự khi làm sạch chuỗi.** `INITCAP` trước `REPLACE` biến `TP.HCM` thành `Tp.Hcm` rồi `REPLACE` không khớp. Chạy thử từng bước với `SELECT DISTINCT` như mục 7.

## Bài tập

### Cơ bản

**Bài 1.** Cửa hàng giảm giá 15% cho điện thoại (`category_id = 7`). Hiển thị `sku`, `name`, `price` và giá sau giảm làm tròn tới nghìn đồng (`gia_sale`), đắt trước.

<details>
<summary>Đáp án</summary>

```sql
SELECT sku,
       name,
       price,
       ROUND(price * 0.85, -3) AS gia_sale
FROM products
WHERE category_id = 7
ORDER BY price DESC;
```

Kết quả:

| sku | name | price | gia_sale |
| --- | --- | --- | --- |
| PHN-001 | iPhone 15 128GB | 19990000 | 16992000 |
| PHN-002 | Samsung Galaxy S24 | 18990000 | 16142000 |
| PHN-003 | Xiaomi Redmi Note 13 | 4890000 | 4157000 |
| PHN-004 | Nokia 105 4G | 690000 | 587000 |

</details>

**Bài 2.** In danh bạ dạng `Tên <email>` cho 5 khách đầu tiên (id 1 đến 5). Khách không có email thì hiện `<không có email>`.

<details>
<summary>Đáp án</summary>

```sql
SELECT full_name || ' <' || COALESCE(email, 'không có email') || '>' AS lien_he
FROM customers
WHERE customer_id <= 5
ORDER BY customer_id;
```

Kết quả:

| lien_he |
| --- |
| Nguyễn Văn An &lt;an.nguyen@gmail.com&gt; |
| Trần Thị Bình &lt;binh.tran@gmail.com&gt; |
| Lê Hoàng Cường &lt;cuong.le@outlook.com&gt; |
| Phạm Minh Duy &lt;duy.pham@gmail.com&gt; |
| Hoàng Thị Em &lt;không có email&gt; |

Thiếu `COALESCE` thì dòng của Hoàng Thị Em thành `NULL` vì `||` gặp `NULL`.

</details>

**Bài 3.** Liệt kê các đơn đặt vào cuối tuần (thứ Bảy, Chủ nhật) từ đầu năm 2026. Hiển thị ngày dạng `DD/MM/YYYY` và số thứ trong tuần.

<details>
<summary>Đáp án</summary>

```sql
SELECT order_id,
       TO_CHAR(order_date, 'DD/MM/YYYY') AS ngay,
       EXTRACT(ISODOW FROM order_date)   AS thu_trong_tuan
FROM orders
WHERE EXTRACT(ISODOW FROM order_date) IN (6, 7)
  AND order_date >= '2026-01-01'
ORDER BY order_date;
```

Kết quả:

| order_id | ngay | thu_trong_tuan |
| --- | --- | --- |
| 30 | 15/03/2026 | 7 |
| 36 | 08/08/2026 | 6 |
| 38 | 20/09/2026 | 7 |

`ISODOW` đánh số thứ Hai là 1, Chủ nhật là 7. (Còn `DOW` đánh số Chủ nhật là 0.) Sắp xếp theo `order_date` gốc, không theo chuỗi `ngay`.

</details>

### Vận dụng

**Bài 4.** Năm khách hàng trẻ nhất (đã khai ngày sinh) và tuổi của họ, tính tại ngày 17/10/2026.

<details>
<summary>Đáp án</summary>

```sql
SELECT full_name,
       birth_date,
       EXTRACT(YEAR FROM AGE(DATE '2026-10-17', birth_date)) AS tuoi
FROM customers
WHERE birth_date IS NOT NULL
ORDER BY tuoi
LIMIT 5;
```

Kết quả:

| full_name | birth_date | tuoi |
| --- | --- | --- |
| Dương Minh Khoa | 2005-02-14 | 21 |
| Võ Quốc Phong | 2004-05-12 | 22 |
| Huỳnh Tấn Phát | 2004-08-20 | 22 |
| Phạm Minh Duy | 2003-01-30 | 23 |
| Tạ Quang Sơn | 2002-12-12 | 23 |

Thiếu `WHERE birth_date IS NOT NULL` thì sao? `ORDER BY tuoi` tăng dần đặt `NULL` cuối nên kết quả vẫn đúng ở đây, nhưng viết rõ điều kiện giúp truy vấn không phụ thuộc vào chi tiết đó. Sắp theo `birth_date DESC` cũng được và tránh phải tính tuổi để sắp.

</details>

**Bài 5.** Tính biên lợi nhuận theo phần trăm của các laptop (danh mục 3, 4): `(price - cost_price) / cost_price * 100`, làm tròn 1 chữ số thập phân. Sắp biên cao nhất trước, sản phẩm chưa có giá nhập xuống cuối.

<details>
<summary>Đáp án</summary>

```sql
SELECT sku,
       name,
       price,
       cost_price,
       ROUND((price - cost_price) * 100.0 / cost_price, 1) AS bien_loi_nhuan_pct
FROM products
WHERE category_id IN (3, 4)
ORDER BY bien_loi_nhuan_pct DESC NULLS LAST;
```

Kết quả:

| sku | name | price | cost_price | bien_loi_nhuan_pct |
| --- | --- | --- | --- | --- |
| LAP-001 | ASUS ROG Strix G16 | 32990000 | 28500000 | 15.8 |
| LAP-003 | Acer Nitro V 15 | 21990000 | 19000000 | 15.7 |
| LAP-004 | Dell Inspiron 14 | 18490000 | 16000000 | 15.6 |
| LAP-002 | Lenovo Legion 5 | 29990000 | 26000000 | 15.3 |
| LAP-005 | MacBook Air M2 13 inch | 24990000 | 22000000 | 13.6 |
| LAP-006 | HP Pavilion 15 | 16990000 | NULL | NULL |

`price` và `cost_price` là `NUMERIC` nên không bị chia nguyên; viết `100.0` vẫn là thói quen tốt.

</details>

**Bài 6.** Cũng bảng trên nhưng hiển thị biên lợi nhuận thành chữ, ví dụ `15.8%`; sản phẩm chưa có giá nhập ghi `chưa có giá nhập`. Sắp theo `sku`.

<details>
<summary>Đáp án</summary>

`COALESCE` cần các đối số cùng kiểu, nên phải ép số sang `TEXT` trước khi nối `%`:

```sql
SELECT sku,
       COALESCE(ROUND((price - cost_price) * 100.0 / cost_price, 1)::TEXT || '%',
                'chưa có giá nhập') AS bien_loi_nhuan
FROM products
WHERE category_id IN (3, 4)
ORDER BY sku;
```

Kết quả:

| sku | bien_loi_nhuan |
| --- | --- |
| LAP-001 | 15.8% |
| LAP-002 | 15.3% |
| LAP-003 | 15.7% |
| LAP-004 | 15.6% |
| LAP-005 | 13.6% |
| LAP-006 | chưa có giá nhập |

Với `LAP-006`, cả biểu thức `ROUND(...)::TEXT || '%'` là `NULL` (vì `||` gặp `NULL`), nên `COALESCE` chuyển sang đối số thứ hai. Ở đây tính chất "NULL lan truyền" lại có ích.

</details>

**Bài 7.** Che số điện thoại khi hiển thị: giữ 4 số đầu và 3 số cuối, giữa là `***` (ví dụ `0901***567`). Khách không có số thì hiện `ẩn`. Làm cho khách id 1 đến 6.

<details>
<summary>Đáp án</summary>

```sql
SELECT full_name,
       COALESCE(LEFT(phone, 4) || '***' || RIGHT(phone, 3), 'ẩn') AS phone_che
FROM customers
WHERE customer_id <= 6
ORDER BY customer_id;
```

Kết quả:

| full_name | phone_che |
| --- | --- |
| Nguyễn Văn An | 0901***567 |
| Trần Thị Bình | 0912***678 |
| Lê Hoàng Cường | ẩn |
| Phạm Minh Duy | 0987***321 |
| Hoàng Thị Em | 0934***890 |
| Võ Quốc Phong | 0976***210 |

Viết bằng `SUBSTRING` cũng được: `SUBSTRING(phone FROM 1 FOR 4) || '***' || SUBSTRING(phone FROM LENGTH(phone) - 2)`.

</details>

### Thử thách

**Bài 8.** Tìm mọi khách ở Đà Nẵng, bất kể viết hoa hay thường, có khoảng trắng thừa hay không. Không được liệt kê từng cách viết.

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id,
       full_name,
       city
FROM customers
WHERE LOWER(TRIM(city)) = 'đà nẵng'
ORDER BY customer_id;
```

Kết quả:

| customer_id | full_name | city |
| --- | --- | --- |
| 3 | Lê Hoàng Cường | Đà Nẵng |
| 8 | Bùi Văn Hùng | đà nẵng |
| 18 | Mai Đức Uy | Đà Nẵng |

Đưa cả hai vế về cùng một dạng (`LOWER`) rồi mới so sánh. `city ILIKE 'đà nẵng'` cũng cho cùng kết quả nhưng không xử lý khoảng trắng thừa.

</details>

**Bài 9.** Với các đơn chưa giao xong (`pending`, `paid`, `shipped`), cửa hàng cam kết giao trong 3 ngày kể từ lúc đặt. Hiển thị hạn giao (dạng `DD/MM/YYYY`) và số ngày khách đã chờ tính đến ngày 17/10/2026, đơn cũ nhất trước.

<details>
<summary>Đáp án</summary>

```sql
SELECT order_id,
       order_date,
       TO_CHAR(order_date + INTERVAL '3 days', 'DD/MM/YYYY') AS han_giao,
       DATE '2026-10-17' - order_date::date AS so_ngay_cho
FROM orders
WHERE status IN ('pending', 'paid', 'shipped')
ORDER BY order_date;
```

Kết quả:

| order_id | order_date | han_giao | so_ngay_cho |
| --- | --- | --- | --- |
| 37 | 2026-09-02 10:00:00+07 | 05/09/2026 | 45 |
| 38 | 2026-09-20 16:30:00+07 | 23/09/2026 | 27 |
| 39 | 2026-10-05 09:00:00+07 | 08/10/2026 | 12 |
| 40 | 2026-10-14 22:00:00+07 | 17/10/2026 | 3 |

`order_date::date` bỏ phần giờ để phép trừ hai `DATE` ra số ngày nguyên. Trong ứng dụng thật, thay `DATE '2026-10-17'` bằng `CURRENT_DATE`.

</details>

## Tóm tắt

- `/` giữa hai số nguyên là chia nguyên (`7 / 2 = 3`); cần thập phân thì cho một vế là `NUMERIC` (`7 / 2.0`, `7::numeric / 2`). `%` lấy phần dư, dùng được với `NUMERIC`.
- Nhân chia trước cộng trừ, phép toán trước so sánh, so sánh trước `NOT`/`AND`/`OR`. Có nghi ngờ thì đặt ngoặc.
- Phép toán và hàm gặp `NULL` thường trả `NULL`; `CONCAT` là ngoại lệ (bỏ qua `NULL`).
- Hàm chuỗi: `||`, `CONCAT`, `UPPER`, `LOWER`, `INITCAP`, `TRIM`, `LENGTH`, `SUBSTRING`, `LEFT`/`RIGHT`, `POSITION`, `REPLACE`.
- Hàm ngày giờ: `CURRENT_DATE`, `now()`, `EXTRACT`, `DATE_TRUNC`, `TO_CHAR`, `AGE`; cộng trừ bằng `INTERVAL`; `DATE - DATE` ra số ngày.
- Lọc theo khoảng thời gian bằng `>= đầu AND < cuối`, không bọc cột trong `EXTRACT`.
- `CAST(x AS kieu)` hoặc `x::kieu` để đổi kiểu; `ROUND(x, n)` làm tròn, `n = -3` là tròn nghìn.
- `COALESCE` lấy giá trị khác `NULL` đầu tiên, nhưng đừng biến "chưa biết" thành 0 khi 0 sai nghĩa. `NULLIF(x, 0)` chặn lỗi chia cho 0.
- Làm sạch chuỗi: thử từng bước bằng `SELECT DISTINCT`, chú ý thứ tự gọi hàm.

## Đọc thêm

- [Vì sao NOT IN của bạn trả về 0 dòng? Logic ba trị của SQL và cái bẫy NULL](https://tiennhm.io.vn/blog/sql-null-not-in-three-valued-logic) — Một câu NOT IN trả về đúng 0 dòng trong khi bảng có dữ liệu, còn NOT EXISTS cùng ý định lại trả về đủ.
- [Collation là gì? Character Sets, Collations và so sánh chuỗi trong MySQL](https://tiennhm.io.vn/blog/character-sets-and-collations-in-mysql) — Collation quyết định MySQL so sánh và sắp xếp chuỗi thế nào — vì sao WHERE name = 'Alice' lại khớp cả 'alice', hậu tố _ci _cs _bin nghĩa là gì, vì…
- Tài liệu PostgreSQL: [Mathematical Functions and Operators](https://www.postgresql.org/docs/16/functions-math.html), [String Functions](https://www.postgresql.org/docs/16/functions-string.html), [Date/Time Functions](https://www.postgresql.org/docs/16/functions-datetime.html), [Conditional Expressions (COALESCE, NULLIF)](https://www.postgresql.org/docs/16/functions-conditional.html).

---

[⬅️ Ngày 4: ORDER BY và LIMIT, sắp xếp và phân trang](04-order-by-limit.md) | [📚 Mục lục](../README.md) | [Ngày 6: Thêm, sửa, xóa dữ liệu (INSERT, UPDATE, DELETE) ➡️](06-insert-update-delete.md)
