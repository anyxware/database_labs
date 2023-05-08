\i init.sql

insert into firm_category (name) values ('firm_category1');
insert into firm (name, category_id) values ('super_firm', 1);

insert into role (code, name) values (1, 'boss');
insert into worker (initials, login, password, role_id) values ('hiy', 'super_cool', 'super_duper', 1);

insert into product_group(name) values ('group1'), ('group2'), ('group3'), ('group4');
insert into product_group(name) values ('group5');

-- call update_parent_group_id(5, array[1, 2, 3, 4]);
-- call update_parent_group_id(1, array[2, 3, 4, 5]);


insert into product(name, count, price) values ('p1', 100, 100), ('p2', 100, 100), ('p3', 100, 100);
--call create_note(array['(1,100)', '(2, 1000)', '(3,1)']::counted_product[], 1, 1);