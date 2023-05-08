\i init.sql

insert into firm_category (name) values ('firm_category1');
insert into firm (name, category_id) values ('super_firm', 1);

insert into role (code, name) values (1, 'boss');
insert into worker (initials, login, password, role_id) values ('hiy', 'super_cool', 'super_duper', 1);

insert into product(name, count, price) values ('p1', 100, 100), ('p2', 100, 100), ('p3', 100, 100), ('p6', 100, 100), ('p4', 100, 100), ('p5', 100, 100);

call create_note(array['(1,20)', '(2, 10)', '(3,10)']::counted_product[], 1, 1);
call create_note(array['(4,10)', '(5, 10)', '(6,10)']::counted_product[], 1, 1);
call create_note(array['(1,20)', '(2, 12)', '(3,1)']::counted_product[], 1, 1);
call create_note(array['(4,20)', '(2, 67)', '(6,1)']::counted_product[], 1, 1);
call create_note(array['(4,2)', '(4, 6)']::counted_product[], 1, 1);

update delivery_note set order_date = '2023-02-20' where id = 1;
update delivery_note set order_date = '2023-02-20' where id = 2;
update delivery_note set order_date = '2023-01-20' where id = 3;
update delivery_note set order_date = '2023-03-20' where id = 4;
update delivery_note set order_date = '2022-01-20' where id = 5;


insert into product_group (name) values ('g1'), ('g2'), ('g3'), ('g4'), ('g5'), ('g6');
update product_group set parent_group_id = 4 where name = 'g1' or name = 'g2' or name = 'g3';
update product_group set parent_group_id = 6 where name = 'g4' or name = 'g5';

insert into product_product_group (group_id, product_id) values (1,1), (1,2), (2,1), (2,3), (3,1), (4,1), (4,2), (4,3), (5,6), (6,4), (6,5);


insert into firm (name, category_id) values ('firm_with_no_notes', 1);
insert into firm (name, category_id) values ('firm_with_one_note', 1);
call create_note(array['(4,50)']::counted_product[], 1, 3);
insert into firm (name, category_id) values ('firm_without_debts', 1);
call create_note(array['(4,10)']::counted_product[], 1, 4);
call create_note(array['(4,10)']::counted_product[], 1, 4);
update delivery_note set payment_date = now() where id = 7;
