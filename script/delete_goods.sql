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
    delete from ecm_goods where goods_id = v_goods_id;
    delete from ecm_goods_spec where goods_id = v_goods_id;
    delete from ecm_goods_attr where goods_id = v_goods_id;
    delete from ecm_goods_image where goods_id = v_goods_id;
    delete from ecm_category_goods where goods_id = v_goods_id;
    select concat('goods_id:', v_goods_id, ' deleted') info;
  end loop;

  close goods_cursor;

  select o_count;

end$$

delimiter ;
