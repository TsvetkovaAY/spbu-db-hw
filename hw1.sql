--- ДОМАШНЕЕ ЗАДАНИЕ.-- 
--1. Создать таблицу courses, в которой будут храниться курсы студентов. Поля -- id, name, is_exam, min_grade, max_grade.-- 
--2. Создать таблицу groups, в которой будут храниться данные групп. Поля -- id, full_name, short_name, students_ids.-- 
--3. Создать таблицу students, в которой будут храниться данные студентов. Поля -- id, first_name, last_name, group_id, courses_ids.--
--4. Создать таблицу любого курса, в котором будут поля -- student_id, grade, grade_str с учетом min_grade и max_grade---- Каждую таблицу нужно заполнить соответствующими данные, показать процедуры фильтрации и агрегации.


create table courses (
	id serial primary key,
	name varchar(50),
	is_exam varchar(50),
	min_grade int,
	max_grade int
	);

insert into courses (name, is_exam, min_grade, max_grade) values 
('Math', 'yes', '0', '100'),
('History', 'no', '0', '100'),
('English', 'yes', '0', '100'),
('German', 'yes', '0', '100'),
('Computer Science', 'yes', '0', '100'),
('Physics', 'yes', '0', '100'),
('Communication Psychology', 'no', '0', '100');


--2. Создать таблицу groups, в которой будут храниться данные групп. Поля -- id, full_name, short_name, students_ids.-- 
create table groups (
	id serial primary key,
	full_name varchar(50),
	short_name varchar(50),
	students_ids integer[]
	);

insert into groups (full_name, short_name, students_ids) values 
('5030302-00201', '201', array[1, 3, 6]),
('5030302-00802', '802', array[2, 4, 5]);

--3. Создать таблицу students, в которой будут храниться данные студентов. Поля -- id, first_name, last_name, group_id, courses_ids.--

create table students (
	id serial primary key,
	first_name varchar(50),
	last_name varchar(50),
	group_id int references groups(id),
	courses_ids integer[]
	);

insert into students (first_name, last_name, group_id, courses_ids) values
  ('Rachel', 'Green', 1, array[1, 5, 6, 7]),
  ('Monica', 'Geller', 2, array[3, 5, 7]),
  ('Phoebe', 'Buffay', 1, array[1, 2, 3, 7]),
  ('Joey', 'Tribbiani', 2, array[1, 2, 3]),
  ('Chandler', 'Bing', 2, array[1, 2, 4, 7]),
  ('Ross', 'Geller', 1, array[1, 2, 3, 5, 6, 7]);

select * from students;

--4. Создать таблицу любого курса, в котором будут поля -- student_id, grade, grade_str с учетом min_grade и max_grade
---- Каждую таблицу нужно заполнить соответствующими данные, показать процедуры фильтрации и агрегации.

create table math_course (
	student_id integer,
	grade integer
	);

insert into math_course (student_id, grade)
select 
    id, 
    case
        when id = 1 then 70
        when id = 2 then 90
        when id = 3 then 55
        when id = 4 then 48
        when id = 5 then 80
        when id = 6 then 90
    end as grade
from students
where courses_ids @> (array[(select id from courses where name = 'Math')]);	

select * from math_course;
alter table math_course add column grade_str varchar(50);

update math_course
set grade_str = 
    case
        when grade >= 90 then 'A'
        when grade >= 80 then 'B'
        when grade >= 70 then 'C'
        when grade >= 60 then 'D'
        when grade >= 50 then 'E'
        else 'F'
    end;

select * from math_course;


--Высчитаем, сколько людей сдали математику:
select count(*) from math_course where grade_str != 'F';

--Высчитаем, сколько людей сдали математику на 'A':
select count(*) from math_course where grade_str = 'A';

--Высчитаем среднюю оценку студентов по математике:
select avg(grade) from math_course

