delimiter $$

drop procedure sync_stores$$

create procedure sync_stores(
  in i_min_store_id int(10) unsigned,
  in i_max_store_id int(10) unsigned,
  in i_suffix varchar(10)
)
begin
  declare store_done int default false;
  declare v_store_id, v_new_store_id, v_add_time int(10) unsigned;
  declare v_im_qq, v_tel, v_state, v_new_username, v_username, v_salt, v_time, v_shop_mall, v_floor, v_address, v_store_name, v_see_price, v_im_ww, v_shop_http, v_has_link, v_serv_refund, v_serv_exchgoods, v_serv_sendgoods, v_serv_probexch, v_serv_deltpic, v_serv_modpic, v_serv_golden varchar(255);
  declare store_cursor cursor for select store_id, im_qq, tel, state, add_time, shop_mall, floor, address, store_name, see_price, im_ww, shop_http, has_link, serv_refund, serv_exchgoods, serv_sendgoods, serv_probexch, serv_deltpic, serv_modpic, serv_golden from wangpi51.ecm_store s where im_qq != '' and store_id >= i_min_store_id and store_id < i_max_store_id order by s.store_id;
  declare continue handler for not found set store_done = true;

  open store_cursor;

  store_loop: loop
    fetch store_cursor into v_store_id, v_im_qq, v_tel, v_state, v_add_time, v_shop_mall, v_floor, v_address, v_store_name, v_see_price, v_im_ww, v_shop_http, v_has_link, v_serv_refund, v_serv_exchgoods, v_serv_sendgoods, v_serv_probexch, v_serv_deltpic, v_serv_modpic, v_serv_golden;
    if store_done then
      leave store_loop;
    end if;

    set v_time = timestampdiff(second, '1970-1-1 8:0:0', now());

    select store_id into v_new_store_id from ecm_store where shop_http = v_shop_http limit 1;

    if v_new_store_id is null then
      set v_username = concat('mall-', v_im_qq);
      set v_salt = substr(rand(), 3, 4);
      select username into v_new_username from ucenter51.uc_members where username = v_username;
      if v_new_username is null then
        set v_new_username = v_username;
      else
        set v_new_username = concat(v_username, i_suffix);
      end if;
      insert into ucenter51.uc_members set secques='', username=v_new_username, password=md5(concat(md5(v_new_username), v_salt)), email=concat(v_im_qq, '@qq.com'), regip='112.124.54.224', regdate=v_time, salt=v_salt;
      set v_new_store_id = last_insert_id();
      insert into ucenter51.uc_memberfields set uid = v_new_store_id;
      insert into ecm_store set store_id=v_new_store_id, owner_name=v_new_store_id, owner_card='', region_id=2, region_name='中国', tel=v_tel, sgrade=1, domain='', state=v_state, add_time=v_add_time, im_qq=v_im_qq, mk_name=v_shop_mall, shop_mall=v_shop_mall, floor=v_floor, address=v_address, dangkou_address=v_address, store_name=v_store_name, see_price=v_see_price, im_ww=v_im_ww, shop_http=v_shop_http, has_link=v_has_link, serv_refund=v_serv_refund, serv_exchgoods=v_serv_exchgoods, serv_sendgoods=v_serv_sendgoods, serv_probexch=v_serv_probexch, serv_deltpic=v_serv_deltpic, serv_modpic=v_serv_modpic, serv_golden=v_serv_golden, last_update=v_time;
      insert into ecm_shipping set store_id=last_insert_id(), shipping_name='网站默认快递', shipping_desc='网站默认快递', first_price=10, step_price=0, enabled=1, sort_order=255;
      select concat('new user and store registered, username is: ', v_new_username) info;
    else
      update ecm_store set tel=v_tel, shop_mall=v_shop_mall, floor=v_floor, address=v_address, store_name=v_store_name, see_price=v_see_price, im_ww=v_im_ww, shop_http=v_shop_http, has_link=v_has_link, serv_refund=v_serv_refund, serv_exchgoods=v_serv_exchgoods, serv_sendgoods=v_serv_sendgoods, serv_probexch=v_serv_probexch, serv_deltpic=v_serv_deltpic, serv_modpic=v_serv_modpic, serv_golden=v_serv_golden, last_update=v_time where store_id = v_new_store_id;
      select concat('store is updated, store_id is: ', v_new_store_id) info;
    end if;

    set store_done = false;
    set v_store_id = null;
    set v_new_store_id = null;
    set v_add_time = null;
    set v_im_qq = null;
    set v_tel = null;
    set v_state = null;
    set v_new_username = null;
    set v_username = null;
    set v_salt = null;
    set v_time = null;
    set v_shop_mall = null;
    set v_floor = null;
    set v_address = null;
    set v_store_name = null;
    set v_see_price = null;
    set v_im_ww = null;
    set v_shop_http = null;
    set v_has_link = null;
    set v_serv_refund = null;
    set v_serv_exchgoods = null;
    set v_serv_sendgoods = null;
    set v_serv_probexch = null;
    set v_serv_deltpic = null;
    set v_serv_modpic = null;
    set v_serv_golden = null;
  end loop;

end$$

delimiter ;
