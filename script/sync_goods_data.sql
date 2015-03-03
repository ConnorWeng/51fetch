delimiter $$

drop procedure sync_goods_data$$

create procedure sync_goods_data(
  in i_min_store_id int(10) unsigned,
  in i_max_store_id int(10) unsigned
)
begin
  declare store_done, goods_done int default false;
  declare v_store_id, v_store_id_wangpi51, v_max_last_update, v_count int(10) unsigned;
  declare store_cursor cursor for select store_id, max(store_id_wangpi51) from (select s.store_id, s5.store_id store_id_wangpi51 from ecm_store s, wangpi51.ecm_store s5 where s.shop_http = s5.shop_http and s.store_id >= i_min_store_id and s.store_id < i_max_store_id) t group by store_id order by store_id;
  declare continue handler for not found set store_done = true;

  truncate table sync_log;

  open store_cursor;

  store_loop: loop
    fetch store_cursor into v_store_id, v_store_id_wangpi51;
    if store_done then
      select max(last_update), count(1) into v_max_last_update, v_count from ecm_goods where store_id = v_store_id and not exists (select 1 from sync_log where sync_log.store_id = v_store_id and sync_log.goods_id = ecm_goods.goods_id);
      delete from ecm_goods where store_id = v_store_id and not exists (select 1 from sync_log where sync_log.store_id = v_store_id and sync_log.goods_id = ecm_goods.goods_id);
      delete from ecm_goods_spec where exists (select 1 from ecm_goods where store_id = v_store_id and ecm_goods_spec.goods_id = ecm_goods.goods_id) and not exists (select 1 from sync_log where sync_log.goods_id = ecm_goods_spec.goods_id);
      delete from ecm_goods_attr where exists (select 1 from ecm_goods where store_id = v_store_id and ecm_goods_attr.goods_id = ecm_goods.goods_id) and not exists (select 1 from sync_log where sync_log.goods_id = ecm_goods_attr.goods_id);
      delete from ecm_goods_image where exists (select 1 from sync_log where sync_log.store_id = v_store_id and sync_log.goods_id = ecm_goods_image.goods_id);
      call log_sync('delete', v_store_id, null, v_max_last_update, v_count);
      select concat('store_id:', v_store_id, ' done') info;
      leave store_loop;
    end if;

    block2: begin
      declare v_goods_name, v_default_image, v_good_http, v_cids varchar(255);
      declare v_price decimal(10,2);
      declare v_add_time, v_last_update int(10) unsigned;
      declare goods_cursor cursor for select goods_name, default_image, price, good_http, cids, add_time, last_update from wangpi51.ecm_goods where store_id = v_store_id_wangpi51;
      declare continue handler for not found set goods_done = true;

      open goods_cursor;

      goods_loop: loop
        fetch goods_cursor into v_goods_name, v_default_image, v_price, v_good_http, v_cids, v_add_time, v_last_update;
        if goods_done then
          leave goods_loop;
        end if;
        call merge_good_data(v_store_id, v_goods_name, v_default_image, v_price, v_good_http, v_cids, v_add_time, v_last_update);
      end loop;

      close goods_cursor;
    end block2;

  end loop;

  close store_cursor;

end$$

drop procedure merge_good_data$$

create procedure merge_good_data(
  in i_store_id int(10) unsigned,
  in i_goods_name varchar(255),
  in i_default_image varchar(255),
  in i_price decimal(10,2),
  in i_good_http varchar(255),
  in i_cids varchar(255),
  in i_add_time int(10) unsigned,
  in i_last_update int(10) unsigned
)
begin
  declare v_goods_id int(10) unsigned;

  select goods_id into v_goods_id from ecm_goods where store_id = i_store_id and good_http = i_good_http limit 1;

  if v_goods_id is not null then
    update ecm_goods set goods_name = i_goods_name, default_image = i_default_image, price = i_price, cids = i_cids, add_time = i_add_time, last_update = i_last_update where goods_id = v_goods_id;
    update ecm_goods_image set image_url = i_default_image, thumbnail = i_default_image, file_id = 0 where goods_id = v_goods_id;
    call log_sync('update', i_store_id, v_goods_id, i_last_update, 1);
  else
    insert into ecm_goods(store_id, goods_name, default_image, price, good_http, cids, add_time, last_update) values (i_store_id, i_goods_name, i_default_image, i_price, i_good_http, i_cids, i_add_time, i_last_update);
    call log_sync('insert', i_store_id, last_insert_id(), i_last_update, 1);
    insert into ecm_goods_image(goods_id, image_url, thumbnail, sort_order, file_id) values (last_insert_id(), i_default_image, i_default_image, 255, 0);
  end if;
end$$

delimiter ;