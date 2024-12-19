-- КУРСОВАЯ РАБОТА ЧАСТЬ 2 --
--Временные структуры и представления, способы валидации запросов


SELECT * FROM employees LIMIT 10;

ALTER TABLE employees_books 
ADD COLUMN employee_position INTEGER;

UPDATE employees_books eb
SET employee_position = e.position
FROM employees e 
WHERE e.id = eb.employee_id;

SELECT * FROM employees_books LIMIT 50;
SELECT * FROM publisher_position LIMIT 15;
SELECT * FROM books LIMIT 15;


--1) Временная таблица ready_books которая будет содержать книги, который были отредактированы, откорректированы и получили готовый дизайн на момент проверки (прошли этапы 1, 2, 3)

CREATE TABLE IF NOT EXISTS publish_progress (
    id SERIAL PRIMARY KEY,
    book_id INTEGER REFERENCES books(id),
    step INTEGER REFERENCES publisher_position(id),
    start_date DATE NOT NULL,
    finish_date DATE NOT NULL
);

-- Пример данных
INSERT INTO publish_progress (book_id, step, start_date, finish_date)
VALUES
    (1, 1, '2024-11-13', '2024-11-19'),
    (1, 2, '2024-11-20', '2024-11-29'),
    (1, 3, '2024-11-30', '2024-12-05'),
    (2, 1, '2024-10-30', '2024-11-15'),
    (3, 1, '2024-11-10', '2024-11-20'),
    (3, 2, '2024-12-02', '2024-12-10'),
    (3, 3, '2024-12-11', '2024-12-16'),
    (4, 1, '2024-11-14', '2024-11-30'),
    (5, 1, '2024-11-09', '2024-11-15'),
    (5, 2, '2024-11-16', '2024-12-01'),
    (5, 3, '2024-12-05', '2024-12-12');

SELECT * FROM publish_progress LIMIT 50;

ALTER TABLE publish_progress
ADD COLUMN employee_id INTEGER REFERENCES employees(id);

UPDATE publish_progress pp
SET employee_id = eb.employee_id
FROM employees_books eb
WHERE pp.book_id = eb.book_id AND pp.step = eb.employee_position;

CREATE TEMP TABLE ready_books AS
SELECT book_id,  finish_date
FROM (
    SELECT book_id, finish_date,
           ROW_NUMBER() OVER (PARTITION BY book_id ORDER BY finish_date DESC) AS rn
    FROM publish_progress
) AS subquery
WHERE rn = 1
AND book_id IN (
    SELECT book_id
    FROM publish_progress
    GROUP BY book_id
    HAVING COUNT(DISTINCT step) = 3
);

SELECT * FROM ready_books LIMIT 50;
DROP TABLE ready_books;

--2) Создать CTE employee_publish_result, который посчитает сколько денег заработал каждый сотрудник за работу над книгами за ноябрь (работа оплачивается, если она была закончена в ноябре)

WITH recent_publish_progress AS (
    SELECT pp.book_id, pp.step, pp.start_date, pp.finish_date, pp.employee_id
    FROM publish_progress pp
    WHERE date_part('month', pp.finish_date) = 11 AND date_part('year', pp.finish_date) = 2024
),
employee_work AS (
    SELECT rpp.book_id, rpp.step, rpp.start_date, rpp.finish_date, rpp.employee_id, b.pages, p.price_per_page
    FROM recent_publish_progress rpp
    JOIN books b ON rpp.book_id = b.id
    JOIN publisher_position p ON p.id = rpp.step
),
employee_earnings AS (
    SELECT ew.employee_id, SUM(ew.price_per_page * ew.pages) AS total_earnings
    FROM employee_work ew
    GROUP BY employee_id
)

SELECT * FROM employee_earnings LIMIT 50;


----3) Написать запрос с CTE, в котором будет содержаться инфомация о том, сколько времени (дней) работал каждый сотрудник в декабре (при этом сб и вс не считаются, так как не являются рабочими днями) 

WITH recent_publish_progress AS (
    SELECT pp.book_id, pp.step, pp.start_date, pp.finish_date, pp.employee_id
    FROM publish_progress pp
    WHERE date_part('month', pp.finish_date) = 12 AND date_part('year', pp.finish_date) = 2024
),
employee_work AS (
    SELECT rpp.employee_id, rpp.book_id, rpp.step, rpp.start_date, rpp.finish_date,
           CASE
               WHEN rpp.start_date < '2024-12-01' AND rpp.finish_date >= '2024-12-01' THEN (rpp.finish_date - '2024-12-01' + 1)
               ELSE (rpp.finish_date - rpp.start_date + 1)
           END AS work_days
    FROM recent_publish_progress rpp
),
working_days AS (
    SELECT ew.employee_id, ew.book_id, ew.step, ew.start_date, ew.finish_date,
           (SELECT COUNT(*) AS work_days
            FROM generate_series(
                GREATEST(ew.start_date, '2024-12-01'), 
                ew.finish_date, 
                '1 day'::INTERVAL
            ) AS day
            WHERE EXTRACT(DOW FROM day) != 6 AND EXTRACT(DOW FROM day) != 0
           ) AS actual_work_days
    FROM employee_work ew
),
employee_work_summary AS (
    SELECT wd.employee_id, SUM(wd.actual_work_days) AS total_work_days
    FROM working_days wd
    GROUP BY wd.employee_id
)

SELECT * FROM employee_work_summary LIMIT 50;

--
----4) Создадим индекс для таблицы publish_progress по полю book_id и step 
----Проверим, как наличие индекса влияет на производительность запроса, используя трассировку (EXPLAIN ANALYZE)

--Без индекса
EXPLAIN ANALYZE 
SELECT * FROM publish_progress 
WHERE book_id = 1 AND step BETWEEN 1 AND 3
LIMIT 50;

--Limit  (cost=0.00..1.19 rows=1 width=24) (actual time=0.010..0.013 rows=3 loops=1)
--Seq Scan on publish_progress  (cost=0.00..37.48 rows=1 width=24) (actual time=0.012..0.016 rows=3 loops=1)
-- Filter: ((step >= 1) AND (step <= 3) AND (book_id = 1))
--Rows Removed by Filter: 8
--Planning Time: 0.146 ms
--Execution Time: 0.029 ms

--Создадим индекс
CREATE INDEX idx_publish_progress_book_id_step ON publish_progress (book_id, step);

EXPLAIN ANALYZE 
SELECT * FROM publish_progress 
WHERE book_id = 1 AND step BETWEEN 1 AND 3
LIMIT 50;

--Limit  (cost=0.00..1.19 rows=1 width=24) (actual time=0.010..0.013 rows=3 loops=1)
--Seq Scan on publish_progress  (cost=0.00..37.48 rows=1 width=24) (actual time=0.011..0.014 rows=3 loops=1)
--Filter: ((step >= 1) AND (step <= 3) AND (book_id = 1))
--Rows Removed by Filter: 8
--Planning Time: 0.182 ms
--Execution Time: 0.020 ms

DROP INDEX idx_publish_progress_book_id_step;

----Таким образом, наличие индекса уменьшает время выполнения запроса, то есть, производительность увеличивается. Но это несильно заметно на небольшом объеме данных,
---- для того, чтобы индекс значительно увеличил производительность, необходимо работать с большим объемом данных (>10000 записей, например)
--
----5) Используя трассировку, проанализируем запрос, который находит общее количество этапов работы над каждой книгой.
--

EXPLAIN ANALYZE
SELECT book_id, COUNT(*) AS total_steps
FROM publish_progress
GROUP BY book_id
ORDER BY total_steps DESC
LIMIT 10;

--Limit  (cost=39.87..39.90 rows=10 width=12) (actual time=0.024..0.026 rows=5 loops=1)
--  ->  Sort  (cost=39.87..40.37 rows=200 width=12) (actual time=0.023..0.024 rows=5 loops=1)
--        Sort Key: (count(*)) DESC
--        Sort Method: quicksort  Memory: 25kB
--        ->  HashAggregate  (cost=33.55..35.55 rows=200 width=12) (actual time=0.017..0.019 rows=5 loops=1)
--              Group Key: book_id
--              Batches: 1  Memory Usage: 40kB
--              ->  Seq Scan on publish_progress (cost=0.00..25.70 rows=1570 width=4) (actual time=0.007..0.009 rows=11 loops=1)
--Planning Time: 0.066 ms
--Execution Time: 0.050 ms


--Анализ:
--1) Limit - ограничение на вывод 10 строк, actual time - время выполнения шага
--2) Sort - сорировка по столбцу (count(*)) в порядке убывания, метод сортировки - быстрая сортировка (quick sort),
--выделенный объем памяти для сортировки результатов - 25 кб
--3) HashAggregate - агрегация данных по ключу book_id, количество пакетов для агрегации (Batches) = 1,
--использованное количество памяти - 40 кб
--4) Seq Scan on publish_progress  - сканирование таблицы publish_progress, указание времени выполнения шага
--5) Planning Time - время выполнения с учетом задержки до сервера (планируемое время выполнения запроса) = 0.066 ms
--6) Execution Time - фактическое время выполнения запроса =  0.050 ms

