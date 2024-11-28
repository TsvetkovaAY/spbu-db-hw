--Домашнее задание №4

--Создать триггеры со всеми возможными ключевыми словами, а также рассмотреть операционные триггеры
--Попрактиковаться в созданиях транзакций (привести пример успешной и фейл транзакции, объяснить в комментариях почему она зафейлилась)
--Попробовать использовать RAISE внутри триггеров для логирования

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
    ('David Brown', 'Sales Intern', 'Sales', 20000, 2),
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
    (2, 5, 6, '2024-12-17'),
    (2, 4, 2, '2024-10-10'),
    (3, 1, 10, '2024-11-12'),
    (3, 3, 5, '2024-10-9'),
    (3, 4, 3, '2024-11-14'),
    (3, 5, 8, '2024-11-9'),
    (4, 2, 8, '2024-11-10'),
    (4, 6, 2, '2024-12-13');

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



--1) Создать триггеры со всеми возможными ключевыми словами, а также рассмотреть операционные триггеры

--before

CREATE OR REPLACE FUNCTION check_number_of_sales()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantity < 1 THEN
        RAISE EXCEPTION 'Произошла ошибка: в запись о продаже машины вносится недопустимое количество проданных машин (< 1)!';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_number_of_sales
BEFORE INSERT OR UPDATE ON sales
FOR EACH ROW
WHEN (NEW.quantity IS NOT NULL)
EXECUTE FUNCTION check_number_of_sales();

-- after

CREATE OR REPLACE FUNCTION check_car_model()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT NEW.name LIKE '%Audi%' THEN
        RAISE EXCEPTION 'Машина должна быть марки Audi';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_car_model
AFTER INSERT OR UPDATE ON products
FOR EACH ROW
WHEN (NEW.name IS NOT NULL) 
EXECUTE FUNCTION check_car_model();

-- instead of
 
CREATE VIEW sales_view AS
SELECT * FROM sales;

CREATE OR REPLACE FUNCTION check_is_employee_exist()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM employees WHERE employee_id = NEW.employee_id) THEN
        RAISE EXCEPTION ' Сотрудник с id % не существует', NEW.employee_id;
    ELSE
        INSERT INTO sales (employee_id, product_id, quantity, sale_date)
        VALUES (NEW.employee_id, NEW.product_id, NEW.quantity, NEW.sale_date);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_is_employee_exist
INSTEAD OF INSERT ON sales_view
FOR EACH ROW
EXECUTE PROCEDURE check_is_employee_exist();

--for each statement

CREATE OR REPLACE FUNCTION check_interns_number()
RETURNS TRIGGER AS $$
BEGIN
	IF (SELECT COUNT(*) FROM employees WHERE position LIKE '%Intern%') > 2 THEN 
		RAISE EXCEPTION 'Общее количество стажирующихся работников превысило допустимый максимум (2 интерна)';
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_interns_number
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH STATEMENT
EXECUTE FUNCTION check_interns_number();

-- Приведем примеры успешной транзакции:

BEGIN;

INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES
    (2, 1, 10, '2024-11-15');
   
INSERT INTO products (name, price)
VALUES ('Audi Q4', 4.2);

DELETE FROM employees WHERE employee_id = 6;

-- Подтверждаем транзакцию
COMMIT;

-- Откат транзакции
ROLLBACK;


-- Приведем примеры неуспешной транзакции:

BEGIN;

INSERT INTO sales (employee_id, product_id, quantity, sale_date)
VALUES
    (2, 1, -1, '2024-10-19');

COMMIT;
ROLLBACK;
-- Неуспешна, так как сработает триггер trigger_number_of_sales на правильность заполнения отчетности 

BEGIN;

INSERT INTO products (name, price)
VALUES ('Aodi Q2', 7.9);

COMMIT;
ROLLBACK;
-- Неуспешна, так как сработает триггер trigger_car_model на марку машины (в салоне продаются только автомобили марки Audi), проверяем, что в документах правильно указана марка

BEGIN;

INSERT INTO sales_view (employee_id, product_id, quantity, sale_date)
VALUES
    (28, 1, 1, '2024-10-19');

COMMIT;
ROLLBACK;
-- Неуспешна, так как сработает триггер trigger_is_employee_exist на проверку существования сотрудника с указанным id, чтобы корректно заполнить документы о продажах


BEGIN;

INSERT INTO employees (name, position, department, salary, manager_id)
VALUES
    ('Ben Red',  'Intern', 'IT', 30000, 5),
    ('Harry Gray', 'Sales Intern', 'Sales', 27000, 2);
    
COMMIT;
ROLLBACK;
-- Неуспешна, так как сработает триггер trigger_interns_number на проверку количества интернов в компании, их должно быть не больше двух человек на все отделы
