delimiter $$

drop procedure delete_goods$$

create procedure delete_goods(
  in i_last_update int(10) unsigned
)
begin
  declare v_goods_id int(10) unsigned;
  declare goods_done int default false;
  declare goods_cursor cursor for select goods_id from ecm_goods where last_update < i_last_update;
  declare continue handler for not found set goods_done = true;

  open goods_cursor;

  goods_loop: loop
    fetch goods_cursor into v_goods_id;
    if goods_done then
      leave goods_loop;
    end if;
    delete from ecm_goods where goods_id = v_goods_id;
    delete from ecm_goods_spec where goods_id = v_goods_id;
    delete from ecm_goods_attr where goods_id = v_goods_id;
    delete from ecm_goods_image where goods_id = v_goods_id;
    delete from ecm_category_goods where goods_id = v_goods_id;
    select concat('goods_id:', v_goods_id, ' deleted') info;
  end loop;

  close goods_cursor;

end$$

delimiter ;
