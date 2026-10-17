# Ngày 9: Nhóm dữ liệu với GROUP BY và HAVING

> **Tóm tắt:** Ngày 8 bạn đã tính một con số cho cả bảng (tổng số đơn, tổng tiền). Hôm nay bạn chia các dòng thành từng nhóm bằng `GROUP BY` để có một con số cho mỗi nhóm (số đơn của mỗi khách, số đơn mỗi tháng), rồi lọc các nhóm bằng `HAVING`. Cuối bài là thứ tự thực thi logic đầy đủ của câu `SELECT`, chìa khóa để hiểu vì sao WHERE và HAVING khác nhau.

**Sau bài này bạn có thể:**

- Viết truy vấn `GROUP BY` theo một cột, nhiều cột hoặc một biểu thức (năm, tháng) để làm báo cáo tổng hợp.
- Giải thích được quy tắc "cột trong SELECT phải nằm trong GROUP BY hoặc nằm trong hàm tổng hợp" và sửa được lỗi tương ứng.
- Chọn đúng giữa `WHERE` (lọc dòng trước khi nhóm) và `HAVING` (lọc nhóm sau khi nhóm).
- Sắp xếp được các mệnh đề `FROM`, `WHERE`, `GROUP BY`, `HAVING`, `SELECT`, `DISTINCT`, `ORDER BY`, `LIMIT` theo thứ tự database xử lý.

**Cần biết trước:** [Ngày 3](03-select-where.md) (SELECT, WHERE, NULL), [Ngày 4](04-order-by-limit.md) (ORDER BY, LIMIT), [Ngày 5](05-operators-expressions.md) (EXTRACT, DATE_TRUNC, ROUND), [Ngày 8](08-aggregate-functions.md) (COUNT, SUM, AVG, MIN, MAX).

Mọi ví dụ chạy trên bộ dữ liệu DSC Shop. Nếu chưa dựng môi trường, xem [setup/README.md](../setup/README.md).

## 1. Từ một con số đến một con số cho mỗi nhóm

Ở Ngày 8, hàm tổng hợp gom cả bảng thành một dòng:

```sql
SELECT COUNT(*) AS so_don
FROM orders;
```

| so_don |
| --- |
| 40 |

Nhưng người quản lý cửa hàng thường hỏi chi tiết hơn: "trong 40 đơn đó, bao nhiêu đơn đã giao, bao nhiêu đơn bị hủy?". Bạn cần một con số cho mỗi trạng thái. Đó là việc của `GROUP BY`.

Hình dung thế này: database đọc từng đơn hàng và bỏ vào các "xô" theo giá trị cột `status`. Đơn `delivered` vào xô `delivered`, đơn `cancelled` vào xô `cancelled`. Sau đó hàm tổng hợp chạy riêng trên từng xô, và mỗi xô cho ra đúng một dòng kết quả.

```sql
SELECT status, COUNT(*) AS so_don
FROM orders
GROUP BY status
ORDER BY so_don DESC;
```

| status | so_don |
| --- | --- |
| delivered | 33 |
| cancelled | 3 |
| paid | 2 |
| pending | 1 |
| shipped | 1 |

Cú pháp chung:

```text
SELECT cot_nhom, HAM_TONG_HOP(cot_khac)
FROM ten_bang
GROUP BY cot_nhom;
```

Một ví dụ khác: đếm số đơn của mỗi khách hàng.

```sql
SELECT customer_id, COUNT(*) AS so_don
FROM orders
GROUP BY customer_id
ORDER BY so_don DESC, customer_id;
```

| customer_id | so_don |
| --- | --- |
| 1 | 5 |
| 2 | 4 |
| 3 | 3 |
| 4 | 3 |
| 6 | 3 |
| 5 | 2 |
| 7 | 2 |
| ... | ... |

(... tổng 16 dòng)

Có 18 khách nhưng chỉ 16 nhóm: khách 16 và 17 chưa có đơn nào, nên trong bảng `orders` không có dòng nào để tạo nhóm cho họ. Muốn hiện cả khách chưa mua với số đơn bằng 0, bạn cần ghép bảng `customers` với `orders`, sẽ học ở [Ngày 10](10-join.md).

## 2. Quy tắc vàng: cột trong SELECT phải "đại diện" được cho cả nhóm

Sau khi nhóm, mỗi nhóm chỉ còn một dòng. Vậy mỗi cột trong `SELECT` phải cho ra đúng một giá trị cho nhóm đó. Chỉ có hai loại cột làm được việc này:

1. Cột có trong `GROUP BY` (cả nhóm có chung một giá trị).
2. Hàm tổng hợp (`COUNT`, `SUM`, ...) gom nhiều giá trị thành một.

Thử chọn thêm `order_date` khi nhóm theo `customer_id`:

```sql
SELECT customer_id, order_date, COUNT(*)
FROM orders
GROUP BY customer_id;
```

PostgreSQL báo lỗi:

```text
ERROR:  column "orders.order_date" must appear in the GROUP BY clause or be used in an aggregate function
```

Lý do: khách 1 có 5 đơn với 5 ngày khác nhau. Database không biết bạn muốn ngày nào. Nếu bạn muốn ngày đơn đầu tiên và đơn gần nhất, hãy nói rõ bằng hàm tổng hợp:

```sql
SELECT customer_id,
       COUNT(*)               AS so_don,
       MIN(order_date)::date  AS don_dau_tien,
       MAX(order_date)::date  AS don_gan_nhat
FROM orders
GROUP BY customer_id
ORDER BY customer_id
LIMIT 3;
```

| customer_id | so_don | don_dau_tien | don_gan_nhat |
| --- | --- | --- | --- |
| 1 | 5 | 2025-01-12 | 2026-09-02 |
| 2 | 4 | 2025-01-20 | 2026-06-15 |
| 3 | 3 | 2025-02-03 | 2026-10-14 |

> **Ghi chú dialect:** MySQL khi tắt chế độ `ONLY_FULL_GROUP_BY` (mặc định đang bật từ MySQL 5.7) và SQLite không báo lỗi câu trên mà trả về một `order_date` bất kỳ trong nhóm. Kết quả đó không đáng tin, đừng dựa vào nó. PostgreSQL và SQL Server luôn báo lỗi.

## 3. GROUP BY nhiều cột

Liệt kê nhiều cột trong `GROUP BY` thì mỗi tổ hợp giá trị khác nhau là một nhóm. Ví dụ: số đơn theo kênh bán và trạng thái.

```sql
SELECT channel, status, COUNT(*) AS so_don
FROM orders
GROUP BY channel, status
ORDER BY channel, status;
```

| channel | status | so_don |
| --- | --- | --- |
| offline | delivered | 15 |
| online | cancelled | 3 |
| online | delivered | 18 |
| online | paid | 2 |
| online | pending | 1 |
| online | shipped | 1 |

Chỉ những tổ hợp thật sự xuất hiện trong dữ liệu mới thành nhóm. Không có đơn `offline` nào bị hủy nên không có dòng `offline | cancelled`.

## 4. GROUP BY theo biểu thức

Bạn không bắt buộc nhóm theo một cột có sẵn. Nhóm theo một biểu thức cũng được, rất hay dùng với ngày tháng (đã học `EXTRACT`, `DATE_TRUNC` ở Ngày 5).

Số đơn mỗi năm:

```sql
SELECT EXTRACT(YEAR FROM order_date) AS nam,
       COUNT(*) AS so_don
FROM orders
GROUP BY EXTRACT(YEAR FROM order_date)
ORDER BY nam;
```

| nam | so_don |
| --- | --- |
| 2025 | 25 |
| 2026 | 15 |

Tổng tiền của từng đơn hàng: bảng `orders` không có cột tổng tiền, tổng tiền luôn tính từ `order_items` bằng `quantity * unit_price * (1 - discount)`. Nhóm theo `order_id` là ra tổng tiền mỗi đơn.

```sql
SELECT order_id,
       COUNT(*) AS so_dong_hang,
       ROUND(SUM(quantity * unit_price * (1 - discount))) AS tong_tien
FROM order_items
GROUP BY order_id
ORDER BY order_id
LIMIT 5;
```

| order_id | so_dong_hang | tong_tien |
| --- | --- | --- |
| 1 | 2 | 699000 |
| 2 | 1 | 26990000 |
| 3 | 2 | 5780000 |
| 4 | 2 | 7881000 |
| 5 | 1 | 32990000 |

`ROUND` ở đây để bỏ phần `.00` sinh ra do `discount` có 2 chữ số thập phân.

## 5. NULL tạo thành một nhóm riêng

Ở Ngày 3 bạn biết `NULL = NULL` không cho ra TRUE. Riêng với `GROUP BY`, mọi giá trị NULL được gom chung vào một nhóm. Xem số khách theo thành phố:

```sql
SELECT city,
       COUNT(*)     AS so_khach,
       COUNT(phone) AS co_sdt
FROM customers
GROUP BY city
ORDER BY so_khach DESC, city;
```

| city | so_khach | co_sdt |
| --- | --- | --- |
| Hà Nội | 4 | 2 |
| TP. Hồ Chí Minh | 3 | 3 |
| Cần Thơ | 2 | 2 |
| Đà Nẵng | 2 | 1 |
| NULL | 2 | 1 |
| Biên Hòa | 1 | 1 |
| đà nẵng | 1 | 1 |
| Hải Phòng | 1 | 1 |
| Hồ Chí Minh | 1 | 1 |
| TP.HCM | 1 | 1 |

Hai điều rút ra:

- Hai khách không có `city` nằm chung nhóm `NULL`.
- `GROUP BY` so sánh chính xác từng ký tự. `TP. Hồ Chí Minh`, `Hồ Chí Minh`, `TP.HCM` là ba nhóm khác nhau, `Đà Nẵng` và `đà nẵng` cũng vậy. Dữ liệu bẩn làm báo cáo sai, nên nhóm theo biểu thức đã làm sạch (bạn đã luyện ở Ngày 5) trước khi tin vào con số.

Cột `co_sdt` nhắc lại bài Ngày 8: `COUNT(*)` đếm mọi dòng của nhóm, còn `COUNT(phone)` bỏ qua dòng có `phone` là NULL.

## 6. HAVING: lọc nhóm sau khi nhóm

Câu hỏi: "khách nào đã đặt từ 3 đơn trở lên?". Điều kiện `COUNT(*) >= 3` nói về cả nhóm, không nói về một dòng đơn lẻ. Thử viết vào `WHERE`:

```sql
SELECT customer_id, COUNT(*) AS so_don
FROM orders
WHERE COUNT(*) >= 3
GROUP BY customer_id;
```

```text
ERROR:  aggregate functions are not allowed in WHERE
```

Điều kiện trên nhóm phải đặt trong `HAVING`, viết sau `GROUP BY`:

```sql
SELECT customer_id, COUNT(*) AS so_don
FROM orders
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY so_don DESC, customer_id;
```

| customer_id | so_don |
| --- | --- |
| 1 | 5 |
| 2 | 4 |
| 3 | 3 |
| 4 | 3 |
| 6 | 3 |

`HAVING` cũng dùng được với các hàm tổng hợp khác. Các đơn có tổng tiền trên 30 triệu:

```sql
SELECT order_id,
       ROUND(SUM(quantity * unit_price * (1 - discount))) AS tong_tien
FROM order_items
GROUP BY order_id
HAVING SUM(quantity * unit_price * (1 - discount)) > 30000000
ORDER BY tong_tien DESC;
```

| order_id | tong_tien |
| --- | --- |
| 39 | 39980000 |
| 5 | 32990000 |
| 12 | 31880000 |
| 27 | 31340500 |

## 7. WHERE và HAVING dùng cùng nhau

`WHERE` và `HAVING` không loại trừ nhau. Một câu truy vấn thường có cả hai: `WHERE` bỏ các dòng không cần trước khi nhóm, `HAVING` bỏ các nhóm không đạt sau khi nhóm.

Câu hỏi: "khách nào có từ 3 đơn trở lên, không tính đơn đã hủy?"

```sql
SELECT customer_id, COUNT(*) AS so_don
FROM orders
WHERE status <> 'cancelled'
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY so_don DESC, customer_id;
```

| customer_id | so_don |
| --- | --- |
| 1 | 5 |
| 2 | 4 |
| 3 | 3 |
| 6 | 3 |

Khách 4 biến mất: khách này có 3 đơn nhưng đơn 5 bị hủy. `WHERE` bỏ đơn 5 trước khi đếm (40 đơn còn 37), nên nhóm của khách 4 chỉ còn 2 đơn và bị `HAVING` loại.

| | `WHERE` | `HAVING` |
| --- | --- | --- |
| Lọc cái gì | Từng dòng | Từng nhóm |
| Chạy lúc nào | Trước khi nhóm | Sau khi nhóm |
| Dùng được hàm tổng hợp (`COUNT`, `SUM`, ...) | Không | Có |
| Dùng chung với `GROUP BY` | Có | Có |
| Không có `GROUP BY` thì sao | Lọc dòng như bình thường | Cả bảng được coi là một nhóm |

Quy tắc thực hành: điều kiện trên cột thường (`status`, `order_date`, `channel`) đặt ở `WHERE`. Chỉ điều kiện trên hàm tổng hợp mới đặt ở `HAVING`. Viết `HAVING status <> 'cancelled'` sẽ lỗi nếu `status` không nằm trong `GROUP BY`; và kể cả khi chạy được, lọc sớm bằng `WHERE` giúp database phải nhóm ít dòng hơn.

## 8. Thứ tự thực thi logic đầy đủ

Ở Ngày 3 bạn đã biết database xử lý `FROM` → `WHERE` → `SELECT`. Giờ có thêm nhóm, thứ tự đầy đủ là:

| Bước | Mệnh đề | Làm gì |
| --- | --- | --- |
| 1 | `FROM` (và `JOIN`, Ngày 10) | Lấy bảng nguồn |
| 2 | `WHERE` | Lọc từng dòng |
| 3 | `GROUP BY` | Gom dòng thành nhóm |
| 4 | `HAVING` | Lọc từng nhóm |
| 5 | `SELECT` | Tính các cột, đặt tên (alias) |
| 6 | `DISTINCT` | Bỏ dòng trùng |
| 7 | `ORDER BY` | Sắp xếp |
| 8 | `LIMIT` / `OFFSET` | Cắt lấy một phần |

Đây là thứ tự logic, tức là kết quả luôn giống như khi chạy theo thứ tự này. Bên trong, database có thể làm khác đi để chạy nhanh hơn (bạn sẽ thấy ở Ngày 20).

Sơ đồ dưới đây đi theo truy vấn ở mục 7:

![Thứ tự thực thi logic của câu SELECT có GROUP BY, minh họa bằng truy vấn đếm đơn mỗi khách trên bảng orders. Câu lệnh viết theo thứ tự SELECT, FROM, WHERE, GROUP BY, HAVING, ORDER BY, nhưng database xử lý: 1 FROM lấy bảng orders, 40 dòng; 2 WHERE status khác 'cancelled' lọc từng dòng, còn 37 dòng; hai bước này chạy trước khi nhóm. Sau đó 3 GROUP BY customer_id gom thành 16 nhóm; 4 HAVING COUNT(*) >= 3 lọc từng nhóm, còn 4 nhóm; 5 SELECT tính COUNT(*) và đặt tên so_don; 6 ORDER BY so_don DESC sắp xếp. WHERE chạy khi chưa có nhóm nên không lọc được SUM(), COUNT(); HAVING chạy sau GROUP BY nên lọc được theo hàm tổng hợp.](img/thu-tu-thuc-thi.png#gh-light-mode-only)
![Thứ tự thực thi logic của câu SELECT có GROUP BY, minh họa bằng truy vấn đếm đơn mỗi khách trên bảng orders. Câu lệnh viết theo thứ tự SELECT, FROM, WHERE, GROUP BY, HAVING, ORDER BY, nhưng database xử lý: 1 FROM lấy bảng orders, 40 dòng; 2 WHERE status khác 'cancelled' lọc từng dòng, còn 37 dòng; hai bước này chạy trước khi nhóm. Sau đó 3 GROUP BY customer_id gom thành 16 nhóm; 4 HAVING COUNT(*) >= 3 lọc từng nhóm, còn 4 nhóm; 5 SELECT tính COUNT(*) và đặt tên so_don; 6 ORDER BY so_don DESC sắp xếp. WHERE chạy khi chưa có nhóm nên không lọc được SUM(), COUNT(); HAVING chạy sau GROUP BY nên lọc được theo hàm tổng hợp.](img/thu-tu-thuc-thi-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/group-by-having/thu-tu-thuc-thi.html) · [nền tối](../diagrams/group-by-having/thu-tu-thuc-thi-dark.html)</small>

Thứ tự này giải thích luôn chuyện dùng alias (tên đặt bằng `AS`) ở đâu được:

- `ORDER BY so_don` chạy được, vì `ORDER BY` (bước 7) chạy sau `SELECT` (bước 5), lúc đó tên `so_don` đã có.
- `HAVING so_don >= 3` thì lỗi, vì `HAVING` (bước 4) chạy trước khi `SELECT` đặt tên:

```sql
SELECT customer_id, COUNT(*) AS so_don
FROM orders
GROUP BY customer_id
HAVING so_don >= 3;
```

```text
ERROR:  column "so_don" does not exist
```

Cách đúng là lặp lại biểu thức: `HAVING COUNT(*) >= 3`.

> **Ghi chú dialect:** PostgreSQL và MySQL cho phép viết alias trong `GROUP BY` (ví dụ `GROUP BY nam` thay cho `GROUP BY EXTRACT(YEAR FROM order_date)`), đây là phần mở rộng ngoài chuẩn SQL. SQL Server không cho, bạn phải lặp lại biểu thức. Lặp lại biểu thức là cách chạy được ở mọi nơi. MySQL còn cho dùng alias trong `HAVING`, PostgreSQL và SQL Server thì không.

## 9. Nhắc qua: dòng tổng cộng với ROLLUP

Báo cáo thường cần thêm một dòng "tổng cộng" ở cuối. `GROUP BY ROLLUP (...)` làm việc đó:

```sql
SELECT channel, COUNT(*) AS so_don
FROM orders
GROUP BY ROLLUP (channel)
ORDER BY channel;
```

| channel | so_don |
| --- | --- |
| offline | 15 |
| online | 25 |
| NULL | 40 |

Dòng có `channel` là NULL chính là dòng tổng của mọi nhóm. Bạn chỉ cần biết `ROLLUP` tồn tại; các báo cáo nhiều cấp (`ROLLUP`, `CUBE`, `GROUPING SETS`) nằm ngoài phạm vi khóa này.

## Lỗi thường gặp

**1. Chọn cột không nằm trong GROUP BY.** Đã gặp ở mục 2. Hỏi lại bản thân: "mỗi nhóm có đúng một giá trị cho cột này không?". Nếu không, đưa cột đó vào `GROUP BY` hoặc bọc trong hàm tổng hợp.

**2. Dùng hàm tổng hợp trong WHERE.** `WHERE COUNT(*) >= 3` lỗi `aggregate functions are not allowed in WHERE`. Chuyển điều kiện sang `HAVING`.

**3. Nhóm theo tên thay vì theo khóa.** DSC Shop có hai khách khác nhau cùng tên `Nguyễn Văn An` (id 1 và 15):

```sql
SELECT full_name, COUNT(*) AS so_khach
FROM customers
GROUP BY full_name
HAVING COUNT(*) > 1;
```

| full_name | so_khach |
| --- | --- |
| Nguyễn Văn An | 2 |

Nếu bạn nhóm đơn hàng theo tên khách, đơn của hai người này bị gộp làm một. Luôn nhóm theo khóa chính (`customer_id`), tên chỉ để hiển thị.

**4. Tưởng GROUP BY tự sắp xếp.** Có lúc kết quả nhìn như đã sắp xếp, nhưng đó là tình cờ. Chạy câu này nhiều lần hoặc trên máy khác, thứ tự có thể khác:

```sql
SELECT status, COUNT(*) AS so_don
FROM orders
GROUP BY status;
```

| status | so_don |
| --- | --- |
| delivered | 33 |
| cancelled | 3 |
| pending | 1 |
| paid | 2 |
| shipped | 1 |

Muốn có thứ tự, luôn viết `ORDER BY`.

**5. Dùng alias trong HAVING.** Đã gặp ở mục 8: `HAVING so_don >= 3` lỗi trong PostgreSQL. Viết lại biểu thức `HAVING COUNT(*) >= 3`.

**6. Đặt điều kiện trên cột thường vào HAVING.** Lọc `status`, `order_date` ở `WHERE` để database nhóm ít dòng hơn và câu lệnh dễ đọc hơn. `HAVING` chỉ dành cho điều kiện trên nhóm.

## Bài tập

### Cơ bản

**Bài 1.** Đếm số sản phẩm trong mỗi danh mục (`category_id`), kèm giá thấp nhất và cao nhất của danh mục đó. Sắp xếp theo `category_id`.

<details>
<summary>Đáp án</summary>

```sql
SELECT category_id,
       COUNT(*)   AS so_san_pham,
       MIN(price) AS gia_thap_nhat,
       MAX(price) AS gia_cao_nhat
FROM products
GROUP BY category_id
ORDER BY category_id;
```

Kết quả:

| category_id | so_san_pham | gia_thap_nhat | gia_cao_nhat |
| --- | --- | --- | --- |
| 3 | 3 | 21990000 | 32990000 |
| 4 | 3 | 16990000 | 24990000 |
| 5 | 3 | 4290000 | 9990000 |
| 7 | 4 | 690000 | 19990000 |
| 8 | 2 | 9490000 | 16990000 |
| 10 | 4 | 250000 | 2490000 |
| 11 | 3 | 2690000 | 7990000 |
| 12 | 2 | 150000 | 890000 |

Danh mục 1, 2, 6, 9 là danh mục cha, 13 chưa có sản phẩm, nên không xuất hiện.
</details>

**Bài 2.** Đếm số đơn theo từng năm và từng kênh bán (`channel`).

<details>
<summary>Đáp án</summary>

```sql
SELECT EXTRACT(YEAR FROM order_date) AS nam,
       channel,
       COUNT(*) AS so_don
FROM orders
GROUP BY EXTRACT(YEAR FROM order_date), channel
ORDER BY nam, channel;
```

Kết quả:

| nam | channel | so_don |
| --- | --- | --- |
| 2025 | offline | 10 |
| 2025 | online | 15 |
| 2026 | offline | 5 |
| 2026 | online | 10 |
</details>

**Bài 3.** Với mỗi phương thức thanh toán (`payments.method`), cho biết số lần thanh toán và tổng tiền. Sắp xếp theo tổng tiền giảm dần.

<details>
<summary>Đáp án</summary>

```sql
SELECT method,
       COUNT(*)    AS so_lan,
       SUM(amount) AS tong_tien
FROM payments
GROUP BY method
ORDER BY tong_tien DESC;
```

Kết quả:

| method | so_lan | tong_tien |
| --- | --- | --- |
| bank_transfer | 8 | 166691500 |
| momo | 14 | 157951000 |
| card | 7 | 112317500 |
| cash | 8 | 99331000 |
</details>

### Vận dụng

**Bài 4.** Tìm 5 sản phẩm (`product_id`) có giá trị đặt hàng cao nhất trong `order_items` (tổng `quantity * unit_price * (1 - discount)`), kèm tổng số lượng đã đặt. Làm tròn đến đồng.

Lưu ý: đây chưa phải doanh thu. Trong khóa này, doanh thu chỉ tính các đơn có `status NOT IN ('pending', 'cancelled')` (đơn đã thanh toán, khớp với bảng `payments`). Muốn lọc theo `status` phải ghép `order_items` với `orders`, việc của Ngày 10. Bài này tính mọi đơn, kể cả đơn chờ xử lý và đơn hủy.

<details>
<summary>Đáp án</summary>

```sql
SELECT product_id,
       SUM(quantity) AS so_luong,
       ROUND(SUM(quantity * unit_price * (1 - discount))) AS gia_tri_dat
FROM order_items
GROUP BY product_id
ORDER BY gia_tri_dat DESC
LIMIT 5;
```

Kết quả:

| product_id | so_luong | gia_tri_dat |
| --- | --- | --- |
| 10 | 4 | 78960500 |
| 1 | 2 | 64330500 |
| 2 | 2 | 59980000 |
| 5 | 2 | 50730500 |
| 3 | 2 | 43830500 |
</details>

**Bài 5.** Chỉ giữ các phương thức thanh toán có tổng tiền trên 100 triệu.

<details>
<summary>Đáp án</summary>

```sql
SELECT method,
       COUNT(*)    AS so_lan,
       SUM(amount) AS tong_tien
FROM payments
GROUP BY method
HAVING SUM(amount) > 100000000
ORDER BY tong_tien DESC;
```

Kết quả:

| method | so_lan | tong_tien |
| --- | --- | --- |
| bank_transfer | 8 | 166691500 |
| momo | 14 | 157951000 |
| card | 7 | 112317500 |

`cash` có tổng 99.331.000 nên bị loại.
</details>

**Bài 6.** Với các đơn `offline`, mỗi nhân viên (`employee_id`) bán được bao nhiêu đơn? Sắp xếp giảm dần theo số đơn.

<details>
<summary>Đáp án</summary>

```sql
SELECT employee_id, COUNT(*) AS so_don
FROM orders
WHERE channel = 'offline'
GROUP BY employee_id
ORDER BY so_don DESC, employee_id;
```

Kết quả:

| employee_id | so_don |
| --- | --- |
| 4 | 5 |
| 5 | 5 |
| 6 | 4 |
| 8 | 1 |

`channel = 'offline'` là điều kiện trên từng dòng nên đặt ở `WHERE`.
</details>

### Thử thách

**Bài 7.** Trong năm 2025, tháng nào có từ 3 đơn trở lên (không tính đơn đã hủy)? Hiển thị tháng dạng ngày đầu tháng (ví dụ `2025-09-01`).

<details>
<summary>Đáp án</summary>

```sql
SELECT DATE_TRUNC('month', order_date)::date AS thang,
       COUNT(*) AS so_don
FROM orders
WHERE status <> 'cancelled'
  AND order_date >= '2025-01-01'
  AND order_date <  '2026-01-01'
GROUP BY DATE_TRUNC('month', order_date)
HAVING COUNT(*) >= 3
ORDER BY thang;
```

Kết quả:

| thang | so_don |
| --- | --- |
| 2025-09-01 | 3 |
| 2025-11-01 | 3 |

Lọc năm bằng khoảng `>= '2025-01-01' AND < '2026-01-01'` thay vì `EXTRACT(YEAR ...) = 2025`: kết quả như nhau, nhưng cách so sánh trực tiếp trên cột cho phép database dùng index (Ngày 15, 28).
</details>

**Bài 8.** Tìm các sản phẩm xuất hiện trong ít nhất 3 đơn hàng khác nhau. Hiển thị `product_id`, số đơn và tổng số lượng đã bán, sắp xếp theo số đơn giảm dần.

<details>
<summary>Đáp án</summary>

```sql
SELECT product_id,
       COUNT(DISTINCT order_id) AS so_don,
       SUM(quantity)            AS so_luong
FROM order_items
GROUP BY product_id
HAVING COUNT(DISTINCT order_id) >= 3
ORDER BY so_don DESC, product_id;
```

Kết quả:

| product_id | so_don | so_luong |
| --- | --- | --- |
| 23 | 6 | 13 |
| 16 | 5 | 6 |
| 12 | 4 | 5 |
| 17 | 4 | 4 |
| 22 | 4 | 6 |
| 10 | 3 | 4 |
| 18 | 3 | 3 |
| 19 | 3 | 3 |
| 20 | 3 | 3 |

Khóa chính của `order_items` là `(order_id, product_id)`, nên trong một nhóm `product_id` mỗi `order_id` chỉ xuất hiện một lần, `COUNT(*)` cũng cho cùng kết quả. Viết `COUNT(DISTINCT order_id)` thì ý nghĩa "số đơn khác nhau" rõ ràng hơn và vẫn đúng nếu sau này schema thay đổi.
</details>

**Bài 9.** "Có bao nhiêu khách đã đặt từ 3 đơn trở lên?" Câu trả lời là một con số. Thử nghĩ xem vì sao chỉ dùng `GROUP BY` và `HAVING` thì không ra được một con số.

<details>
<summary>Đáp án</summary>

`GROUP BY customer_id HAVING COUNT(*) >= 3` cho ra 5 dòng (mỗi khách một dòng, xem mục 6). Muốn đếm số dòng đó, bạn phải tổng hợp thêm một lần nữa trên kết quả của truy vấn trước. Việc này cần truy vấn con trong `FROM`, học ở [Ngày 11](11-subquery.md):

```sql
SELECT COUNT(*) AS so_khach
FROM (
    SELECT customer_id
    FROM orders
    GROUP BY customer_id
    HAVING COUNT(*) >= 3
) AS khach_than_thiet;
```

Kết quả:

| so_khach |
| --- |
| 5 |
</details>

## Tóm tắt

- `GROUP BY` chia các dòng thành nhóm theo giá trị của một hoặc nhiều cột (hoặc biểu thức); hàm tổng hợp chạy riêng trên từng nhóm, mỗi nhóm ra một dòng.
- Cột trong `SELECT` phải nằm trong `GROUP BY` hoặc nằm trong hàm tổng hợp.
- NULL gom chung thành một nhóm; giá trị viết khác nhau (`Đà Nẵng`, `đà nẵng`) là các nhóm khác nhau.
- `WHERE` lọc dòng trước khi nhóm, `HAVING` lọc nhóm sau khi nhóm. Hai mệnh đề thường đi cùng nhau.
- Thứ tự logic: `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `DISTINCT` → `ORDER BY` → `LIMIT`. Vì vậy alias dùng được trong `ORDER BY` nhưng không dùng được trong `WHERE`, `HAVING`.
- `GROUP BY` không đảm bảo thứ tự; cần thứ tự thì viết `ORDER BY`.
- Nhóm theo khóa chính, không nhóm theo tên.

## Đọc thêm

- [PostgreSQL: GROUP BY và HAVING](https://www.postgresql.org/docs/16/queries-table-expressions.html#QUERIES-GROUP)
- [PostgreSQL: GROUPING SETS, CUBE, ROLLUP](https://www.postgresql.org/docs/16/queries-table-expressions.html#QUERIES-GROUPING-SETS)
- [Luỹ kế của bạn sai ngay dòng đầu: window function, RANGE và cái mặc định ít ai đọc](https://tiennhm.io.vn/blog/window-function-vs-group-by) — GROUP BY gom 200.000 dòng thành 200, window function giữ nguyên cả 200.000 mà vẫn có số tổng của nhóm (window function học ở Ngày 29).

---

[⬅️ Ngày 8: Hàm tổng hợp (COUNT, SUM, AVG, MIN, MAX)](08-aggregate-functions.md) | [📚 Mục lục](../README.md) | [Ngày 10: Kết hợp nhiều bảng với JOIN ➡️](10-join.md)
