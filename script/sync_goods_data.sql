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
      leave store_loop;
    end if;

    update ecm_store s inner join wangpi51.ecm_store ws on s.store_id = v_store_id and ws.store_id = v_store_id_wangpi51 set s.tel = ws.tel, s.cate_content = ws.cate_content;
    call log_sync('store', v_store_id, null, null, 1);

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
          SET goods_done = false;
          leave goods_loop;
        end if;
        call merge_good_data(v_store_id, v_goods_name, v_default_image, v_price, v_good_http, v_cids, v_add_time, v_last_update);
      end loop;

      close goods_cursor;
    end block2;

    select concat('store_id:', v_store_id, ' done') info;

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
  declare v_image varchar(255);
  declare v_image_240 varchar(255);
  declare v_image_460 varchar(255);

  select goods_id into v_goods_id from ecm_goods where store_id = i_store_id and good_http = i_good_http limit 1;
  select replace(replace(replace(replace(replace(i_default_image, '_160x160.jpg', ''), '_180x180.jpg', ''), '_240x240.jpg', ''), '_250x250.jpg', ''), '_b.jpg', '') into v_image;
  select concat(v_image, '_240x240.jpg') into v_image_240;
  select concat(v_image, '_460x460.jpg') into v_image_460;

  if v_goods_id is not null then
    update ecm_goods set goods_name = i_goods_name, default_image = v_image_240, price = i_price, cids = i_cids, add_time = i_add_time, last_update = i_last_update where goods_id = v_goods_id;
    update ecm_goods_spec set price = i_price where goods_id = v_goods_id;
    update ecm_goods_image set image_url = v_image, thumbnail = v_image_460, file_id = 0 where goods_id = v_goods_id and sort_order = 0;
    call log_sync('update', i_store_id, v_goods_id, i_last_update, 1);
  else
    insert into ecm_goods(store_id, goods_name, default_image, price, good_http, cids, add_time, last_update) values (i_store_id, i_goods_name, v_image_240, i_price, i_good_http, i_cids, i_add_time, i_last_update);
    set v_goods_id = last_insert_id();
    insert into ecm_goods_image(goods_id, image_url, thumbnail, sort_order, file_id) values (v_goods_id, v_image, v_image_460, 0, 0);
    call log_sync('insert', i_store_id, v_goods_id, i_last_update, 1);
  end if;
end$$

delimiter ;
