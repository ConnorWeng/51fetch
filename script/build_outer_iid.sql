delimiter $$

drop procedure build_outer_iid$$

create procedure build_outer_iid(
  in i_min_store_id int(10) unsigned,
  in i_max_store_id int(10) unsigned
)
begin
  declare v_goods_id int(10) unsigned;
  declare v_store_id int(10) unsigned;
  declare v_shop_mall, v_address, v_price_huohao varchar(100);
  declare goods_done int default false;
  declare goods_cursor cursor for select goods_id, store_id from ecm_goods where store_id >= i_min_store_id and store_id < i_max_store_id;
  declare continue handler for not found set goods_done = true;

  open goods_cursor;

  goods_loop: loop
    fetch goods_cursor into v_goods_id, v_store_id;
    if goods_done then
      leave goods_loop;
    end if;

    select shop_mall, address into v_shop_mall, v_address from ecm_store where store_id = v_store_id;

    select substring_index(attr_value, '_', -2) into v_price_huohao from ecm_goods_attr where goods_id = v_goods_id and attr_id = 1;

    if v_price_huohao is not null then
      update ecm_goods_attr set attr_value = concat(v_shop_mall, v_address, '_', v_price_huohao) where goods_id = v_goods_id and attr_id = 1;
      select concat('goods_id:', v_goods_id, ' outer_iid:', v_shop_mall, v_address, '_', v_price_huohao) info;
    else
      select concat('goods_id:', v_goods_id, ' unfetch');
    end if;

    set goods_done = false;
    set v_goods_id = null;
    set v_store_id = null;
    set v_price_huohao = null;
    set v_shop_mall = null;
    set v_address = null;
  end loop;

  close goods_cursor;

end$$

delimiter ;
