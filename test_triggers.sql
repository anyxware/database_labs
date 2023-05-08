\i init.sql

insert into product_group (name) values ('group1');

insert into firm_category (name) values ('firm_category1');
insert into firm (name, category_id) values ('super_firm', 1);

insert into role (code, name) values (1, 'boss');
insert into worker (initials, login, password, role_id) values ('hiy', 'super_cool', 'super_duper', 1);

insert into delivery_note (manager_id, firm_id) values (1, 1);
insert into delivery_note (manager_id, firm_id) values (1, 1);

insert into product(name, price) values ('product1', 100);

insert into product_in_note (count, price, product_id, note_id) values (100, 10, 1, 1);
insert into product_in_note (count, price, product_id, note_id) values (100, 10, 1, 1);
insert into product_in_note (count, price, product_id, note_id) values (10, 1, 1, 2);
/*
insert into product_in_note (count, product_id, note_id) values (1, 1, 1);
*/



insert into product_group (name) values ('super');
insert into product_group (name) values ('duper');
/*
insert into product(name, price) values ('super_duper', 100);
  select * from product_product_group join product_group on product_group.id = product_product_group.group_id;
  */