delimiter $$

drop procedure build_market$$

create procedure build_market()
begin
  declare v_store_id, v_mall_id, v_floor_id, v_nan int(10) unsigned;
  declare v_shop_mall, v_floor varchar(255);
  declare store_done int default false;
  declare store_cursor cursor for select store_id, shop_mall, floor from ecm_store where state = 1 and shop_mall != '' and floor != '';
  declare continue handler for not found set store_done = true;

  open store_cursor;

  start transaction;
  store_loop: loop
    fetch store_cursor into v_store_id, v_shop_mall, v_floor;
    if store_done then
      leave store_loop;
    end if;

    select (substr(v_floor, -1, 1) REGEXP '[^0-9.]') into v_nan;

    if v_nan = 1 then
      set v_floor = v_floor;
    else
      set v_floor = concat(v_floor, 'F');
    end if;

    select mk_id into v_mall_id from ecm_market where mk_name = v_shop_mall and parent_id = 1;
    if v_mall_id is not null then
      select mk_id into v_floor_id from ecm_market where mk_name = v_floor and parent_id = v_mall_id;
      if v_floor_id is not null then
        update ecm_store set mk_id = v_floor_id, mk_name = concat(v_shop_mall, '-', v_floor) where store_id = v_store_id;
      else
        insert into ecm_market(mk_name, parent_id) values (v_floor, v_mall_id);
        update ecm_store set mk_id = last_insert_id(), mk_name = concat(v_shop_mall, '-', v_floor) where store_id = v_store_id;
        select concat('store_id:', v_store_id, ' insert floor and update') info;
      end if;
    else
      insert into ecm_market(mk_name, parent_id) values (v_shop_mall, 1);
      insert into ecm_market(mk_name, parent_id) values (v_floor, last_insert_id());
      update ecm_store set mk_id = last_insert_id(), mk_name = concat(v_shop_mall, '-', v_floor) where store_id = v_store_id;
      select concat('store_id:', v_store_id, ' insert mall and floor') info;
    end if;

    set store_done = false;
    set v_mall_id = null;
    set v_floor_id = null;
    set v_nan = null;

  end loop;

  close store_cursor;
  commit;

end$$

delimiter ;
