delimiter $$

drop procedure build_market$$

create procedure build_market()
begin
  declare v_store_id, v_mall_id, v_floor_id int(10) unsigned;
  declare v_shop_mall, v_floor varchar(255);
  declare store_done int default false;
  declare store_cursor cursor for select store_id, shop_mall, floor from ecm_store where shop_mall != '' and floor != '';
  declare continue handler for not found set store_done = true;

  open store_cursor;

  store_loop: loop
    fetch store_cursor into v_store_id, v_shop_mall, v_floor;
    if store_done then
      leave store_loop;
    end if;

    select mk_id into v_mall_id from ecm_market where mk_name = v_shop_mall;
    if v_mall_id is not null then
      select mk_id into v_floor_id from ecm_market where mk_name = concat(v_floor, 'F') and parent_id = v_mall_id;
      if v_floor_id is not null then
        update ecm_store set mk_id = v_floor_id, mk_name = v_shop_mall where store_id = v_store_id;
        select concat('store_id:', v_store_id, ' just update') info;
      else
        insert into ecm_market(mk_name, parent_id) values (concat(v_floor, 'F'), v_mall_id);
        update ecm_store set mk_id = last_insert_id(), mk_name = v_shop_mall where store_id = v_store_id;
        select concat('store_id:', v_store_id, ' insert floor and update') info;
      end if;
    else
      insert into ecm_market(mk_name, parent_id) values (v_shop_mall, 1);
      insert into ecm_market(mk_name, parent_id) values (concat(v_floor, 'F'), last_insert_id());
      update ecm_store set mk_id = last_insert_id(), mk_name = v_shop_mall where store_id = v_store_id;
      select concat('store_id:', v_store_id, ' insert mall and floor') info;
    end if;

    select concat('store_id:', v_store_id, ' done') info;
    set store_done = false;
    set v_mall_id = null;
    set v_floor_id = null;

  end loop;

  close store_cursor;

end$$

delimiter ;
