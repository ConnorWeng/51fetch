delimiter $$

drop procedure delete_stores$$

create procedure delete_stores(
  in i_last_update int(10) unsigned
)
begin
  declare v_store_id int(10) unsigned;
  declare store_done int default false;
  declare store_cursor cursor for select store_id from ecm_store where last_update < i_last_update and shop_http is not null;
  declare continue handler for not found set store_done = true;

  open store_cursor;

  store_loop: loop
    fetch store_cursor into v_store_id;
    if store_done then
      leave store_loop;
    end if;
    delete from ecm_store where store_id = v_store_id;
    delete from ecm_shipping where store_id = v_store_id;
    delete from ucenter51.uc_members where uid = v_store_id;
    delete from ucenter51.uc_memberfields where uid = v_store_id;
    select concat('store_id:', v_store_id, ' deleted') info;
    set store_done = false;
  end loop;

  close store_cursor;

end$$

delimiter ;
