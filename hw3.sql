--Домашнее задание №3
--1) Создайте временную таблицу high_sales_products, которая будет содержать продукты, проданные в количестве более 10 единиц за последние 7 дней. Выведите данные из таблицы high_sales_products 
--2) Создайте CTE employee_sales_stats, который посчитает общее количество продаж и среднее количество продаж для каждого сотрудника за последние 30 дней. Напишите запрос, который выводит сотрудников с количеством продаж выше среднего по компании 
--3) Используя CTE, создайте иерархическую структуру, показывающую всех сотрудников, которые подчиняются конкретному менеджеру
--4) Напишите запрос с CTE, который выведет топ-3 продукта по количеству продаж за текущий месяц и за прошлый месяц. В результатах должно быть указано, к какому месяцу относится каждая запись
--5) Создайте индекс для таблицы sales по полю employee_id и sale_date. Проверьте, как наличие индекса влияет на производительность следующего запроса, используя трассировку (EXPLAIN ANALYZE)
--6) Используя трассировку, проанализируйте запрос, который находит общее количество проданных единиц каждого продукта.


--1) Создайте временную таблицу high_sales_products, которая будет содержать продукты, проданные в количестве более
-- 10 единиц за последние 7 дней. Выведите данные из таблицы high_sales_products 

CREATE TABLE IF NOT EXISTS employees (
    employee_id SERIAL PRIMARY KEY, -- идентификатор
    name VARCHAR(50) NOT NULL, -- имя
    position VARCHAR(50) NOT NULL, -- должность,
    department VARCHAR(50) NOT NULL, -- отдел,
    salary NUMERIC(10, 2) NOT NULL, -- зарплата
    manager_id INT REFERENCES employees(employee_id) -- идентификатор руководителя
);

-- Пример данных
INSERT INTO employees (name, position, department, salary, manager_id)
VALUES
    ('Alice Johnson', 'Manager', 'Sales', 85000, NULL),
    ('Bob Smith', 'Sales Associate', 'Sales', 50000, 1),
    ('Carol Lee', 'Sales Associate', 'Sales', 48000, 1),
    ('David Brown', 'Sales Intern', 'Sales', 30000, 2),
    ('Eve Davis', 'Developer', 'IT', 75000, NULL),
    ('Frank Miller', 'Intern', 'IT', 35000, 5);

SELECT * FROM employees LIMIT 6;

CREATE TABLE IF NOT EXISTS sales(
    sale_id SERIAL PRIMARY KEY,
    employee_id INT REFERENCES employees(employee_id),
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    sale_date DATE NOT NULL
);

-- Пример данных
INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES
    (2, 1, 20, '2024-11-15'),
    (2, 2, 15, '2024-11-16'),
    (2, 1, 12, '2024-10-20'),
    (2, 5, 6, '2024-10-17'),
    (2, 4, 2, '2024-10-10'),
    (3, 1, 10, '2024-11-12'),
    (3, 3, 5, '2024-10-9'),
    (3, 4, 3, '2024-11-14'),
    (3, 5, 8, '2024-11-9'),
    (4, 2, 8, '2024-11-10'),
    (4, 6, 2, '2024-11-13');

SELECT * FROM sales LIMIT 11;


CREATE TABLE IF NOT EXISTS products (
    product_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    price NUMERIC(10, 1) NOT NULL
);

-- Пример данных
INSERT INTO products (name, price)
VALUES
    ('Audi Cabriolet', 1.5),
    ('Audi A5', 8.6),
    ('Audi Q7', 14),
    ('Audi A3', 6.8),
    ('Audi S5', 3.6),
    ('Audi V8', 0.8);

SELECT * FROM products LIMIT 6;

-- Временная таблица

CREATE TEMP TABLE high_sales_products AS
SELECT product_id, SUM(quantity) AS total_quantity
FROM sales
WHERE (date_part('day', CURRENT_DATE) - date_part('day', sale_date) <= 7) AND (date_part('month', CURRENT_DATE) = date_part('month', sale_date))
		AND (date_part('year', CURRENT_DATE) = date_part('year', sale_date))
GROUP BY product_id
HAVING SUM(quantity)> 10;

SELECT * FROM high_sales_products LIMIT 10;

DROP TABLE high_sales_products;


--2) Создайте CTE employee_sales_stats, который посчитает общее количество продаж и среднее количество продаж 
--для каждого сотрудника за последние 30 дней. 

--Напишите запрос, который выводит сотрудников с количеством продаж выше среднего по компании 

WITH employee_sales_stats AS (
    SELECT s.employee_id, AVG(s.quantity) AS avg_sales, SUM(s.quantity) AS total_sales
    FROM sales s
    WHERE sale_date >= CURRENT_DATE - INTERVAL '30 day'
    GROUP BY s.employee_id
)
SELECT employee_id, avg_sales, total_sales
FROM employee_sales_stats
WHERE avg_sales > (SELECT AVG(avg_sales) FROM employee_sales_stats);

--3) Используя CTE, создайте иерархическую структуру, показывающую всех сотрудников, которые подчиняются конкретному менеджеру

WITH employee_hierarchy AS (
    SELECT e1.name AS manager, e2.name AS employee
    FROM employees e1
    JOIN employees e2 ON e1.employee_id = e2.manager_id
)
SELECT * FROM employee_hierarchy LIMIT 10;

--4) Напишите запрос с CTE, который выведет топ-3 продукта по количеству продаж за текущий месяц и за прошлый месяц. 
--В результатах должно быть указано, к какому месяцу относится каждая запись

WITH 
top_products_current_month AS (
    SELECT s.product_id, SUM(s.quantity) AS total_quantity,
    ROW_NUMBER() OVER (ORDER BY SUM(s.quantity) DESC) AS row_num
    FROM sales s
    WHERE date_part('month', CURRENT_DATE) = date_part('month', sale_date)
    AND date_part('year', CURRENT_DATE) = date_part('year', sale_date)
    GROUP BY s.product_id
),
top_products_previous_month AS (
    SELECT s.product_id, SUM(s.quantity) AS total_quantity,
    ROW_NUMBER() OVER (ORDER BY SUM(s.quantity) DESC) AS row_num
    FROM sales s
    WHERE date_part('month', sale_date) = date_part('month', CURRENT_DATE) - 1
    GROUP BY s.product_id
)
SELECT 
 'Текущий месяц' AS month,
  product_id,
  total_quantity
FROM top_products_current_month
WHERE row_num <= 3
UNION ALL 
SELECT 
 'Прошлый месяц' AS month,
  product_id,
  total_quantity
FROM top_products_previous_month
WHERE row_num <= 3
ORDER BY month, total_quantity DESC
LIMIT 6;

--5) Создайте индекс для таблицы sales по полю employee_id и sale_date. 
--Проверьте, как наличие индекса влияет на производительность следующего запроса, используя трассировку (EXPLAIN ANALYZE)

--Без индекса
EXPLAIN ANALYZE 
SELECT * FROM sales 
WHERE employee_id = 4 AND sale_date BETWEEN '2024-11-01' AND CURRENT_DATE;

--Seq Scan on sales  (cost=0.00..1.22 rows=1 width=20) (actual time=0.007..0.008 rows=2 loops=1)
--Filter: ((sale_date >= '2024-11-01'::date) AND (employee_id = 4) AND (sale_date <= CURRENT_DATE))
--Rows Removed by Filter: 9
--Planning Time: 0.135 ms
--Execution Time: 0.017 ms

--Создадим индекс
CREATE INDEX idx_employee_id_sale_date ON sales (employee_id, sale_date);

EXPLAIN ANALYZE 
SELECT * FROM sales 
WHERE employee_id = 4 AND sale_date BETWEEN '2024-11-01' AND CURRENT_DATE;

--Seq Scan on sales  (cost=0.00..1.22 rows=1 width=20) (actual time=0.006..0.006 rows=2 loops=1)
--Filter: ((sale_date >= '2024-11-01'::date) AND (employee_id = 4) AND (sale_date <= CURRENT_DATE))
--Rows Removed by Filter: 9
--Planning Time: 0.137 ms
--Execution Time: 0.013 ms

DROP INDEX idx_employee_id_sale_date;


--Таким образом, наличие индекса уменьшает время выполнения запроса, то есть, производительность увеличивается. Но это несильно заметно на небольшом объеме данных,
-- для того, чтобы индекс значительно увеличил производительность, необходимо работать с большим объемом данных (>10000 записей, например)

--6) Используя трассировку, проанализируйте запрос, который находит общее количество проданных единиц каждого продукта.

EXPLAIN ANALYZE
SELECT product_id, SUM(quantity) AS total_sales
FROM sales
GROUP BY product_id
ORDER BY total_sales DESC
LIMIT 10;

--Limit  (cost=1.47..1.49 rows=10 width=12) (actual time=0.018..0.019 rows=6 loops=1)
--  ->  Sort  (cost=1.47..1.49 rows=11 width=12) (actual time=0.017..0.018 rows=6 loops=1)
--        Sort Key: (sum(quantity)) DESC
--        Sort Method: quicksort  Memory: 25kB
--        ->  HashAggregate  (cost=1.17..1.28 rows=11 width=12) (actual time=0.013..0.014 rows=6 loops=1)
--              Group Key: product_id
--              Batches: 1  Memory Usage: 24kB
--              ->  Seq Scan on sales  (cost=0.00..1.11 rows=11 width=8) (actual time=0.005..0.006 rows=11 loops=1)
--Planning Time: 0.054 ms
--Execution Time: 0.036 ms

--Анализ:
--1) Limit - ограничение на вывод 10 строк, actual time - время выполнения шага
--2) Sort - сорировка по столбцу (sum(quantity)) в порядке убывания, метод сортировки - быстрая сортировка (quick sort),
--выделенный объем памяти для сортировки результатов - 25 кб
--3) HashAggregate - агрегация данных по ключу product_id, количество пакетов для агрегации (Batches) = 1,
--использованное количество памяти - 24 кб
--4) Seq Scan on sales  - сканирование таблицы sales, указание времени выполнения шага
--5) Planning Time - время выполнения с учетом задержки до сервера (планируемое время выполнения запроса) = 0.054 ms
--6) Execution Time - фактическое время выполнения запроса =  0.036 ms


