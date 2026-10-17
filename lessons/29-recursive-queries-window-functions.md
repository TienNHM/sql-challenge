# Ngày 29: Window function và truy vấn đệ quy

> **Tóm tắt:** Window function tính toán trên một "cửa sổ" các dòng liên quan mà không gộp dòng như GROUP BY, nên làm được xếp hạng, lũy kế, trung bình trượt, so sánh với kỳ trước và top-N mỗi nhóm. CTE đệ quy (`WITH RECURSIVE`) lặp một truy vấn cho tới khi không còn dòng mới, dùng để duyệt dữ liệu dạng cây như danh mục sản phẩm hay sơ đồ tổ chức. Bài này dạy cả hai trên DSC Shop, kèm cách chặn vòng lặp vô hạn.

**Sau bài này bạn có thể:**
- Viết được `SUM/AVG/COUNT ... OVER (PARTITION BY ... ORDER BY ...)` để tính tỷ trọng, lũy kế và trung bình trượt mà vẫn giữ từng dòng.
- Chọn đúng `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `NTILE` khi xếp hạng có giá trị bằng nhau, và lấy top-N mỗi nhóm qua CTE.
- Giải thích được khung (frame) `ROWS` và `RANGE`, và nhận ra bẫy khung mặc định khi `ORDER BY` có giá trị trùng.
- Dùng `LAG`/`LEAD` để so sánh doanh thu tháng này với tháng trước.
- Viết được CTE đệ quy duyệt cây `categories` và `employees` theo cả hai chiều, có điều kiện dừng và cơ chế chống vòng lặp (mảng đường đi hoặc mệnh đề `CYCLE`).

**Cần biết trước:** [Ngày 5](05-operators-expressions.md) (DATE_TRUNC, EXTRACT, ROUND), [Ngày 8](08-aggregate-functions.md), [Ngày 9](09-group-by-having.md), [Ngày 10](10-join.md) (SELF JOIN trên `employees`), [Ngày 11](11-subquery.md) (CTE `WITH`).

Quy ước dùng trong cả bài:

- **Doanh thu** chỉ tính đơn đã thanh toán, tức `status NOT IN ('pending', 'cancelled')`.
- Tiền một dòng hàng là `quantity * unit_price * (1 - discount)`. Vì `discount` có kiểu `NUMERIC(3,2)` nên kết quả có đuôi `.00`; bài bọc `ROUND(...)` để in gọn thành số nguyên VNĐ.

---

## Phần A. Window function

### 1. GROUP BY gộp dòng, window function giữ dòng

Đếm số đơn đã thanh toán của khách 1 và khách 2 bằng GROUP BY:

```sql
SELECT customer_id,
       COUNT(*) AS so_don
FROM orders
WHERE status NOT IN ('pending', 'cancelled')
  AND customer_id IN (1, 2)
GROUP BY customer_id;
```

| customer_id | so_don |
| --- | --- |
| 1 | 5 |
| 2 | 4 |

Kết quả chỉ còn 2 dòng: chi tiết từng đơn đã mất. Nếu bạn muốn thấy **từng đơn** và **cạnh nó** là tổng số đơn của khách đó, hãy dùng window function: thêm `OVER (...)` sau hàm tổng hợp.

```sql
SELECT order_id,
       customer_id,
       order_date::date AS ngay,
       COUNT(*) OVER (PARTITION BY customer_id) AS so_don_cua_khach
FROM orders
WHERE status NOT IN ('pending', 'cancelled')
  AND customer_id IN (1, 2)
ORDER BY customer_id, order_date;
```

| order_id | customer_id | ngay | so_don_cua_khach |
| --- | --- | --- | --- |
| 1 | 1 | 2025-01-12 | 5 |
| 4 | 1 | 2025-02-14 | 5 |
| 13 | 1 | 2025-07-08 | 5 |
| 25 | 1 | 2025-12-24 | 5 |
| 37 | 1 | 2026-09-02 | 5 |
| 2 | 2 | 2025-01-20 | 4 |
| 8 | 2 | 2025-04-22 | 4 |
| 22 | 2 | 2025-11-11 | 4 |
| 34 | 2 | 2026-06-15 | 4 |

Vẫn đủ 9 dòng. Với mỗi dòng, PostgreSQL nhìn qua một "cửa sổ" gồm các dòng cùng `customer_id` rồi đếm trong cửa sổ đó. Đó là ý nghĩa của chữ *window*.

Hình dung đời thường: bảng điểm của lớp. GROUP BY giống tờ tổng kết chỉ ghi "điểm trung bình lớp A: 7,2". Window function giống bảng điểm từng bạn, có thêm cột "điểm trung bình lớp mình" và "hạng trong lớp" ngay bên cạnh.

### 2. Cú pháp OVER: PARTITION BY, ORDER BY, khung

```text
ham(...) OVER (
    PARTITION BY <cột chia nhóm>      -- tùy chọn: chia dòng thành từng nhóm
    ORDER BY <cột sắp xếp>            -- tùy chọn: thứ tự các dòng trong nhóm
    <khung>                           -- tùy chọn: ROWS/RANGE BETWEEN ... AND ...
)
```

- `OVER ()` rỗng: cửa sổ là **toàn bộ kết quả** (sau WHERE).
- `PARTITION BY`: chia thành nhóm, mỗi dòng chỉ nhìn thấy nhóm của nó. Giống GROUP BY nhưng không gộp dòng.
- `ORDER BY` trong `OVER`: thứ tự các dòng trong nhóm. Cần cho xếp hạng, lũy kế, LAG/LEAD. Nó không quyết định thứ tự in kết quả, đó vẫn là việc của `ORDER BY` cuối câu.
- Khung (frame): trong nhóm đã sắp xếp, dòng nào được đưa vào phép tính cho dòng hiện tại. Học kỹ ở mục 5.

Ví dụ tính tỷ trọng mỗi đơn trong tổng chi tiêu của khách. Truy vấn dùng một CTE `order_totals` tính tổng tiền từng đơn (CTE đã học ở Ngày 11):

```sql
WITH order_totals AS (
    SELECT o.order_id,
           o.customer_id,
           o.order_date::date AS ngay,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS tong_tien
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.order_id
)
SELECT order_id,
       customer_id,
       tong_tien,
       SUM(tong_tien) OVER (PARTITION BY customer_id) AS tong_cua_khach,
       ROUND(100.0 * tong_tien / SUM(tong_tien) OVER (PARTITION BY customer_id), 1) AS pct_cua_khach,
       SUM(tong_tien) OVER () AS tong_toan_shop
FROM order_totals
WHERE customer_id IN (1, 2)
ORDER BY customer_id, ngay;
```

| order_id | customer_id | tong_tien | tong_cua_khach | pct_cua_khach | tong_toan_shop |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | 699000 | 45430000 | 1.5 | 103692500 |
| 4 | 1 | 7881000 | 45430000 | 17.3 | 103692500 |
| 13 | 1 | 2230000 | 45430000 | 4.9 | 103692500 |
| 25 | 1 | 24980000 | 45430000 | 55.0 | 103692500 |
| 37 | 1 | 9640000 | 45430000 | 21.2 | 103692500 |
| 2 | 2 | 26990000 | 58262500 | 46.3 | 103692500 |
| 8 | 2 | 20140000 | 58262500 | 34.6 | 103692500 |
| 22 | 2 | 9492500 | 58262500 | 16.3 | 103692500 |
| 34 | 2 | 1640000 | 58262500 | 2.8 | 103692500 |

Để ý cột `tong_toan_shop`: 103692500 chỉ là tổng của **khách 1 và 2**, không phải cả shop. Window function chạy **sau** WHERE, nên nó chỉ thấy những dòng còn lại sau khi lọc.

Vị trí của window function trong thứ tự thực thi logic (bổ sung cho sơ đồ ở [Ngày 9](09-group-by-having.md)):

```text
FROM → WHERE → GROUP BY → HAVING → window function → SELECT (đặt alias) → DISTINCT → ORDER BY → LIMIT
```

Hệ quả: không dùng window function trong WHERE, GROUP BY, HAVING được (mục 8), nhưng dùng được trong ORDER BY cuối câu.

### 3. Hàm xếp hạng: ROW_NUMBER, RANK, DENSE_RANK, NTILE

Xếp hạng các mẫu điện thoại (danh mục 7) theo số lượng đã bán. iPhone 15 và Xiaomi Redmi Note 13 cùng bán 4 chiếc, Samsung Galaxy S24 và Nokia 105 4G cùng bán 2 chiếc, nên ta thấy rõ cách mỗi hàm xử lý giá trị bằng nhau:

```sql
WITH ban_ra AS (
    SELECT p.name,
           SUM(oi.quantity) AS so_luong
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.status NOT IN ('pending', 'cancelled')
      AND p.category_id = 7
    GROUP BY p.product_id, p.name
)
SELECT name,
       so_luong,
       ROW_NUMBER() OVER (ORDER BY so_luong DESC, name) AS row_num,
       RANK()       OVER (ORDER BY so_luong DESC)       AS sales_rank,
       DENSE_RANK() OVER (ORDER BY so_luong DESC)       AS dense_rnk
FROM ban_ra
ORDER BY so_luong DESC, name;
```

| name | so_luong | row_num | sales_rank | dense_rnk |
| --- | --- | --- | --- | --- |
| iPhone 15 128GB | 4 | 1 | 1 | 1 |
| Xiaomi Redmi Note 13 | 4 | 2 | 1 | 1 |
| Nokia 105 4G | 2 | 3 | 3 | 2 |
| Samsung Galaxy S24 | 2 | 4 | 3 | 2 |

| Hàm | Khi bằng nhau | Dùng khi |
| --- | --- | --- |
| `ROW_NUMBER()` | Vẫn đánh số khác nhau 1, 2, 3, 4 | Cần đúng một dòng mỗi vị trí: phân trang, lấy "đơn đầu tiên", top-N cứng |
| `RANK()` | Cùng hạng, rồi **nhảy** số: 1, 1, 3 | Bảng xếp hạng thi đấu: hai người đồng hạng nhất thì không có hạng nhì |
| `DENSE_RANK()` | Cùng hạng, **không nhảy**: 1, 1, 2 | Đếm "mức" giá trị: mức bán chạy thứ 2 |

Lưu ý với `ROW_NUMBER()`: khi hai dòng bằng nhau ở cột sắp xếp, dòng nào được số 1 là **không xác định**, có thể đổi giữa hai lần chạy. Vì vậy ví dụ trên thêm `name` vào `ORDER BY` làm cột phụ (tie-breaker) để kết quả luôn như nhau.

> **Ghi chú dialect:** Từ MySQL 8.0.2, `RANK` là từ khóa dành riêng, nên alias `AS rank` báo lỗi cú pháp. Bài này đặt tên `sales_rank`, `dense_rnk` để chạy được ở mọi nơi. Window function chỉ có từ MySQL 8.0 trở lên.

`NTILE(n)` chia các dòng đã sắp xếp thành `n` nhóm gần bằng nhau, hay dùng để phân khúc khách hàng. Chia 16 khách đã mua hàng thành 4 nhóm theo tổng chi tiêu:

```sql
WITH chi_tieu AS (
    SELECT o.customer_id,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS tong_chi
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.customer_id
)
SELECT c.full_name,
       ct.tong_chi,
       NTILE(4) OVER (ORDER BY ct.tong_chi DESC) AS nhom
FROM chi_tieu ct
JOIN customers c ON c.customer_id = ct.customer_id
ORDER BY ct.tong_chi DESC;
```

| full_name | tong_chi | nhom |
| --- | --- | --- |
| Dương Minh Khoa | 63220500 | 1 |
| Nguyễn Văn An | 58970000 | 1 |
| Trần Thị Bình | 58262500 | 1 |
| Mai Đức Uy | 46980000 | 1 |
| Huỳnh Tấn Phát | 45880500 | 2 |
| Nguyễn Văn An | 45430000 | 2 |
| ... | ... | ... |
| Hoàng Thị Em | 1380000 | 4 |

(... tổng 16 dòng, mỗi nhóm 4 khách.) Hai dòng "Nguyễn Văn An" là hai người khác nhau (khách 15 và khách 1), nhắc bạn rằng gom theo `customer_id` chứ đừng gom theo tên.

### 4. Hàm tổng hợp có ORDER BY: lũy kế

Thêm `ORDER BY` vào `OVER` của `SUM` là có ngay tổng lũy kế (running total). Lũy kế chi tiêu của khách 1 và 2 theo thời gian, kèm tổng của "hai đơn gần nhất":

```sql
WITH order_totals AS (
    SELECT o.order_id,
           o.customer_id,
           o.order_date::date AS ngay,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS tong_tien
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.order_id
)
SELECT customer_id,
       order_id,
       ngay,
       tong_tien,
       SUM(tong_tien) OVER (PARTITION BY customer_id ORDER BY ngay
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS luy_ke,
       SUM(tong_tien) OVER (PARTITION BY customer_id ORDER BY ngay
                            ROWS BETWEEN 1 PRECEDING AND CURRENT ROW) AS hai_don_gan_nhat
FROM order_totals
WHERE customer_id IN (1, 2)
ORDER BY customer_id, ngay;
```

| customer_id | order_id | ngay | tong_tien | luy_ke | hai_don_gan_nhat |
| --- | --- | --- | --- | --- | --- |
| 1 | 1 | 2025-01-12 | 699000 | 699000 | 699000 |
| 1 | 4 | 2025-02-14 | 7881000 | 8580000 | 8580000 |
| 1 | 13 | 2025-07-08 | 2230000 | 10810000 | 10111000 |
| 1 | 25 | 2025-12-24 | 24980000 | 35790000 | 27210000 |
| 1 | 37 | 2026-09-02 | 9640000 | 45430000 | 34620000 |
| 2 | 2 | 2025-01-20 | 26990000 | 26990000 | 26990000 |
| 2 | 8 | 2025-04-22 | 20140000 | 47130000 | 47130000 |
| 2 | 22 | 2025-11-11 | 9492500 | 56622500 | 29632500 |
| 2 | 34 | 2026-06-15 | 1640000 | 58262500 | 11132500 |

Sơ đồ dưới đây cho thấy chuyện gì xảy ra ở dòng đơn 13:

![Window function trên các đơn của khách 1 và khách 2. Kết quả vẫn đủ 9 dòng, chia thành hai partition theo customer_id. Partition customer_id = 1 gồm các đơn 1, 4, 13, 25, 37; partition customer_id = 2 gồm các đơn 2, 8, 22, 34. Dòng hiện tại là đơn 13 (2025-07-08, 2230000). Khung ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW gồm đơn 1, 4, 13 nên SUM = 699000 + 7881000 + 2230000 = 10810000. Khung ROWS BETWEEN 1 PRECEDING AND CURRENT ROW chỉ gồm đơn 4 và 13 nên SUM = 10111000. Sang partition mới, lũy kế bắt đầu lại: đơn 2 chỉ thấy chính nó, luy_ke = 26990000. Ba phần trong OVER đọc theo thứ tự: 1 PARTITION BY customer_id chia dòng thành nhóm, 2 ORDER BY ngay xếp thứ tự trong nhóm, 3 ROWS BETWEEN chọn khung cho từng dòng.](img/cua-so-va-khung.png#gh-light-mode-only)
![Window function trên các đơn của khách 1 và khách 2. Kết quả vẫn đủ 9 dòng, chia thành hai partition theo customer_id. Partition customer_id = 1 gồm các đơn 1, 4, 13, 25, 37; partition customer_id = 2 gồm các đơn 2, 8, 22, 34. Dòng hiện tại là đơn 13 (2025-07-08, 2230000). Khung ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW gồm đơn 1, 4, 13 nên SUM = 699000 + 7881000 + 2230000 = 10810000. Khung ROWS BETWEEN 1 PRECEDING AND CURRENT ROW chỉ gồm đơn 4 và 13 nên SUM = 10111000. Sang partition mới, lũy kế bắt đầu lại: đơn 2 chỉ thấy chính nó, luy_ke = 26990000. Ba phần trong OVER đọc theo thứ tự: 1 PARTITION BY customer_id chia dòng thành nhóm, 2 ORDER BY ngay xếp thứ tự trong nhóm, 3 ROWS BETWEEN chọn khung cho từng dòng.](img/cua-so-va-khung-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/recursive-queries-window-functions/cua-so-va-khung.html) · [nền tối](../diagrams/recursive-queries-window-functions/cua-so-va-khung-dark.html)</small>

### 5. Khung (frame): ROWS và RANGE

Khung viết theo dạng `ROWS BETWEEN <đầu> AND <cuối>` hoặc `RANGE BETWEEN <đầu> AND <cuối>`:

| Mốc | Nghĩa |
| --- | --- |
| `UNBOUNDED PRECEDING` | Dòng đầu tiên của partition |
| `n PRECEDING` | n dòng trước dòng hiện tại (với ROWS) |
| `CURRENT ROW` | Dòng hiện tại |
| `n FOLLOWING` | n dòng sau dòng hiện tại |
| `UNBOUNDED FOLLOWING` | Dòng cuối cùng của partition |

- `ROWS` đếm theo **vị trí dòng**: "1 PRECEDING" là đúng một dòng phía trước.
- `RANGE` đếm theo **giá trị của cột ORDER BY**: mọi dòng có cùng giá trị với dòng hiện tại được coi là "ngang hàng" (peer) và luôn vào khung cùng nhau.

**Khung mặc định**, điều ít ai đọc kỹ:

- Có `ORDER BY` trong OVER mà không ghi khung: mặc định là `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
- Không có `ORDER BY`: khung là cả partition.

Khác biệt chỉ lộ ra khi cột `ORDER BY` có giá trị trùng. Ngày 11/11/2025 có hai đơn (21 và 22). Lũy kế doanh thu tháng 11/2025 theo ngày:

```sql
WITH order_totals AS (
    SELECT o.order_id,
           o.order_date::date AS ngay,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS tong_tien
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
      AND o.order_date >= '2025-11-01' AND o.order_date < '2025-12-01'
    GROUP BY o.order_id
)
SELECT order_id,
       ngay,
       tong_tien,
       SUM(tong_tien) OVER (ORDER BY ngay) AS mac_dinh_range,
       SUM(tong_tien) OVER (ORDER BY ngay
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS theo_rows
FROM order_totals
ORDER BY ngay, order_id;
```

| order_id | ngay | tong_tien | mac_dinh_range | theo_rows |
| --- | --- | --- | --- | --- |
| 21 | 2025-11-11 | 14280000 | 23772500 | 14280000 |
| 22 | 2025-11-11 | 9492500 | 23772500 | 23772500 |
| 23 | 2025-11-25 | 16990000 | 40762500 | 40762500 |

Với khung mặc định (RANGE), hai đơn cùng ngày là peer nên **cả hai** đều thấy tổng 23772500 ngay từ dòng đầu. Nếu bạn muốn "lũy kế từng đơn", đó là kết quả sai. Với ROWS, lũy kế tăng dần từng dòng. Cả hai cách đều "đúng" theo định nghĩa của chúng; vấn đề là bạn phải chọn có chủ đích:

- Muốn lũy kế **theo ngày** (mọi đơn trong một ngày cùng một số): RANGE là đúng.
- Muốn lũy kế **theo từng dòng**: ghi rõ `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` và thêm cột phụ vào ORDER BY (ví dụ `ORDER BY ngay, order_id`) để thứ tự các dòng trùng ngày được xác định.

> PostgreSQL còn có kiểu khung `GROUPS` và `RANGE` theo khoảng giá trị (ví dụ `RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW`). Bài này chỉ cần ROWS và RANGE cơ bản.

### 6. Báo cáo doanh thu theo tháng: lũy kế và trung bình trượt

Bài toán hay gặp nhất: doanh thu từng tháng năm 2025, lũy kế từ đầu năm, và trung bình 3 tháng gần nhất để làm mượt biến động.

```sql
WITH doanh_thu_thang AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS thang,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
      AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT to_char(thang, 'YYYY-MM') AS thang,
       doanh_thu,
       SUM(doanh_thu) OVER (ORDER BY thang) AS luy_ke,
       ROUND(AVG(doanh_thu) OVER (ORDER BY thang
                                  ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS tb_3_thang
FROM doanh_thu_thang
ORDER BY thang;
```

| thang | doanh_thu | luy_ke | tb_3_thang |
| --- | --- | --- | --- |
| 2025-01 | 27689000 | 27689000 | 27689000 |
| 2025-02 | 13661000 | 41350000 | 20675000 |
| 2025-03 | 1380000 | 42730000 | 14243333 |
| 2025-04 | 42379500 | 85109500 | 19140167 |
| 2025-05 | 16570000 | 101679500 | 20109833 |
| 2025-06 | 50769000 | 152448500 | 36572833 |
| 2025-07 | 11720000 | 164168500 | 26353000 |
| 2025-08 | 8980000 | 173148500 | 23823000 |
| 2025-09 | 43568500 | 216717000 | 21422833 |
| 2025-10 | 18990000 | 235707000 | 23846167 |
| 2025-11 | 40762500 | 276469500 | 34440333 |
| 2025-12 | 49661000 | 326130500 | 36471167 |

Vài điều đáng chú ý:

- `luy_ke` dùng khung mặc định (RANGE) nhưng vẫn đúng, vì mỗi tháng chỉ có một dòng, không có giá trị trùng.
- `tb_3_thang` của tháng 1 và tháng 2 chỉ là trung bình của 1 và 2 tháng, vì phía trước chưa đủ 2 dòng. Khung không "bịa" thêm dòng.
- Cách này giả định tháng nào cũng có đơn. Nếu có tháng trống, tháng đó không có dòng nào và "2 PRECEDING" sẽ nhảy qua nó. Muốn chắc chắn, hãy sinh đủ danh sách tháng trước (bằng `generate_series` hoặc CTE đệ quy ở Phần B) rồi LEFT JOIN.
- `DATE_TRUNC` trên `TIMESTAMPTZ` cắt theo múi giờ của phiên. Database của khóa học đặt sẵn `Asia/Ho_Chi_Minh` nên tháng được tính theo giờ Việt Nam.

### 7. LAG và LEAD: so với dòng trước, dòng sau

`LAG(cot, n, mac_dinh)` lấy giá trị của dòng đứng trước n dòng (mặc định n = 1) trong cùng partition; `LEAD` lấy dòng đứng sau. Không có dòng đó thì trả `NULL` (hoặc giá trị `mac_dinh` nếu bạn truyền vào).

Tăng trưởng doanh thu so với tháng trước:

```sql
WITH doanh_thu_thang AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS thang,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
      AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT to_char(thang, 'YYYY-MM') AS thang,
       doanh_thu,
       LAG(doanh_thu)  OVER (ORDER BY thang) AS thang_truoc,
       LEAD(doanh_thu) OVER (ORDER BY thang) AS thang_sau,
       ROUND(100.0 * (doanh_thu - LAG(doanh_thu) OVER (ORDER BY thang))
                   / LAG(doanh_thu) OVER (ORDER BY thang), 1) AS tang_truong_pct
FROM doanh_thu_thang
ORDER BY thang;
```

| thang | doanh_thu | thang_truoc | thang_sau | tang_truong_pct |
| --- | --- | --- | --- | --- |
| 2025-01 | 27689000 | NULL | 13661000 | NULL |
| 2025-02 | 13661000 | 27689000 | 1380000 | -50.7 |
| 2025-03 | 1380000 | 13661000 | 42379500 | -89.9 |
| 2025-04 | 42379500 | 1380000 | 16570000 | 2971.0 |
| 2025-05 | 16570000 | 42379500 | 50769000 | -60.9 |
| 2025-06 | 50769000 | 16570000 | 11720000 | 206.4 |
| ... | ... | ... | ... | ... |
| 2025-12 | 49661000 | 40762500 | NULL | 21.8 |

(... tổng 12 dòng.) Tháng 1 không có tháng trước nên `LAG` là NULL, và phép tính tăng trưởng cũng NULL theo (NULL lan truyền như đã học ở Ngày 3). Con số +2971% của tháng 4 là thật: tháng 3 chỉ có một đơn 1,38 triệu. Đây là lý do báo cáo thật thường xem kèm trung bình trượt chứ không chỉ % tăng trưởng.

`LAG` cũng hay dùng kèm `PARTITION BY` để so sánh trong từng nhóm. Số ngày giữa hai lần mua liên tiếp của khách 1 và khách 6:

```sql
SELECT customer_id,
       order_id,
       order_date::date AS ngay,
       order_date::date - LAG(order_date::date) OVER (PARTITION BY customer_id ORDER BY order_date) AS cach_don_truoc
FROM orders
WHERE status NOT IN ('pending', 'cancelled')
  AND customer_id IN (1, 6)
ORDER BY customer_id, order_date;
```

| customer_id | order_id | ngay | cach_don_truoc |
| --- | --- | --- | --- |
| 1 | 1 | 2025-01-12 | NULL |
| 1 | 4 | 2025-02-14 | 33 |
| 1 | 13 | 2025-07-08 | 144 |
| 1 | 25 | 2025-12-24 | 169 |
| 1 | 37 | 2026-09-02 | 252 |
| 6 | 7 | 2025-04-05 | NULL |
| 6 | 19 | 2025-09-06 | 154 |
| 6 | 35 | 2026-07-07 | 304 |

Trừ hai giá trị `DATE` cho ra số ngày (kiểu INT).

### 8. FIRST_VALUE, LAST_VALUE và bẫy khung

`FIRST_VALUE(cot)` lấy giá trị ở dòng đầu khung, `LAST_VALUE(cot)` lấy ở dòng cuối khung. Tìm sản phẩm đắt nhất và rẻ nhất trong từng danh mục laptop:

```sql
SELECT category_id,
       name,
       price,
       FIRST_VALUE(name) OVER (PARTITION BY category_id ORDER BY price DESC) AS dat_nhat,
       LAST_VALUE(name)  OVER (PARTITION BY category_id ORDER BY price DESC) AS last_sai,
       LAST_VALUE(name)  OVER (PARTITION BY category_id ORDER BY price DESC
                               ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS re_nhat
FROM products
WHERE category_id IN (3, 4)
ORDER BY category_id, price DESC;
```

| category_id | name | price | dat_nhat | last_sai | re_nhat |
| --- | --- | --- | --- | --- | --- |
| 3 | ASUS ROG Strix G16 | 32990000 | ASUS ROG Strix G16 | ASUS ROG Strix G16 | Acer Nitro V 15 |
| 3 | Lenovo Legion 5 | 29990000 | ASUS ROG Strix G16 | Lenovo Legion 5 | Acer Nitro V 15 |
| 3 | Acer Nitro V 15 | 21990000 | ASUS ROG Strix G16 | Acer Nitro V 15 | Acer Nitro V 15 |
| 4 | MacBook Air M2 13 inch | 24990000 | MacBook Air M2 13 inch | MacBook Air M2 13 inch | HP Pavilion 15 |
| 4 | Dell Inspiron 14 | 18490000 | MacBook Air M2 13 inch | Dell Inspiron 14 | HP Pavilion 15 |
| 4 | HP Pavilion 15 | 16990000 | MacBook Air M2 13 inch | HP Pavilion 15 | HP Pavilion 15 |

Cột `last_sai` chỉ trả về chính dòng hiện tại. Lý do: khung mặc định kết thúc ở `CURRENT ROW`, nên "dòng cuối khung" luôn là dòng đang xét. Muốn lấy dòng cuối partition, phải mở khung tới `UNBOUNDED FOLLOWING` như cột `re_nhat`. (Cách khác đơn giản hơn: `FIRST_VALUE(name) OVER (PARTITION BY category_id ORDER BY price ASC)`.)

### 9. Top-N mỗi nhóm

Đề bài kinh điển: "lấy 2 sản phẩm có doanh thu cao nhất trong **mỗi** danh mục". Phản xạ đầu tiên thường là lọc ngay trong WHERE:

```sql
SELECT name,
       category_id,
       ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price DESC) AS rn
FROM products
WHERE ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY price DESC) <= 2;
```

```text
ERROR:  window functions are not allowed in WHERE
LINE 5: WHERE ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY p...
              ^
```

WHERE chạy **trước** window function (xem thứ tự ở mục 2), nên lúc lọc thì cột `rn` chưa tồn tại. Cách làm đúng: tính số thứ tự trong một CTE (hoặc subquery trong FROM), rồi lọc ở truy vấn bên ngoài.

```sql
WITH doanh_thu_sp AS (
    SELECT p.category_id,
           p.name,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY p.product_id, p.category_id, p.name
),
xep_hang AS (
    SELECT dt.*,
           ROW_NUMBER() OVER (PARTITION BY category_id ORDER BY doanh_thu DESC, name) AS rn
    FROM doanh_thu_sp dt
)
SELECT c.name AS danh_muc,
       xh.name AS san_pham,
       xh.doanh_thu,
       xh.rn
FROM xep_hang xh
JOIN categories c ON c.category_id = xh.category_id
WHERE xh.rn <= 2
ORDER BY xh.category_id, xh.rn;
```

| danh_muc | san_pham | doanh_thu | rn |
| --- | --- | --- | --- |
| Laptop gaming | Lenovo Legion 5 | 59980000 | 1 |
| Laptop gaming | Acer Nitro V 15 | 43830500 | 2 |
| Laptop văn phòng | MacBook Air M2 13 inch | 50730500 | 1 |
| Laptop văn phòng | Dell Inspiron 14 | 36980000 | 2 |
| PC & Màn hình | Màn hình LG UltraGear 27 inch | 19470000 | 1 |
| PC & Màn hình | Màn hình Dell P2422H | 12870000 | 2 |
| Điện thoại | iPhone 15 128GB | 78960500 | 1 |
| Điện thoại | Samsung Galaxy S24 | 36081000 | 2 |
| ... | ... | ... | ... |

(... tổng 16 dòng, 2 dòng cho mỗi danh mục có bán hàng.)

Chọn hàm nào cho top-N?

- `ROW_NUMBER()`: luôn đúng N dòng mỗi nhóm, dòng bằng điểm bị cắt theo cột phụ.
- `RANK()` hoặc `DENSE_RANK()`: giữ mọi dòng đồng hạng, nên một nhóm có thể ra nhiều hơn N dòng. Bài tập 7 dùng cách này.

> **Ghi chú dialect:** Snowflake, BigQuery và DuckDB có mệnh đề `QUALIFY` để lọc kết quả window function mà không cần CTE. PostgreSQL, MySQL và SQL Server không có `QUALIFY`, nên dùng CTE như trên.

### 10. Window trên kết quả GROUP BY và mệnh đề WINDOW

Vì window function chạy sau GROUP BY, nó có thể bọc ngoài một hàm tổng hợp. Mệnh đề `WINDOW` đặt tên cho một định nghĩa cửa sổ để dùng lại nhiều lần:

```sql
SELECT p.category_id,
       COUNT(*) AS so_sp,
       SUM(COUNT(*)) OVER () AS tong_sp,
       RANK() OVER w AS hang
FROM products p
GROUP BY p.category_id
WINDOW w AS (ORDER BY COUNT(*) DESC)
ORDER BY hang, p.category_id;
```

| category_id | so_sp | tong_sp | hang |
| --- | --- | --- | --- |
| 7 | 4 | 24 | 1 |
| 10 | 4 | 24 | 1 |
| 3 | 3 | 24 | 3 |
| 4 | 3 | 24 | 3 |
| 5 | 3 | 24 | 3 |
| 11 | 3 | 24 | 3 |
| 8 | 2 | 24 | 7 |
| 12 | 2 | 24 | 7 |

`SUM(COUNT(*)) OVER ()` đọc từ trong ra ngoài: `COUNT(*)` đếm sản phẩm mỗi danh mục (GROUP BY), rồi `SUM(...) OVER ()` cộng các số đếm đó trên toàn bộ kết quả.

---

## Phần B. CTE đệ quy

### 11. Ý tưởng: phần neo, phần đệ quy, điều kiện dừng

CTE thường (Ngày 11) là một truy vấn có tên. CTE đệ quy là một CTE **tham chiếu tới chính nó**, gồm ba phần:

```text
WITH RECURSIVE ten_cte AS (
    <phần neo (anchor)>             -- chạy 1 lần, tạo các dòng xuất phát
    UNION ALL
    <phần đệ quy>                   -- có FROM/JOIN ten_cte, chạy lặp lại
)
SELECT ... FROM ten_cte;
```

Cách PostgreSQL thực thi:

1. Chạy phần neo, đưa kết quả vào kết quả cuối **và** vào một "bảng tạm" (working table).
2. Chạy phần đệ quy, trong đó `ten_cte` chỉ là **các dòng của bảng tạm** (các dòng vòng trước vừa sinh ra), không phải toàn bộ kết quả.
3. Dòng mới sinh ra được cộng vào kết quả cuối và trở thành bảng tạm của vòng sau.
4. Lặp lại bước 2-3 cho tới khi một vòng **không sinh thêm dòng nào**.

Ví dụ nhỏ nhất, đếm từ 1 đến 5:

```sql
WITH RECURSIVE dem AS (
    SELECT 1 AS n                -- phần neo (anchor)
    UNION ALL
    SELECT n + 1 FROM dem        -- phần đệ quy
    WHERE n < 5                  -- điều kiện dừng
)
SELECT n FROM dem;
```

| n |
| --- |
| 1 |
| 2 |
| 3 |
| 4 |
| 5 |

Vòng có `n = 5` không thỏa `n < 5` nên không sinh dòng mới, và đệ quy dừng. Bỏ điều kiện dừng đi là truy vấn chạy mãi.

### 12. Duyệt cây danh mục `categories`

Bảng `categories` là cây: `parent_id` trỏ về danh mục cha, danh mục gốc có `parent_id IS NULL`. Liệt kê toàn bộ cây kèm cấp và đường dẫn:

```sql
WITH RECURSIVE cay AS (
    SELECT category_id,
           name,
           parent_id,
           1 AS cap,
           name::text AS duong_dan
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.category_id,
           c.name,
           c.parent_id,
           cay.cap + 1,
           cay.duong_dan || ' > ' || c.name
    FROM categories c
    JOIN cay ON c.parent_id = cay.category_id
)
SELECT category_id, cap, duong_dan
FROM cay
ORDER BY duong_dan;
```

| category_id | cap | duong_dan |
| --- | --- | --- |
| 6 | 1 | Điện thoại & Tablet |
| 7 | 2 | Điện thoại & Tablet > Điện thoại |
| 8 | 2 | Điện thoại & Tablet > Máy tính bảng |
| 1 | 1 | Máy tính |
| 2 | 2 | Máy tính > Laptop |
| 3 | 3 | Máy tính > Laptop > Laptop gaming |
| 4 | 3 | Máy tính > Laptop > Laptop văn phòng |
| 5 | 2 | Máy tính > PC & Màn hình |
| 9 | 1 | Phụ kiện |
| 10 | 2 | Phụ kiện > Chuột & Bàn phím |
| 12 | 2 | Phụ kiện > Sạc & Cáp |
| 11 | 2 | Phụ kiện > Tai nghe & Loa |
| 13 | 1 | Thiết bị mạng |

Đọc điều kiện JOIN `c.parent_id = cay.category_id` là: "tìm các danh mục **có cha** là một dòng vừa tìm được". Đó là chiều đi **xuống** cây. Sắp xếp theo `duong_dan` giúp con đứng ngay dưới cha.

`name::text` ở phần neo là bắt buộc: cột `name` có kiểu `VARCHAR(100)`, còn phép nối `||` ở phần đệ quy trả về kiểu khác. Thiếu ép kiểu sẽ báo lỗi (xem mục Lỗi thường gặp).

Sơ đồ dưới đây cho thấy truy vấn trên chạy qua từng vòng:

![CTE đệ quy duyệt cây categories theo từng vòng. Mỗi vòng chỉ JOIN với các dòng vòng ngay trước vừa sinh ra. Vòng 0 là phần neo, điều kiện parent_id IS NULL, cho 4 dòng mới: Máy tính, Điện thoại & Tablet, Phụ kiện, Thiết bị mạng. Vòng 1 là phần đệ quy, lấy con của vòng 0, cho 7 dòng mới: Laptop, PC & Màn hình, Điện thoại, Máy tính bảng, Chuột & Bàn phím, Tai nghe & Loa, Sạc & Cáp. Vòng 2 lấy con của vòng 1, cho 2 dòng mới: Laptop gaming, Laptop văn phòng. Vòng 3 lấy con của vòng 2 nhưng không danh mục nào có parent_id là 3 hoặc 4, bảng tạm rỗng nên đệ quy dừng. UNION ALL gom kết quả mọi vòng: 4 + 7 + 2 = 13 dòng, đủ 13 danh mục. Dữ liệu có vòng lặp thì bảng tạm không bao giờ rỗng, phải chặn.](img/cte-de-quy-tung-vong.png#gh-light-mode-only)
![CTE đệ quy duyệt cây categories theo từng vòng. Mỗi vòng chỉ JOIN với các dòng vòng ngay trước vừa sinh ra. Vòng 0 là phần neo, điều kiện parent_id IS NULL, cho 4 dòng mới: Máy tính, Điện thoại & Tablet, Phụ kiện, Thiết bị mạng. Vòng 1 là phần đệ quy, lấy con của vòng 0, cho 7 dòng mới: Laptop, PC & Màn hình, Điện thoại, Máy tính bảng, Chuột & Bàn phím, Tai nghe & Loa, Sạc & Cáp. Vòng 2 lấy con của vòng 1, cho 2 dòng mới: Laptop gaming, Laptop văn phòng. Vòng 3 lấy con của vòng 2 nhưng không danh mục nào có parent_id là 3 hoặc 4, bảng tạm rỗng nên đệ quy dừng. UNION ALL gom kết quả mọi vòng: 4 + 7 + 2 = 13 dòng, đủ 13 danh mục. Dữ liệu có vòng lặp thì bảng tạm không bao giờ rỗng, phải chặn.](img/cte-de-quy-tung-vong-dark.png#gh-dark-mode-only)

<small>File gốc: [nền sáng](../diagrams/recursive-queries-window-functions/cte-de-quy-tung-vong.html) · [nền tối](../diagrams/recursive-queries-window-functions/cte-de-quy-tung-vong-dark.html)</small>

Bạn có thể tự kiểm chứng số dòng mỗi vòng bằng cách thêm cột đếm vòng rồi GROUP BY:

```sql
WITH RECURSIVE cay AS (
    SELECT category_id, name, 0 AS vong
    FROM categories
    WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, c.name, cay.vong + 1
    FROM categories c
    JOIN cay ON c.parent_id = cay.category_id
)
SELECT vong, COUNT(*) AS so_dong, string_agg(name, ', ' ORDER BY category_id) AS cac_danh_muc
FROM cay
GROUP BY vong
ORDER BY vong;
```

| vong | so_dong | cac_danh_muc |
| --- | --- | --- |
| 0 | 4 | Máy tính, Điện thoại & Tablet, Phụ kiện, Thiết bị mạng |
| 1 | 7 | Laptop, PC & Màn hình, Điện thoại, Máy tính bảng, Chuột & Bàn phím, Tai nghe & Loa, Sạc & Cáp |
| 2 | 2 | Laptop gaming, Laptop văn phòng |

(`string_agg` nối các giá trị trong nhóm thành một chuỗi, ở đây chỉ để in gọn.)

**Lấy một cây con.** Đổi phần neo là có thể bắt đầu từ bất kỳ nút nào. Mọi danh mục thuộc nhánh "Máy tính" và số sản phẩm của từng danh mục:

```sql
WITH RECURSIVE cay_con AS (
    SELECT category_id, name
    FROM categories
    WHERE name = 'Máy tính'

    UNION ALL

    SELECT c.category_id, c.name
    FROM categories c
    JOIN cay_con cc ON c.parent_id = cc.category_id
)
SELECT cc.name AS danh_muc,
       COUNT(p.product_id) AS so_san_pham
FROM cay_con cc
LEFT JOIN products p ON p.category_id = cc.category_id
GROUP BY cc.category_id, cc.name
ORDER BY cc.category_id;
```

| danh_muc | so_san_pham |
| --- | --- |
| Máy tính | 0 |
| Laptop | 0 |
| Laptop gaming | 3 |
| Laptop văn phòng | 3 |
| PC & Màn hình | 3 |

Sản phẩm chỉ gắn vào danh mục lá, nên "Máy tính" và "Laptop" có 0 sản phẩm trực tiếp. Muốn biết nhánh "Máy tính" có bao nhiêu sản phẩm thì cộng cả cây con: 9. Đây là việc mà một JOIN cố định số cấp không làm được khi cây có thể sâu thêm.

### 13. Cây nhân viên: sơ đồ tổ chức và chuỗi quản lý

Ở Ngày 10 bạn dùng SELF JOIN để ghép nhân viên với quản lý **trực tiếp**. Muốn đi hết mọi cấp, cần đệ quy. Sơ đồ tổ chức, thụt lề theo cấp:

```sql
WITH RECURSIVE so_do AS (
    SELECT employee_id,
           full_name,
           title,
           1 AS cap,
           full_name::text AS chuoi_quan_ly
    FROM employees
    WHERE manager_id IS NULL

    UNION ALL

    SELECT e.employee_id,
           e.full_name,
           e.title,
           sd.cap + 1,
           sd.chuoi_quan_ly || ' > ' || e.full_name
    FROM employees e
    JOIN so_do sd ON e.manager_id = sd.employee_id
)
SELECT employee_id,
       repeat('    ', cap - 1) || full_name AS so_do_to_chuc,
       title,
       cap
FROM so_do
ORDER BY chuoi_quan_ly;
```

| employee_id | so_do_to_chuc | title | cap |
| --- | --- | --- | --- |
| 1 | Nguyễn Thành Long | Giám đốc | 1 |
| 2 | &nbsp;&nbsp;&nbsp;&nbsp;Lê Thị Hạnh | Trưởng phòng Kinh doanh | 2 |
| 5 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Đỗ Minh Tuấn | Nhân viên bán hàng | 3 |
| 4 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Phạm Thị Thu | Nhân viên bán hàng | 3 |
| 8 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Kiều Anh Thư | Thực tập sinh bán hàng | 4 |
| 6 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Vũ Hoài Nam | Nhân viên bán hàng | 3 |
| 3 | &nbsp;&nbsp;&nbsp;&nbsp;Trần Quốc Bảo | Trưởng phòng Kỹ thuật | 2 |
| 7 | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Lâm Gia Huy | Kỹ thuật viên | 3 |

`repeat('    ', cap - 1)` thêm 4 dấu cách cho mỗi cấp, để kết quả trong psql trông như cây. Thứ tự giữa các anh chị em (Đỗ Minh Tuấn trước Phạm Thị Thu) đi theo quy tắc so sánh chuỗi (collation) của database.

**Đi ngược lên cây.** Chuỗi quản lý của thực tập sinh Kiều Anh Thư, từ bạn ấy lên tới giám đốc. Chỉ cần đảo chiều JOIN: tìm nhân viên **là quản lý** của dòng vừa tìm được.

```sql
WITH RECURSIVE cap_tren AS (
    SELECT employee_id, full_name, title, manager_id, 0 AS buoc
    FROM employees
    WHERE full_name = 'Kiều Anh Thư'

    UNION ALL

    SELECT e.employee_id, e.full_name, e.title, e.manager_id, ct.buoc + 1
    FROM employees e
    JOIN cap_tren ct ON e.employee_id = ct.manager_id
)
SELECT buoc, full_name, title
FROM cap_tren
ORDER BY buoc;
```

| buoc | full_name | title |
| --- | --- | --- |
| 0 | Kiều Anh Thư | Thực tập sinh bán hàng |
| 1 | Phạm Thị Thu | Nhân viên bán hàng |
| 2 | Lê Thị Hạnh | Trưởng phòng Kinh doanh |
| 3 | Nguyễn Thành Long | Giám đốc |

Đệ quy dừng ở giám đốc vì `manager_id` của ông là NULL, và `e.employee_id = NULL` không khớp dòng nào.

| Muốn | Điều kiện JOIN trong phần đệ quy |
| --- | --- |
| Đi xuống (tìm con, cấp dưới) | `bang.parent_id = cte.id` |
| Đi lên (tìm cha, cấp trên) | `bang.id = cte.parent_id` |

### 14. Chống vòng lặp vô hạn

Cây "đúng nghĩa" không có vòng. Nhưng dữ liệu thật có thể bị nhập sai: A là cha của B, B là cha của A. Đồ thị như mạng lưới đường đi, quan hệ bạn bè thì có vòng là chuyện bình thường. Khi đó bảng tạm không bao giờ rỗng và truy vấn chạy mãi.

Tạo một bản sao `categories` rồi cố tình tạo vòng (không đụng vào bảng gốc của shop):

```sql
DROP TABLE IF EXISTS category_cycle_demo;
CREATE TABLE category_cycle_demo AS
SELECT category_id, name, parent_id FROM categories;
-- Cố tình tạo vòng: "Máy tính" nhận "Laptop gaming" làm cha
UPDATE category_cycle_demo SET parent_id = 3 WHERE category_id = 1;
SELECT * FROM category_cycle_demo WHERE category_id IN (1, 2, 3) ORDER BY category_id;
```

| category_id | name | parent_id |
| --- | --- | --- |
| 1 | Máy tính | 3 |
| 2 | Laptop | 1 |
| 3 | Laptop gaming | 2 |

Giờ Máy tính → Laptop → Laptop gaming → Máy tính → ... Chạy truy vấn duyệt cây thông thường, có đặt giới hạn thời gian 2 giây để không treo máy:

```sql
SET statement_timeout = '2s';
WITH RECURSIVE cay AS (
    SELECT category_id, name, 1 AS cap
    FROM category_cycle_demo
    WHERE category_id = 1
    UNION ALL
    SELECT c.category_id, c.name, cay.cap + 1
    FROM category_cycle_demo c
    JOIN cay ON c.parent_id = cay.category_id
)
SELECT COUNT(*) FROM cay;
```

```text
ERROR:  canceling statement due to statement timeout
```

Không có timeout thì truy vấn chạy tới khi bạn tự hủy (Ctrl+C trong psql) hoặc hết bộ nhớ. Nhớ trả lại thiết lập: `RESET statement_timeout;`.

Có ba cách chặn, nên dùng ít nhất một:

**Cách 1: giới hạn độ sâu.** Đơn giản, nhưng chỉ là "phanh khẩn cấp": vẫn sinh ra dòng lặp cho tới khi chạm giới hạn.

```sql
WITH RECURSIVE cay AS (
    SELECT category_id, name, 1 AS cap
    FROM category_cycle_demo
    WHERE category_id = 1
    UNION ALL
    SELECT c.category_id, c.name, cay.cap + 1
    FROM category_cycle_demo c
    JOIN cay ON c.parent_id = cay.category_id
    WHERE cay.cap < 6
)
SELECT cap, COUNT(*) AS so_dong
FROM cay
GROUP BY cap
ORDER BY cap;
```

| cap | so_dong |
| --- | --- |
| 1 | 1 |
| 2 | 2 |
| 3 | 2 |
| 4 | 1 |
| 5 | 2 |
| 6 | 2 |

Truy vấn dừng, nhưng cấp 4-6 là các dòng lặp lại (Máy tính xuất hiện lần nữa ở cấp 4).

**Cách 2: lưu mảng đường đi.** Mỗi dòng mang theo mảng các id đã đi qua. Gặp lại id cũ thì đánh dấu và không đi tiếp. Cách này chạy được trên mọi phiên bản PostgreSQL.

```sql
WITH RECURSIVE cay AS (
    SELECT category_id, name, 1 AS cap,
           ARRAY[category_id] AS da_di_qua,
           FALSE AS gap_vong
    FROM category_cycle_demo
    WHERE category_id = 1

    UNION ALL

    SELECT c.category_id, c.name, cay.cap + 1,
           cay.da_di_qua || c.category_id,
           c.category_id = ANY(cay.da_di_qua)
    FROM category_cycle_demo c
    JOIN cay ON c.parent_id = cay.category_id
    WHERE NOT cay.gap_vong
)
SELECT category_id, name, cap, da_di_qua, gap_vong
FROM cay
ORDER BY da_di_qua;
```

| category_id | name | cap | da_di_qua | gap_vong |
| --- | --- | --- | --- | --- |
| 1 | Máy tính | 1 | {1} | f |
| 2 | Laptop | 2 | {1,2} | f |
| 3 | Laptop gaming | 3 | {1,2,3} | f |
| 1 | Máy tính | 4 | {1,2,3,1} | t |
| 4 | Laptop văn phòng | 3 | {1,2,4} | f |
| 5 | PC & Màn hình | 2 | {1,5} | f |

`ARRAY[...]` tạo mảng, `||` nối thêm phần tử, `x = ANY(mang)` kiểm tra x có trong mảng không. Dòng có `gap_vong = t` chỉ ra chính xác chỗ vòng khép lại: đường đi `{1,2,3,1}`. Đây cũng là cách tìm dữ liệu nhập sai.

**Cách 3: mệnh đề CYCLE (PostgreSQL 14 trở lên).** PostgreSQL tự làm việc của cách 2:

```sql
WITH RECURSIVE cay AS (
    SELECT category_id, name, 1 AS cap
    FROM category_cycle_demo
    WHERE category_id = 1

    UNION ALL

    SELECT c.category_id, c.name, cay.cap + 1
    FROM category_cycle_demo c
    JOIN cay ON c.parent_id = cay.category_id
) CYCLE category_id SET gap_vong USING duong_di
SELECT category_id, name, cap, gap_vong, duong_di
FROM cay
ORDER BY cap, category_id;
```

| category_id | name | cap | gap_vong | duong_di |
| --- | --- | --- | --- | --- |
| 1 | Máy tính | 1 | f | {(1)} |
| 2 | Laptop | 2 | f | {(1),(2)} |
| 5 | PC & Màn hình | 2 | f | {(1),(5)} |
| 3 | Laptop gaming | 3 | f | {(1),(2),(3)} |
| 4 | Laptop văn phòng | 3 | f | {(1),(2),(4)} |
| 1 | Máy tính | 4 | t | {(1),(2),(3),(1)} |

`CYCLE category_id` nghĩa là "coi như gặp vòng khi `category_id` lặp lại trên đường đi". PostgreSQL thêm hai cột: `gap_vong` (đã gặp vòng chưa) và `duong_di` (mảng đường đi), và tự dừng nhánh khi gặp vòng.

Dọn bảng demo:

```sql
DROP TABLE category_cycle_demo;
```

Về `UNION` thay cho `UNION ALL`: `UNION` loại dòng trùng nên đôi khi chặn được vòng, nhưng chỉ khi **cả dòng** trùng hệt. Chỉ cần có cột `cap` hay `duong_dan` thay đổi mỗi vòng là không dòng nào trùng, và vòng lặp vẫn chạy mãi. Đừng dựa vào nó.

> **Ghi chú dialect:** MySQL (từ 8.0) và SQLite cũng viết `WITH RECURSIVE`; MySQL dừng với lỗi khi vượt `cte_max_recursion_depth` (mặc định 1000). SQL Server viết `WITH` **không có** chữ `RECURSIVE`, mặc định báo lỗi khi đệ quy quá 100 cấp (đổi bằng `OPTION (MAXRECURSION n)` ở cuối câu), dùng `+` để nối chuỗi và đòi kiểu dữ liệu của phần neo và phần đệ quy khớp nhau (thường phải `CAST(name AS VARCHAR(MAX))`). SQL Server dùng `TOP n` thay cho `LIMIT n`.

---

## Lỗi thường gặp

**1. Dùng window function trong WHERE.** Báo lỗi `window functions are not allowed in WHERE` (mục 9). Tính trong CTE rồi lọc ở ngoài.

**2. Quên PARTITION BY nên lũy kế "chảy" sang nhóm khác.**

```sql
WITH order_totals AS (
    SELECT o.order_id,
           o.customer_id,
           o.order_date::date AS ngay,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS tong_tien
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY o.order_id
)
SELECT customer_id,
       order_id,
       ngay,
       tong_tien,
       SUM(tong_tien) OVER (ORDER BY ngay) AS luy_ke_sai
FROM order_totals
WHERE customer_id IN (1, 2)
ORDER BY ngay;
```

| customer_id | order_id | ngay | tong_tien | luy_ke_sai |
| --- | --- | --- | --- | --- |
| 1 | 1 | 2025-01-12 | 699000 | 699000 |
| 2 | 2 | 2025-01-20 | 26990000 | 27689000 |
| 1 | 4 | 2025-02-14 | 7881000 | 35570000 |
| ... | ... | ... | ... | ... |
| 1 | 37 | 2026-09-02 | 9640000 | 103692500 |

Đây là lũy kế chung của hai khách, không phải của từng khách. Cách đúng: `OVER (PARTITION BY customer_id ORDER BY ngay)` như mục 4.

**3. Lũy kế theo khung mặc định khi ORDER BY có giá trị trùng.** Hai đơn cùng ngày nhận cùng một số lũy kế (mục 5). Ghi rõ `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` và thêm cột phụ vào ORDER BY.

**4. `LAST_VALUE` trả về chính dòng hiện tại.** Do khung mặc định dừng ở CURRENT ROW (mục 8). Mở khung tới `UNBOUNDED FOLLOWING` hoặc dùng `FIRST_VALUE` với thứ tự ngược.

**5. `ROW_NUMBER` cho kết quả khác nhau giữa các lần chạy.** Khi ORDER BY có giá trị bằng nhau, thứ tự giữa chúng không xác định. Luôn thêm cột phụ duy nhất (id, tên) vào cuối ORDER BY.

**6. Kiểu dữ liệu phần neo và phần đệ quy không khớp.**

```sql
WITH RECURSIVE cay AS (
    SELECT category_id, name AS duong_dan
    FROM categories
    WHERE parent_id IS NULL
    UNION ALL
    SELECT c.category_id, cay.duong_dan || ' > ' || c.name
    FROM categories c
    JOIN cay ON c.parent_id = cay.category_id
)
SELECT * FROM cay;
```

```text
ERROR:  recursive query "cay" column 2 has type character varying(100) in non-recursive term but type character varying overall
LINE 2:     SELECT category_id, name AS duong_dan
                                ^
HINT:  Cast the output of the non-recursive term to the correct type.
```

Sửa: ép kiểu ở phần neo, `name::text AS duong_dan`.

**7. JOIN sai chiều trong phần đệ quy.** Muốn lấy các danh mục con của "Máy tính" nhưng viết `c.category_id = cc.parent_id` (đi lên):

```sql
WITH RECURSIVE cay_con AS (
    SELECT category_id, name, parent_id FROM categories WHERE name = 'Máy tính'
    UNION ALL
    SELECT c.category_id, c.name, c.parent_id
    FROM categories c
    JOIN cay_con cc ON c.category_id = cc.parent_id
)
SELECT category_id, name FROM cay_con;
```

| category_id | name |
| --- | --- |
| 1 | Máy tính |

Chỉ ra đúng một dòng vì "Máy tính" là gốc, không có cha. Không báo lỗi, nên rất dễ bỏ qua. Đối chiếu với bảng chiều JOIN ở mục 13.

**8. Không có điều kiện dừng hoặc không chống vòng lặp.** Với dữ liệu có thể có vòng (đồ thị, dữ liệu nhập tay), luôn dùng mảng đường đi hoặc `CYCLE`, và đặt `statement_timeout` khi thử nghiệm (mục 14).

---

## Bài tập

Các bài chỉ đọc dữ liệu, không cần khôi phục database sau khi làm.

### Cơ bản

**Bài 1.** Với mỗi đơn đã thanh toán của khách 2 và khách 4, cho biết đó là đơn thứ mấy của khách (theo thời gian đặt).

<details>
<summary>Đáp án</summary>

```sql
SELECT customer_id,
       order_id,
       order_date::date AS ngay,
       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS don_thu
FROM orders
WHERE status NOT IN ('pending', 'cancelled')
  AND customer_id IN (2, 4)
ORDER BY customer_id, don_thu;
```

Kết quả:

| customer_id | order_id | ngay | don_thu |
| --- | --- | --- | --- |
| 2 | 2 | 2025-01-20 | 1 |
| 2 | 8 | 2025-04-22 | 2 |
| 2 | 22 | 2025-11-11 | 3 |
| 2 | 34 | 2026-06-15 | 4 |
| 4 | 16 | 2025-08-16 | 1 |
| 4 | 31 | 2026-04-01 | 2 |

Đơn 5 của khách 4 bị hủy nên không được đánh số.
</details>

**Bài 2.** Xếp hạng giá sản phẩm (đắt nhất là hạng 1) trong từng danh mục con của "Phụ kiện" (các danh mục có `parent_id = 9`), dùng `DENSE_RANK`.

<details>
<summary>Đáp án</summary>

```sql
SELECT c.name AS danh_muc,
       p.name AS san_pham,
       p.price,
       DENSE_RANK() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS hang_gia
FROM products p
JOIN categories c ON c.category_id = p.category_id
WHERE c.parent_id = 9
ORDER BY p.category_id, hang_gia;
```

Kết quả:

| danh_muc | san_pham | price | hang_gia |
| --- | --- | --- | --- |
| Chuột & Bàn phím | Chuột Logitech MX Master 3S | 2490000 | 1 |
| Chuột & Bàn phím | Bàn phím cơ Keychron K2 | 1890000 | 2 |
| Chuột & Bàn phím | Chuột Logitech G102 | 399000 | 3 |
| Chuột & Bàn phím | Lót chuột DSC XXL | 250000 | 4 |
| Tai nghe & Loa | Tai nghe Sony WH-1000XM5 | 7990000 | 1 |
| Tai nghe & Loa | Tai nghe AirPods Pro 2 | 5990000 | 2 |
| Tai nghe & Loa | Loa JBL Flip 6 | 2690000 | 3 |
| Sạc & Cáp | Sạc Anker 65W | 890000 | 1 |
| Sạc & Cáp | Cáp USB-C to USB-C 1m | 150000 | 2 |
</details>

**Bài 3.** Liệt kê mọi cấp dưới (trực tiếp và gián tiếp) của Lê Thị Hạnh, kèm khoảng cách cấp so với chị (1 = cấp dưới trực tiếp).

<details>
<summary>Đáp án</summary>

```sql
WITH RECURSIVE cap_duoi AS (
    SELECT employee_id, full_name, title, 0 AS cap
    FROM employees
    WHERE full_name = 'Lê Thị Hạnh'

    UNION ALL

    SELECT e.employee_id, e.full_name, e.title, cd.cap + 1
    FROM employees e
    JOIN cap_duoi cd ON e.manager_id = cd.employee_id
)
SELECT employee_id, full_name, title, cap
FROM cap_duoi
WHERE cap > 0
ORDER BY cap, employee_id;
```

Kết quả:

| employee_id | full_name | title | cap |
| --- | --- | --- | --- |
| 4 | Phạm Thị Thu | Nhân viên bán hàng | 1 |
| 5 | Đỗ Minh Tuấn | Nhân viên bán hàng | 1 |
| 6 | Vũ Hoài Nam | Nhân viên bán hàng | 1 |
| 8 | Kiều Anh Thư | Thực tập sinh bán hàng | 2 |

`WHERE cap > 0` bỏ dòng của chính Lê Thị Hạnh (dòng neo).
</details>

### Vận dụng

**Bài 4.** Doanh thu từng tháng trong toàn bộ dữ liệu (01/2025 đến 10/2026), kèm lũy kế **từ đầu mỗi năm** (sang năm mới thì lũy kế bắt đầu lại).

<details>
<summary>Đáp án</summary>

```sql
WITH doanh_thu_thang AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS thang,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY DATE_TRUNC('month', o.order_date)
)
SELECT to_char(thang, 'YYYY-MM') AS thang,
       doanh_thu,
       SUM(doanh_thu) OVER (PARTITION BY EXTRACT(YEAR FROM thang)
                            ORDER BY thang) AS luy_ke_trong_nam
FROM doanh_thu_thang
ORDER BY thang;
```

Kết quả:

| thang | doanh_thu | luy_ke_trong_nam |
| --- | --- | --- |
| 2025-01 | 27689000 | 27689000 |
| 2025-02 | 13661000 | 41350000 |
| ... | ... | ... |
| 2025-11 | 40762500 | 276469500 |
| 2025-12 | 49661000 | 326130500 |
| 2026-01 | 34030500 | 34030500 |
| 2026-02 | 11560000 | 45590500 |
| ... | ... | ... |
| 2026-10 | 39980000 | 210160500 |

(... tổng 22 dòng.) Chìa khóa là `PARTITION BY EXTRACT(YEAR FROM thang)`: mỗi năm là một partition riêng.
</details>

**Bài 5.** Với mỗi khách đã mua từ 2 đơn trở lên, tìm khoảng cách ngắn nhất (số ngày) giữa hai đơn liên tiếp. In 3 khách quay lại nhanh nhất.

<details>
<summary>Đáp án</summary>

```sql
WITH khoang_cach AS (
    SELECT customer_id,
           order_date::date - LAG(order_date::date)
               OVER (PARTITION BY customer_id ORDER BY order_date) AS so_ngay
    FROM orders
    WHERE status NOT IN ('pending', 'cancelled')
)
SELECT kc.customer_id,
       c.full_name,
       MIN(kc.so_ngay) AS nhanh_nhat
FROM khoang_cach kc
JOIN customers c ON c.customer_id = kc.customer_id
WHERE kc.so_ngay IS NOT NULL
GROUP BY kc.customer_id, c.full_name
ORDER BY nhanh_nhat, kc.customer_id
LIMIT 3;
```

Kết quả:

| customer_id | full_name | nhanh_nhat |
| --- | --- | --- |
| 1 | Nguyễn Văn An | 33 |
| 2 | Trần Thị Bình | 92 |
| 6 | Võ Quốc Phong | 154 |

Đơn đầu tiên của mỗi khách có `so_ngay` là NULL, nên `WHERE kc.so_ngay IS NOT NULL` cũng tự loại khách chỉ có một đơn. Lưu ý: lọc NULL phải làm ở truy vấn ngoài, sau khi `LAG` đã tính xong.
</details>

**Bài 6.** Doanh số bán hàng offline của từng nhân viên (đơn có `employee_id`), tỷ trọng trên tổng doanh số offline và thứ hạng.

<details>
<summary>Đáp án</summary>

```sql
WITH doanh_so AS (
    SELECT e.full_name,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_so
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN employees e    ON e.employee_id = o.employee_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY e.employee_id, e.full_name
)
SELECT full_name,
       doanh_so,
       ROUND(100.0 * doanh_so / SUM(doanh_so) OVER (), 1) AS pct,
       RANK() OVER (ORDER BY doanh_so DESC) AS hang
FROM doanh_so
ORDER BY hang;
```

Kết quả:

| full_name | doanh_so | pct | hang |
| --- | --- | --- | --- |
| Vũ Hoài Nam | 82907500 | 39.2 | 1 |
| Phạm Thị Thu | 63700000 | 30.1 | 2 |
| Đỗ Minh Tuấn | 63401000 | 30.0 | 3 |
| Kiều Anh Thư | 1640000 | 0.8 | 4 |
</details>

**Bài 7.** Mỗi năm, tìm 2 tháng có doanh thu cao nhất. Nếu có tháng đồng hạng thì giữ cả hai.

<details>
<summary>Đáp án</summary>

```sql
WITH doanh_thu_thang AS (
    SELECT DATE_TRUNC('month', o.order_date)::date AS thang,
           ROUND(SUM(oi.quantity * oi.unit_price * (1 - oi.discount))) AS doanh_thu
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
    GROUP BY DATE_TRUNC('month', o.order_date)
),
xep_hang AS (
    SELECT thang,
           doanh_thu,
           RANK() OVER (PARTITION BY EXTRACT(YEAR FROM thang)
                        ORDER BY doanh_thu DESC) AS hang
    FROM doanh_thu_thang
)
SELECT EXTRACT(YEAR FROM thang) AS nam,
       to_char(thang, 'YYYY-MM') AS thang,
       doanh_thu,
       hang
FROM xep_hang
WHERE hang <= 2
ORDER BY nam, hang;
```

Kết quả:

| nam | thang | doanh_thu | hang |
| --- | --- | --- | --- |
| 2025 | 2025-06 | 50769000 | 1 |
| 2025 | 2025-12 | 49661000 | 2 |
| 2026 | 2026-10 | 39980000 | 1 |
| 2026 | 2026-01 | 34030500 | 2 |

Dùng `RANK` thay vì `ROW_NUMBER` để tháng đồng hạng không bị cắt mất. Năm 2026 mới có dữ liệu tới tháng 10.
</details>

### Thử thách

**Bài 8.** Tính doanh thu theo **danh mục gốc** (cấp 1), gộp từ toàn bộ cây con của nó, kèm tỷ trọng. Danh mục gốc chưa bán được gì vẫn phải hiện với doanh thu 0.

<details>
<summary>Đáp án</summary>

Ý tưởng: CTE đệ quy gắn mỗi danh mục với id gốc của nó (truyền `goc_id` xuống từ phần neo), rồi LEFT JOIN với doanh thu bán hàng.

```sql
WITH RECURSIVE goc AS (
    SELECT category_id, category_id AS goc_id
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.category_id, g.goc_id
    FROM categories c
    JOIN goc g ON c.parent_id = g.category_id
),
ban_hang AS (
    SELECT oi.product_id,
           oi.quantity * oi.unit_price * (1 - oi.discount) AS tien
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.status NOT IN ('pending', 'cancelled')
),
doanh_thu_goc AS (
    SELECT g.goc_id,
           COALESCE(ROUND(SUM(bh.tien)), 0) AS doanh_thu
    FROM goc g
    LEFT JOIN products p  ON p.category_id = g.category_id
    LEFT JOIN ban_hang bh ON bh.product_id = p.product_id
    GROUP BY g.goc_id
)
SELECT c.name AS danh_muc_goc,
       d.doanh_thu,
       ROUND(100.0 * d.doanh_thu / SUM(d.doanh_thu) OVER (), 1) AS pct
FROM doanh_thu_goc d
JOIN categories c ON c.category_id = d.goc_id
ORDER BY d.doanh_thu DESC;
```

Kết quả:

| danh_muc_goc | doanh_thu | pct |
| --- | --- | --- |
| Máy tính | 282181500 | 52.6 |
| Điện thoại & Tablet | 188452500 | 35.1 |
| Phụ kiện | 65657000 | 12.2 |
| Thiết bị mạng | 0 | 0.0 |

Tổng ba nhóm bằng 536291000, khớp với tổng doanh thu 22 tháng ở Bài 4. Lọc trạng thái đơn được đặt trong CTE `ban_hang` chứ không ở WHERE ngoài cùng, để LEFT JOIN không biến thành INNER JOIN (bẫy đã gặp ở Ngày 10).
</details>

**Bài 9.** Với mỗi nhân viên có cấp dưới, tính tổng số cấp dưới (mọi cấp) và tổng lương của cả nhóm (gồm chính người đó). Chỉ dùng **một** CTE đệ quy cho tất cả nhân viên.

<details>
<summary>Đáp án</summary>

Mẹo: phần neo lấy **mọi** nhân viên làm trưởng nhóm của chính mình, rồi đệ quy đi xuống, cột `truong_nhom` được giữ nguyên qua các vòng.

```sql
WITH RECURSIVE nhom AS (
    SELECT employee_id AS truong_nhom, employee_id, salary
    FROM employees

    UNION ALL

    SELECT n.truong_nhom, e.employee_id, e.salary
    FROM employees e
    JOIN nhom n ON e.manager_id = n.employee_id
)
SELECT e.full_name,
       COUNT(*) - 1 AS so_cap_duoi,
       SUM(n.salary) AS tong_luong_ca_nhom
FROM nhom n
JOIN employees e ON e.employee_id = n.truong_nhom
GROUP BY n.truong_nhom, e.full_name
HAVING COUNT(*) > 1
ORDER BY so_cap_duoi DESC, e.full_name;
```

Kết quả:

| full_name | so_cap_duoi | tong_luong_ca_nhom |
| --- | --- | --- |
| Nguyễn Thành Long | 7 | 151000000 |
| Lê Thị Hạnh | 4 | 66000000 |
| Phạm Thị Thu | 1 | 17000000 |
| Trần Quốc Bảo | 1 | 40000000 |

`COUNT(*) - 1` trừ chính trưởng nhóm; `HAVING COUNT(*) > 1` bỏ những người không có cấp dưới.
</details>

---

## Tóm tắt

- Window function = hàm + `OVER (...)`. Nó tính trên một cửa sổ các dòng liên quan nhưng **không gộp dòng** như GROUP BY.
- `PARTITION BY` chia nhóm, `ORDER BY` trong OVER sắp thứ tự trong nhóm, khung chọn những dòng tham gia tính cho dòng hiện tại.
- Xếp hạng: `ROW_NUMBER` (luôn khác nhau), `RANK` (đồng hạng rồi nhảy số), `DENSE_RANK` (đồng hạng, không nhảy), `NTILE(n)` (chia n nhóm). Luôn thêm cột phụ để thứ tự xác định.
- Có `ORDER BY` mà không ghi khung thì khung mặc định là `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`: các dòng trùng giá trị được tính cùng nhau. Muốn từng dòng, ghi rõ `ROWS`.
- `LAG`/`LEAD` lấy giá trị dòng trước/sau; dùng cho tăng trưởng theo tháng, khoảng cách giữa hai lần mua.
- Window function chạy sau WHERE/GROUP BY/HAVING, nên lọc theo kết quả của nó (top-N mỗi nhóm) phải qua CTE hoặc subquery.
- CTE đệ quy = phần neo + `UNION ALL` + phần đệ quy; mỗi vòng chỉ thấy các dòng vòng trước vừa sinh ra, và dừng khi một vòng không sinh dòng mới.
- Đi xuống cây: `bang.parent_id = cte.id`. Đi lên cây: `bang.id = cte.parent_id`.
- Dữ liệu có thể có vòng thì phải chặn: mảng đường đi, mệnh đề `CYCLE` (PostgreSQL 14+), hoặc tối thiểu là giới hạn độ sâu.

## Đọc thêm

- [Luỹ kế của bạn sai ngay dòng đầu: window function, RANGE và cái mặc định ít ai đọc](https://tiennhm.io.vn/blog/window-function-vs-group-by) — GROUP BY gom 200.000 dòng thành 200, window function giữ nguyên cả 200.000 mà vẫn có số tổng của nhóm.
- Tài liệu PostgreSQL: [Window Functions (tutorial)](https://www.postgresql.org/docs/16/tutorial-window.html), [Window Function Calls](https://www.postgresql.org/docs/16/sql-expressions.html#SYNTAX-WINDOW-FUNCTIONS), [WITH Queries (Common Table Expressions)](https://www.postgresql.org/docs/16/queries-with.html).

---

[⬅️ Ngày 28: Tối ưu truy vấn](28-sql-query-optimization.md) | [📚 Mục lục](../README.md) | [Ngày 30: Bảo mật cơ sở dữ liệu ➡️](30-database-security.md)
