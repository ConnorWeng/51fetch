delimiter $$

drop procedure build_outer_iid$$

create procedure build_outer_iid(
  in i_min_store_id int(10) unsigned,
  in i_max_store_id int(10) unsigned
)
begin
  declare v_goods_id int(10) unsigned;
  declare v_store_id int(10) unsigned;
  declare v_shop_mall, v_address, v_price_huohao, v_huohao, v_price, v_price_1, v_price_2 varchar(100);
  declare goods_done int default false;
  declare goods_cursor cursor for select goods_id, store_id, price from ecm_goods where store_id >= i_min_store_id and store_id < i_max_store_id;
  declare continue handler for not found set goods_done = true;

  open goods_cursor;

  goods_loop: loop
    fetch goods_cursor into v_goods_id, v_store_id, v_price;
    if goods_done then
      leave goods_loop;
    end if;

    select substring_index(v_price, '.', 1) into v_price_1;
    select substring_index(v_price, '.', -1) into v_price_2;
    if v_price_2 = '00' then
       set v_price = v_price_1;
    elseif instr(v_price_2, '0') = 2 then
       set v_price = concat(v_price_1, '.', substr(v_price_2, 1, 1));
    end if;

    select shop_mall, dangkou_address into v_shop_mall, v_address from ecm_store where store_id = v_store_id;

    select substring_index(attr_value, '_', -2) into v_price_huohao from ecm_goods_attr where goods_id = v_goods_id and attr_id = 1 limit 1;

    select substring_index(v_price_huohao, '_', -1) into v_huohao;

    if v_price_huohao is not null then
      update ecm_goods_attr set attr_value = concat(v_shop_mall, v_address, '_P', v_price, '_', v_huohao) where goods_id = v_goods_id and attr_id = 1;
      select concat('goods_id:', v_goods_id, ' outer_iid:', v_shop_mall, v_address, '_P', v_price, '_', v_huohao) info;
    else
      select concat('goods_id:', v_goods_id, ' unfetch');
    end if;

    set goods_done = false;
    set v_goods_id = null;
    set v_store_id = null;
    set v_price_huohao = null;
    set v_price = null;
    set v_price_1 = null;
    set v_price_2 = null;
    set v_shop_mall = null;
    set v_address = null;
  end loop;

  close goods_cursor;

end$$

delimiter ;
