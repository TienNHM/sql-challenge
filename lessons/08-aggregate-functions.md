# Ngày 8: Hàm tổng hợp (COUNT, SUM, AVG, MIN, MAX)

> **Tóm tắt:** Đến giờ mỗi dòng kết quả ứng với một dòng trong bảng. Hàm tổng hợp (aggregate function) làm ngược lại: gom nhiều dòng thành một con số, như "có bao nhiêu khách", "tổng tiền đơn 4 là bao nhiêu". Bài này dạy năm hàm cơ bản, sự khác nhau giữa `COUNT(*)`, `COUNT(cot)` và `COUNT(DISTINCT cot)`, cách hàm tổng hợp đối xử với NULL, và cách tính tổng tiền một đơn hàng từ `order_items`.

**Sau bài này bạn có thể:**

- Viết được truy vấn dùng `COUNT`, `SUM`, `AVG`, `MIN`, `MAX` kết hợp `WHERE` để trả lời câu hỏi thống kê trên DSC Shop.
- Chọn đúng giữa `COUNT(*)`, `COUNT(cot)` và `COUNT(DISTINCT cot)`, và giải thích vì sao ba con số khác nhau.
- Dự đoán được kết quả hàm tổng hợp khi cột có NULL, và dùng `COALESCE` khi cần coi NULL là 0.
- Tính được tổng tiền một đơn hàng từ `order_items` theo công thức `quantity * unit_price * (1 - discount)`.

**Cần biết trước:** [Ngày 3](03-select-where.md) (WHERE, DISTINCT, NULL), [Ngày 4](04-order-by-limit.md) (ORDER BY, LIMIT), [Ngày 5](05-operators-expressions.md) (ROUND, COALESCE).

## 1. Hàm tổng hợp là gì

Hàm tổng hợp nhận một tập dòng và trả về một giá trị. Bạn đã quen với hàm như `UPPER(full_name)`: chạy trên từng dòng, 18 khách vào thì 18 kết quả ra. Hàm tổng hợp thì 18 khách vào, 1 kết quả ra.

| Hàm | Trả về | Bỏ qua NULL? |
| --- | --- | --- |
| `COUNT(*)` | Số dòng | Không: đếm cả dòng có NULL |
| `COUNT(cot)` | Số dòng mà `cot` khác NULL | Có |
| `COUNT(DISTINCT cot)` | Số giá trị khác nhau (không tính NULL) | Có |
| `SUM(cot)` | Tổng | Có |
| `AVG(cot)` | Trung bình cộng | Có |
| `MIN(cot)`, `MAX(cot)` | Nhỏ nhất, lớn nhất (số, ngày, chuỗi) | Có |

Câu truy vấn có hàm tổng hợp (và chưa có `GROUP BY`) chạy theo thứ tự: `FROM` lấy bảng, `WHERE` lọc dòng, rồi hàm tổng hợp gom các dòng còn lại thành một dòng kết quả. Ngày 9 sẽ chia dòng thành nhiều nhóm và tính mỗi nhóm một kết quả.

## 2. COUNT: đếm

### COUNT(*): đếm dòng

```sql
SELECT COUNT(*) AS so_khach FROM customers;
```

| so_khach |
| --- |
| 18 |

Kết hợp `WHERE` để đếm các dòng thỏa điều kiện. `WHERE` chạy trước, `COUNT` đếm phần còn lại:

```sql
SELECT COUNT(*) AS so_don_da_giao
FROM orders
WHERE status = 'delivered';
```

| so_don_da_giao |
| --- |
| 33 |

### COUNT(cot): đếm giá trị khác NULL

`COUNT(email)` không đếm dòng, mà đếm số dòng có `email` khác NULL. Bảng `customers` cố ý có nhiều chỗ trống, nên các con số khác nhau rõ:

```sql
SELECT COUNT(*)          AS so_dong,
       COUNT(email)      AS co_email,
       COUNT(phone)      AS co_phone,
       COUNT(city)       AS co_city,
       COUNT(birth_date) AS co_ngay_sinh
FROM customers;
```

| so_dong | co_email | co_phone | co_city | co_ngay_sinh |
| --- | --- | --- | --- | --- |
| 18 | 16 | 14 | 16 | 15 |

Từ đây suy ra ngay: có `18 - 16 = 2` khách không có email. Đây là cách nhanh để đo "dữ liệu thiếu bao nhiêu".

### COUNT(DISTINCT cot): đếm giá trị khác nhau

40 đơn hàng nhưng có bao nhiêu khách đã từng mua?

```sql
SELECT COUNT(*)                    AS so_don,
       COUNT(DISTINCT customer_id) AS so_khach_da_mua
FROM orders;
```

| so_don | so_khach_da_mua |
| --- | --- |
| 40 | 16 |

16 trên 18 khách đã mua (khách 16 và 17 chưa mua đơn nào). `COUNT(customer_id)` sẽ cho 40, vì nó đếm mọi giá trị khác NULL, kể cả giá trị lặp lại.

`COUNT(DISTINCT)` cũng là cách phát hiện dữ liệu bẩn. Có bao nhiêu thành phố?

```sql
SELECT COUNT(city)          AS co_city,
       COUNT(DISTINCT city) AS so_cach_viet
FROM customers;
```

| co_city | so_cach_viet |
| --- | --- |
| 16 | 9 |

9 "thành phố" là con số sai: `TP. Hồ Chí Minh`, `Hồ Chí Minh`, `TP.HCM` là một nơi, `Đà Nẵng` và `đà nẵng` cũng vậy. Con số này chỉ đúng sau khi làm sạch cột `city` như Ngày 5 và Ngày 6.

Thêm một điểm tinh tế: `SELECT DISTINCT city FROM customers` trả về 10 dòng, vì `DISTINCT` coi NULL là một giá trị và in ra một dòng trống. `COUNT(DISTINCT city)` thì bỏ qua NULL nên chỉ ra 9.

### Một bảng so sánh

```sql
SELECT COUNT(employee_id)          AS don_co_nhan_vien,
       COUNT(DISTINCT employee_id) AS so_nhan_vien_ban,
       COUNT(*)                    AS tong_so_don
FROM orders;
```

| don_co_nhan_vien | so_nhan_vien_ban | tong_so_don |
| --- | --- | --- |
| 15 | 4 | 40 |

Đọc: 40 đơn; 15 đơn có nhân viên bán (đơn offline, đơn online để `employee_id` là NULL); 15 đơn đó do 4 nhân viên khác nhau bán.

## 3. SUM và AVG

### SUM: tổng

Tổng số máy đang tồn kho và giá trị hàng tồn theo giá bán:

```sql
SELECT SUM(stock_quantity)         AS tong_ton_kho,
       SUM(price * stock_quantity) AS gia_tri_ton_kho
FROM products;
```

| tong_ton_kho | gia_tri_ton_kho |
| --- | --- |
| 496 | 1816880000 |

Bên trong `SUM` có thể là một biểu thức: PostgreSQL tính `price * stock_quantity` cho từng dòng trước, rồi cộng 24 kết quả lại.

### AVG: trung bình

```sql
SELECT MIN(price)        AS re_nhat,
       MAX(price)        AS dat_nhat,
       AVG(price)        AS gia_tb,
       ROUND(AVG(price)) AS gia_tb_lam_tron
FROM products;
```

| re_nhat | dat_nhat | gia_tb | gia_tb_lam_tron |
| --- | --- | --- | --- |
| 150000 | 32990000 | 10832875.000000000000 | 10832875 |

`AVG` trên cột `NUMERIC` trả về `NUMERIC` có rất nhiều chữ số thập phân, nên thường bọc trong `ROUND` (Ngày 5). Với cột số nguyên cũng vậy: `AVG(stock_quantity)` cho `20.6666666666666667`, không bị cắt thành số nguyên như phép chia `INT / INT`.

## 4. MIN và MAX

`MIN`/`MAX` dùng được với số, ngày giờ và chuỗi. Đơn đầu tiên và đơn gần nhất:

```sql
SELECT MIN(order_date) AS don_dau_tien,
       MAX(order_date) AS don_gan_nhat
FROM orders;
```

| don_dau_tien | don_gan_nhat |
| --- | --- |
| 2025-01-12 10:15:00+07 | 2026-10-14 22:00:00+07 |

Với ngày sinh, `MIN` là người lớn tuổi nhất (sinh sớm nhất):

```sql
SELECT MIN(birth_date) AS lon_tuoi_nhat,
       MAX(birth_date) AS tre_nhat
FROM customers;
```

| lon_tuoi_nhat | tre_nhat |
| --- | --- |
| 1985-04-18 | 2005-02-14 |

Ba khách không có `birth_date` bị bỏ qua, không làm hỏng kết quả.

`MIN`/`MAX` chỉ trả về giá trị, không cho biết dòng nào đạt giá trị đó. Muốn biết "thanh toán lớn nhất là của đơn nào", dùng `ORDER BY ... LIMIT` (Ngày 4):

```sql
SELECT order_id, amount, paid_at
FROM payments
ORDER BY amount DESC
LIMIT 1;
```

| order_id | amount | paid_at |
| --- | --- | --- |
| 39 | 39980000 | 2026-10-05 09:05:00+07 |

## 5. NULL trong hàm tổng hợp

Đây là phần quan trọng nhất của bài. Quy tắc chỉ có một câu: mọi hàm tổng hợp bỏ qua NULL, trừ `COUNT(*)`.

Xét 3 laptop văn phòng (danh mục 4). HP Pavilion 15 chưa có giá nhập:

```sql
SELECT sku, name, cost_price
FROM products
WHERE category_id = 4;
```

| sku | name | cost_price |
| --- | --- | --- |
| LAP-004 | Dell Inspiron 14 | 16000000 |
| LAP-005 | MacBook Air M2 13 inch | 22000000 |
| LAP-006 | HP Pavilion 15 | NULL |

```sql
SELECT COUNT(*)                   AS so_dong,
       COUNT(cost_price)          AS co_gia_nhap,
       SUM(cost_price)            AS tong,
       AVG(cost_price)            AS tb,
       SUM(cost_price) / COUNT(*) AS chia_cho_ca_3
FROM products
WHERE category_id = 4;
```

| so_dong | co_gia_nhap | tong | tb | chia_cho_ca_3 |
| --- | --- | --- | --- | --- |
| 3 | 2 | 38000000 | 19000000.000000000000 | 12666666.666666666667 |

![Bảng products lọc category_id = 4 có ba dòng: LAP-004 Dell Inspiron 14 giá nhập 16.000.000, LAP-005 MacBook Air M2 13 inch giá nhập 22.000.000, LAP-006 HP Pavilion 15 giá nhập NULL. Kết quả từng hàm: COUNT(*) = 3 vì đếm mọi dòng kể cả dòng NULL; COUNT(cost_price) = 2 vì chỉ đếm dòng có giá trị; SUM(cost_price) = 38.000.000 vì chỉ cộng giá trị khác NULL; AVG(cost_price) = 19.000.000, tức 38.000.000 chia 2, được tô nổi bật; AVG(COALESCE(cost_price, 0)) = 12.666.667 vì coi NULL là 0 và chia 3. Chú thích: NULL là chưa biết, không phải 0; hàm tổng hợp bỏ qua nó, trừ COUNT(*).](img/null-trong-ham-tong-hop.png#gh-light-mode-only)
![Bảng products lọc category_id = 4 có ba dòng: LAP-004 Dell Inspiron 14 giá nhập 16.000.000, LAP-005 MacBook Air M2 13 inch giá nhập 22.000.000, LAP-006 HP Pavilion 15 giá nhập NULL. Kết quả từng hàm: COUNT(*) = 3 vì đếm mọi dòng kể cả dòng NULL; COUNT(cost_price) = 2 vì chỉ đếm dòng có giá trị; SUM(cost_price) = 38.000.000 vì chỉ cộng giá trị khác NULL; AVG(cost_price) = 19.000.000, tức 38.000.000 chia 2, được tô nổi bật; AVG(COALESCE(cost_price, 0)) = 12.666.667 vì coi NULL là 0 và chia 3. Chú thích: NULL là chưa biết, không phải 0; hàm tổng hợp bỏ qua nó, trừ COUNT(*).](img/null-trong-ham-tong-hop-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/aggregate-functions/null-trong-ham-tong-hop.html) · [nền tối](../diagrams/aggregate-functions/null-trong-ham-tong-hop-dark.html)</small>

Điểm mấu chốt: `AVG(cost_price)` bằng `SUM(cost_price) / COUNT(cost_price)`, không phải `SUM(cost_price) / COUNT(*)`. Giá nhập trung bình là 19 triệu tính trên 2 máy đã biết giá. Thường đây là điều bạn muốn: giá nhập của HP chưa biết, không có nghĩa là 0 đồng.

Nếu nghiệp vụ thật sự muốn coi NULL là 0, nói rõ bằng `COALESCE` (Ngày 5):

```sql
SELECT ROUND(AVG(cost_price))              AS tb_bo_qua_null,
       ROUND(AVG(COALESCE(cost_price, 0))) AS tb_coi_null_la_0
FROM products
WHERE category_id = 4;
```

| tb_bo_qua_null | tb_coi_null_la_0 |
| --- | --- |
| 19000000 | 12666667 |

### Tập rỗng: SUM trả về NULL, không phải 0

Đơn 40 đang `pending`, chưa có thanh toán nào. Tổng tiền đã thu của đơn này là bao nhiêu?

```sql
SELECT COUNT(*)    AS so_lan_tra,
       SUM(amount) AS tong,
       MAX(amount) AS lon_nhat
FROM payments
WHERE order_id = 40;
```

| so_lan_tra | tong | lon_nhat |
| --- | --- | --- |
| 0 | NULL | NULL |

Không có dòng nào để cộng, nên `SUM`, `AVG`, `MIN`, `MAX` trả về NULL. Chỉ `COUNT` trả về 0. Trong báo cáo, "NULL đồng" dễ gây hiểu lầm hoặc làm hỏng phép tính tiếp theo (`NULL + 5000000` vẫn là NULL), nên bọc `COALESCE`:

```sql
SELECT COALESCE(SUM(amount), 0) AS da_thu
FROM payments
WHERE order_id = 40;
```

| da_thu |
| --- |
| 0 |

### SUM(a - b) khác SUM(a) - SUM(b) khi có NULL

Lợi nhuận dự kiến nếu bán hết hàng tồn, viết theo hai cách tưởng như tương đương:

```sql
SELECT SUM((price - cost_price) * stock_quantity) AS cach_1
FROM products;

SELECT SUM(price * stock_quantity) - SUM(cost_price * stock_quantity) AS cach_2
FROM products;
```

| cach_1 |
| --- |
| 279520000 |

| cach_2 |
| --- |
| 354980000 |

Chênh nhau 75 triệu. Hai sản phẩm thiếu `cost_price` (`LAP-006`, `ACC-009`):

- Cách 1: `price - NULL` là NULL, nên hai sản phẩm này bị bỏ qua hoàn toàn.
- Cách 2: vế đầu vẫn cộng doanh thu của chúng, vế sau không trừ giá vốn, như thể nhập hàng miễn phí. Lợi nhuận "ảo" bằng đúng `16990000 * 4 + 250000 * 30 = 75460000`.

Cách 1 nhất quán hơn (chỉ tính sản phẩm có đủ dữ liệu). Nhưng bài học chính là: khi cột có NULL, hãy kiểm tra bằng `COUNT(cot)` để biết bao nhiêu dòng bị loại, và nói rõ điều đó trong báo cáo.

## 6. Tổng tiền đơn hàng từ order_items

DSC Shop không lưu cột tổng tiền trong `orders`. Tiền của mỗi dòng hàng là:

```text
quantity * unit_price * (1 - discount)
```

`unit_price` là giá lúc mua (không phải `products.price` hiện tại), `discount` là tỉ lệ giảm (`0.10` là 10%). Tổng tiền đơn là `SUM` của biểu thức đó trên các dòng của đơn.

Xem các dòng hàng của đơn 4 trước:

```sql
SELECT product_id, quantity, unit_price, discount,
       quantity * unit_price * (1 - discount) AS thanh_tien
FROM order_items
WHERE order_id = 4;
```

| product_id | quantity | unit_price | discount | thanh_tien |
| --- | --- | --- | --- | --- |
| 20 | 1 | 5990000 | 0.10 | 5391000.00 |
| 17 | 1 | 2490000 | 0.00 | 2490000.00 |

Rồi cộng lại:

```sql
SELECT ROUND(SUM(quantity * unit_price * (1 - discount))) AS tong_tien_don
FROM order_items
WHERE order_id = 4;
```

| tong_tien_don |
| --- |
| 7881000 |

Đối chiếu với tiền khách đã trả:

```sql
SELECT SUM(amount) AS da_thanh_toan
FROM payments
WHERE order_id = 4;
```

| da_thanh_toan |
| --- |
| 7881000 |

Khớp. `discount` có kiểu `NUMERIC(3,2)` nên kết quả nhân ra có đuôi `.00`; `ROUND(...)` (hoặc ép kiểu `::NUMERIC(12,0)`) đưa về đồng nguyên cho dễ đọc.

Đơn 12 trả góp 2 lần, nên phải `SUM` cả bên `payments` mới so được:

```sql
SELECT SUM(quantity * unit_price * (1 - discount))::NUMERIC(12,0) AS tong_tien_don
FROM order_items
WHERE order_id = 12;

SELECT SUM(amount) AS da_thanh_toan, COUNT(*) AS so_lan_tra
FROM payments
WHERE order_id = 12;
```

| tong_tien_don |
| --- |
| 31880000 |

| da_thanh_toan | so_lan_tra |
| --- | --- |
| 31880000 | 2 |

Tổng giá trị hàng của mọi dòng trong `order_items`, và vài con số đếm:

```sql
SELECT ROUND(SUM(quantity * unit_price * (1 - discount))) AS tong_gia_tri_hang,
       SUM(quantity)                                     AS so_san_pham,
       COUNT(*)                                          AS so_dong_hang,
       COUNT(DISTINCT order_id)                          AS so_don,
       COUNT(DISTINCT product_id)                        AS so_mat_hang
FROM order_items;
```

| tong_gia_tri_hang | so_san_pham | so_dong_hang | so_don | so_mat_hang |
| --- | --- | --- | --- | --- |
| 579351000 | 75 | 60 | 40 | 23 |

Con số 579.351.000 chưa phải doanh thu: nó tính cả đơn đã hủy và đơn đang chờ.

> **Định nghĩa dùng trong cả khóa học:** doanh thu là `SUM(quantity * unit_price * (1 - discount))` trên `order_items` của các đơn có `status NOT IN ('pending', 'cancelled')`. Đơn chờ chưa trả tiền, đơn hủy không bán được, nên không tính. Định nghĩa này khớp với tổng tiền trong bảng `payments`.

`status` nằm ở bảng `orders`, còn tiền nằm ở `order_items`. Kết hợp hai bảng trong một câu là việc của JOIN ([Ngày 10](10-join.md)) và subquery ([Ngày 11](11-subquery.md)). Với kiến thức hiện tại, ta làm hai bước. Bước 1, tìm các đơn không được tính:

```sql
SELECT order_id, status
FROM orders
WHERE status IN ('pending', 'cancelled')
ORDER BY order_id;
```

| order_id | status |
| --- | --- |
| 5 | cancelled |
| 15 | cancelled |
| 28 | cancelled |
| 40 | pending |

Bước 2, loại các đơn đó khi cộng:

```sql
SELECT ROUND(SUM(quantity * unit_price * (1 - discount))) AS doanh_thu
FROM order_items
WHERE order_id NOT IN (5, 15, 28, 40);
```

| doanh_thu |
| --- |
| 536291000 |

Đối chiếu với tiền thực thu trong `payments`:

```sql
SELECT SUM(amount) AS tong_thuc_thu FROM payments;
```

| tong_thuc_thu |
| --- |
| 536291000 |

Khớp. Gõ tay danh sách id chỉ ổn khi học; khi dữ liệu thay đổi, danh sách sẽ sai. Ngày 10 và 11 sẽ viết lại thành một câu tự động.

## Lỗi thường gặp

**1. Trộn cột thường với hàm tổng hợp.** Muốn "thanh toán lớn nhất và của đơn nào":

```sql
-- SAI
SELECT order_id, MAX(amount) FROM payments;
```

```text
ERROR:  column "payments.order_id" must appear in the GROUP BY clause or be used in an aggregate function
```

`MAX(amount)` gom 37 dòng thành 1, còn `order_id` có 36 giá trị khác nhau: PostgreSQL không biết in giá trị nào. Cách đúng ở thời điểm này là `ORDER BY amount DESC LIMIT 1` (mục 4). `GROUP BY` ở [Ngày 9](09-group-by-having.md) sẽ giải thích thông báo lỗi này.

> **Ghi chú dialect:** MySQL khi tắt chế độ `ONLY_FULL_GROUP_BY` (mặc định bật từ MySQL 5.7) chấp nhận câu trên và trả về một `order_id` tùy ý, không nhất thiết là đơn có `MAX(amount)`. PostgreSQL và SQL Server luôn báo lỗi.

**2. Dùng hàm tổng hợp trong WHERE.**

```sql
-- SAI
SELECT order_id, amount FROM payments WHERE amount = MAX(amount);
```

```text
ERROR:  aggregate functions are not allowed in WHERE
```

`WHERE` chạy trên từng dòng, trước khi hàm tổng hợp được tính. So sánh với kết quả tổng hợp cần subquery ([Ngày 11](11-subquery.md)) hoặc lọc nhóm bằng `HAVING` ([Ngày 9](09-group-by-having.md)).

**3. Nhân tổng với tổng.** Đơn 13 có 2 sạc Anker 65W (890.000 mỗi cái) và 3 cáp USB-C (150.000 mỗi sợi). Tổng tiền hàng là bao nhiêu?

```sql
-- SAI
SELECT SUM(quantity) * SUM(unit_price) AS sai FROM order_items WHERE order_id = 13;
-- ĐÚNG
SELECT SUM(quantity * unit_price) AS dung FROM order_items WHERE order_id = 13;
```

| sai |
| --- |
| 5200000 |

| dung |
| --- |
| 2230000 |

Cách sai tính `(2 + 3) * (890000 + 150000)`, ghép số lượng của món này với giá của món khác. Luôn tính tiền từng dòng bên trong `SUM`.

**4. Nhầm "trung bình mỗi dòng" với "trung bình mỗi đơn".** `AVG(quantity * unit_price * (1 - discount))` trên `order_items` là trung bình một dòng hàng, không phải giá trị trung bình một đơn (một đơn có nhiều dòng). Xem Bài 9.

**5. Quên rằng SUM của tập rỗng là NULL.** Dùng `COALESCE(SUM(...), 0)` khi kết quả sẽ được hiển thị hoặc đem đi tính tiếp.

**6. SUM/AVG trên cột chữ.** `SUM(full_name)` báo `function sum(character varying) does not exist`. Chỉ `COUNT`, `MIN`, `MAX` dùng được với chuỗi.

## Bài tập

Tất cả chạy trên dữ liệu gốc của DSC Shop.

### Cơ bản

**Bài 1.** Đếm số sản phẩm đang kinh doanh (`is_active = TRUE`) và còn hàng.

<details>
<summary>Đáp án</summary>

```sql
SELECT COUNT(*) AS dang_ban_con_hang
FROM products
WHERE is_active = TRUE
  AND stock_quantity > 0;
```

Kết quả:

| dang_ban_con_hang |
| --- |
| 21 |
</details>

**Bài 2.** Với danh mục `Điện thoại` (`category_id = 7`), tìm giá thấp nhất, cao nhất và giá trung bình làm tròn đến đồng.

<details>
<summary>Đáp án</summary>

```sql
SELECT MIN(price)        AS re_nhat,
       MAX(price)        AS dat_nhat,
       ROUND(AVG(price)) AS gia_tb
FROM products
WHERE category_id = 7;
```

Kết quả:

| re_nhat | dat_nhat | gia_tb |
| --- | --- | --- |
| 690000 | 19990000 | 11140000 |
</details>

**Bài 3.** Trong năm 2025 (theo `order_date`) có bao nhiêu đơn, bao nhiêu khách khác nhau đặt hàng, đơn đầu tiên và đơn cuối cùng vào lúc nào? Dùng điều kiện khoảng, không dùng hàm trên cột ngày.

<details>
<summary>Đáp án</summary>

```sql
SELECT COUNT(*)                    AS so_don,
       COUNT(DISTINCT customer_id) AS so_khach,
       MIN(order_date)             AS don_dau,
       MAX(order_date)             AS don_cuoi
FROM orders
WHERE order_date >= '2025-01-01'
  AND order_date <  '2026-01-01';
```

Kết quả:

| so_don | so_khach | don_dau | don_cuoi |
| --- | --- | --- | --- |
| 25 | 16 | 2025-01-12 10:15:00+07 | 2025-12-24 16:00:00+07 |
</details>

### Vận dụng

**Bài 4.** Tính tỉ lệ phần trăm khách hàng có email (làm tròn 1 chữ số), kèm số khách không có email. Chỉ dùng một câu `SELECT`, không dùng `WHERE`.

<details>
<summary>Đáp án</summary>

```sql
SELECT COUNT(*)                                AS tong_khach,
       COUNT(email)                            AS co_email,
       COUNT(*) - COUNT(email)                 AS khong_email,
       ROUND(100.0 * COUNT(email) / COUNT(*), 1) AS ti_le_co_email
FROM customers;
```

Kết quả:

| tong_khach | co_email | khong_email | ti_le_co_email |
| --- | --- | --- | --- |
| 18 | 16 | 2 | 88.9 |

Nhân `100.0` (số thập phân) trước khi chia để tránh phép chia nguyên `16 / 18 = 0` (Ngày 5).
</details>

**Bài 5.** Tính tổng tiền đơn 22 (cả hai món đều được giảm giá) từ `order_items`, làm tròn đến đồng, rồi đối chiếu với số tiền trong `payments`.

<details>
<summary>Đáp án</summary>

```sql
SELECT product_id, quantity, unit_price, discount
FROM order_items
WHERE order_id = 22;

SELECT ROUND(SUM(quantity * unit_price * (1 - discount))) AS tong_tien_don
FROM order_items
WHERE order_id = 22;

SELECT SUM(amount) AS da_thanh_toan
FROM payments
WHERE order_id = 22;
```

Kết quả:

| product_id | quantity | unit_price | discount |
| --- | --- | --- | --- |
| 20 | 1 | 5990000 | 0.15 |
| 12 | 1 | 4890000 | 0.10 |

| tong_tien_don |
| --- |
| 9492500 |

| da_thanh_toan |
| --- |
| 9492500 |

`5990000 * 0.85 + 4890000 * 0.90 = 5091500 + 4401000 = 9492500`.
</details>

**Bài 6.** Với các đơn `online`: có bao nhiêu đơn, bao nhiêu đơn có ghi `shipping_city`, và giao tới bao nhiêu thành phố khác nhau?

<details>
<summary>Đáp án</summary>

```sql
SELECT COUNT(*)                      AS so_don_online,
       COUNT(shipping_city)          AS co_dia_chi,
       COUNT(DISTINCT shipping_city) AS so_thanh_pho
FROM orders
WHERE channel = 'online';
```

Kết quả:

| so_don_online | co_dia_chi | so_thanh_pho |
| --- | --- | --- |
| 25 | 25 | 6 |

Mọi đơn online đều có địa chỉ giao; `shipping_city` chỉ NULL ở đơn offline (khách nhận tại cửa hàng).
</details>

**Bài 7.** Có bao nhiêu dòng hàng được giảm giá, và tổng số tiền cửa hàng đã giảm cho khách trên các dòng đó là bao nhiêu (làm tròn đến đồng)?

<details>
<summary>Đáp án</summary>

```sql
SELECT COUNT(*)                                  AS so_dong_giam_gia,
       ROUND(SUM(quantity * unit_price * discount)) AS tong_tien_giam
FROM order_items
WHERE discount > 0;
```

Kết quả:

| so_dong_giam_gia | tong_tien_giam |
| --- | --- |
| 9 | 9233000 |
</details>

### Thử thách

**Bài 8.** Giám đốc hỏi "giá trị trung bình mỗi lần thanh toán là bao nhiêu" và "trung bình mỗi đơn đã thanh toán trả bao nhiêu tiền". Tính cả hai trên `payments` trong một câu và giải thích vì sao khác nhau.

<details>
<summary>Đáp án</summary>

```sql
SELECT COUNT(*)                                     AS so_lan_tt,
       COUNT(DISTINCT order_id)                     AS so_don,
       SUM(amount)                                  AS tong,
       ROUND(AVG(amount))                           AS tb_moi_lan,
       ROUND(SUM(amount) / COUNT(DISTINCT order_id)) AS tb_moi_don
FROM payments;
```

Kết quả:

| so_lan_tt | so_don | tong | tb_moi_lan | tb_moi_don |
| --- | --- | --- | --- | --- |
| 37 | 36 | 536291000 | 14494351 | 14896972 |

`AVG(amount)` chia tổng cho 37 lần thanh toán. Đơn 12 trả góp 2 lần nên số đơn chỉ là 36; trung bình mỗi đơn phải chia cho `COUNT(DISTINCT order_id)`. Hai câu hỏi nghe giống nhau nhưng "đơn vị đếm" khác nhau.
</details>

**Bài 9.** Tính trên toàn bộ `order_items`: tổng giá trị hàng, số đơn, giá trị trung bình mỗi đơn và giá trị trung bình mỗi dòng hàng (làm tròn đến đồng). Vì sao không dùng `AVG(quantity * unit_price * (1 - discount))` làm "trung bình mỗi đơn"?

<details>
<summary>Đáp án</summary>

```sql
SELECT COUNT(DISTINCT order_id) AS so_don,
       ROUND(SUM(quantity * unit_price * (1 - discount)))                            AS tong_tien,
       ROUND(SUM(quantity * unit_price * (1 - discount)) / COUNT(DISTINCT order_id)) AS tb_moi_don,
       ROUND(AVG(quantity * unit_price * (1 - discount)))                            AS tb_moi_dong
FROM order_items;
```

Kết quả:

| so_don | tong_tien | tb_moi_don | tb_moi_dong |
| --- | --- | --- | --- |
| 40 | 579351000 | 14483775 | 9655850 |

`AVG` chia cho số dòng được tổng hợp, ở đây là 60 dòng hàng, nên ra trung bình một dòng (9.655.850). Một đơn có thể có 1 đến 3 dòng, nên trung bình mỗi đơn phải lấy tổng chia số đơn khác nhau (14.483.775). Bài này tính trên mọi đơn, kể cả đơn chờ và đơn hủy, nên `tong_tien` không phải doanh thu theo định nghĩa ở mục 6.
</details>

## Tóm tắt

- Hàm tổng hợp gom nhiều dòng thành một giá trị. `WHERE` lọc dòng trước, hàm tổng hợp tính sau.
- `COUNT(*)` đếm dòng; `COUNT(cot)` đếm giá trị khác NULL; `COUNT(DISTINCT cot)` đếm giá trị khác nhau, không tính NULL.
- `SUM`, `AVG`, `MIN`, `MAX` bỏ qua NULL. `AVG(cot) = SUM(cot) / COUNT(cot)`, không chia cho `COUNT(*)`.
- Trên tập rỗng, `COUNT` trả 0 còn các hàm khác trả NULL; dùng `COALESCE(SUM(...), 0)` khi cần.
- Tổng tiền đơn = `SUM(quantity * unit_price * (1 - discount))` trên `order_items` của đơn đó; tính tiền từng dòng bên trong `SUM`.
- Doanh thu = tổng tiền các đơn có `status NOT IN ('pending', 'cancelled')`, khớp với tổng `payments`.
- Không trộn cột thường với hàm tổng hợp khi chưa có `GROUP BY`, và không đặt hàm tổng hợp trong `WHERE`.

## Đọc thêm

- [PostgreSQL: Aggregate Functions](https://www.postgresql.org/docs/16/functions-aggregate.html)
- [PostgreSQL tutorial: Aggregate Functions](https://www.postgresql.org/docs/16/tutorial-agg.html)
- [Vì sao NOT IN của bạn trả về 0 dòng? Logic ba trị của SQL và cái bẫy NULL](https://tiennhm.io.vn/blog/sql-null-not-in-three-valued-logic) — Một câu NOT IN trả về đúng 0 dòng trong khi bảng có dữ liệu, còn NOT EXISTS cùng ý định lại trả về đủ.
- [Luỹ kế của bạn sai ngay dòng đầu: window function, RANGE và cái mặc định ít ai đọc](https://tiennhm.io.vn/blog/window-function-vs-group-by) — GROUP BY gom 200.000 dòng thành 200, window function giữ nguyên cả 200.000 mà vẫn có số tổng của nhóm.

---

[⬅️ Ngày 7: Ôn tập 1 (Ngày 1 đến 6)](07-review-1.md) | [📚 Mục lục](../README.md) | [Ngày 9: Nhóm dữ liệu với GROUP BY và HAVING ➡️](09-group-by-having.md)
