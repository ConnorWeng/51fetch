delimiter $$

drop procedure delete_goods$$

create procedure delete_goods(
  in i_last_update int(10) unsigned,
  in i_min_store_id int(10) unsigned,
  in i_max_store_id int(10) unsigned,
  out o_count int
)
begin
  declare v_goods_id int(10) unsigned;
  declare goods_done int default false;
  declare goods_cursor cursor for select goods_id from ecm_goods where store_id >= i_min_store_id and store_id < i_max_store_id and last_update < i_last_update;
  declare continue handler for not found set goods_done = true;

  set o_count = 0;

  open goods_cursor;

  goods_loop: loop
    fetch goods_cursor into v_goods_id;
    if goods_done then
      leave goods_loop;
    end if;
    set o_count = o_count + 1;
    insert into ecm_goods_delist(`goods_id`, `store_id`, `type`, `goods_name`, `description`, `cate_id`, `cate_name`, `brand`, `spec_qty`, `spec_name_1`, `spec_name_2`, `if_show`, `closed`, `close_reason`, `add_time`, `last_update`, `default_spec`, `default_image`, `searchcode`, `recommended`, `cate_id_1`, `cate_id_2`, `cate_id_3`, `cate_id_4`, `price`, `service_shipa`, `tags`, `sort_order`, `good_http`, `moods`, `cids`, `realpic`, `spec_pid_1`, `spec_pid_2`, `delivery_template_id`, `delivery_weight`, `score`, `taobao_price`) select `goods_id`, `store_id`, `type`, `goods_name`, `description`, `cate_id`, `cate_name`, `brand`, `spec_qty`, `spec_name_1`, `spec_name_2`, `if_show`, `closed`, `close_reason`, `add_time`, UNIX_TIMESTAMP(), `default_spec`, `default_image`, `searchcode`, `recommended`, `cate_id_1`, `cate_id_2`, `cate_id_3`, `cate_id_4`, `price`, `service_shipa`, `tags`, `sort_order`, `good_http`, `moods`, `cids`, `realpic`, `spec_pid_1`, `spec_pid_2`, `delivery_template_id`, `delivery_weight`, `score`, `taobao_price` from ecm_goods where goods_id = v_goods_id;
    delete from ecm_goods where goods_id = v_goods_id;
    delete from ecm_goods_spec where goods_id = v_goods_id;
    delete from ecm_goods_attr where goods_id = v_goods_id;
    delete from ecm_goods_image where goods_id = v_goods_id;
    delete from ecm_category_goods where goods_id = v_goods_id;
  end loop;

  close goods_cursor;

  select o_count;

end$$

delimiter ;
