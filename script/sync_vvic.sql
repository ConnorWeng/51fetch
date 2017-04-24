delimiter $$

drop procedure sync_vvic$$

create procedure sync_vvic(
)
begin
  declare vvic_store_done int default false;
  declare v_51_state, v_name, v_uid, v_store_name, v_address, v_tel, v_im_qq, v_im_ww, v_im_wx, v_business_scope, v_shop_mall, v_floor, v_see_price, v_shop_http, v_mk_name, v_dangkou_address varchar(255);
  declare v_service_daifa, v_service_tuixian, v_serv_realpic int(2);
  declare vvic_store_cursor cursor for select store_name, address, tel, im_qq, im_ww, im_wx, business_scope, shop_mall, floor, see_price, shop_http, mk_name, dangkou_address, service_daifa, service_tuixian, serv_realpic from ecm_store_vvic v where not exists (select 1 from ecm_store s where s.shop_http = v.shop_http) and see_price != '';
  declare vvic_exist_store_cursor cursor for select store_name, address, tel, im_qq, im_ww, im_wx, business_scope, shop_mall, floor, see_price, shop_http, mk_name, dangkou_address, service_daifa, service_tuixian, serv_realpic from ecm_store_vvic v where exists (select 1 from ecm_store s where s.shop_http = v.shop_http);
  declare continue handler for not found set vvic_store_done = true;

  declare exit handler for sqlexception
  BEGIN
    rollback;
    GET DIAGNOSTICS CONDITION 1
      @p2 = MESSAGE_TEXT;
      select concat('unexpect exception! rollback! vvic store ', v_store_name, ' ', v_shop_http, ' ', @p2) error;
  END;

  declare exit handler for sqlwarning
  BEGIN
    rollback;
    select concat('unexpect warning! rollback! vvic store ', v_store_name, ' ', v_shop_http) error;
  END;

  start transaction;
  open vvic_store_cursor;

  vvic_store_loop: loop
    fetch vvic_store_cursor into v_store_name, v_address, v_tel, v_im_qq, v_im_ww, v_im_wx, v_business_scope, v_shop_mall, v_floor, v_see_price, v_shop_http, v_mk_name, v_dangkou_address, v_service_daifa, v_service_tuixian, v_serv_realpic;
    if vvic_store_done then
      leave vvic_store_loop;
    end if;

    if v_im_qq = '' then
      set v_name = v_im_ww;
    else
      set v_name = v_im_qq;
    end if;

    select uid into v_uid from ucenter51.uc_members where username = concat('mall-', v_name);

    if v_uid is null then
      call register_vvic_store(v_im_qq, v_mk_name, v_shop_mall, v_floor, v_address, v_dangkou_address, v_store_name, v_see_price, v_im_ww, v_shop_http, v_business_scope, v_im_wx, v_tel, v_service_daifa, v_service_tuixian, v_serv_realpic);
      select concat('registered vvic store: ', v_store_name, ' ', v_shop_http) info;
    else
      select state into v_51_state from ecm_store where store_id = v_uid;
      if v_51_state = 0 then
        update ecm_store set state = 1, close_reason = '', shop_http = v_shop_http where store_id = v_uid;
        select concat('opened vvic store: ', v_store_name, ' ', v_shop_http) info;
      end if;
    end if;

    set vvic_store_done = false;
    set v_51_state = null;
    set v_name = null;
    set v_uid = null;
    set v_store_name = null;
    set v_address = null;
    set v_tel = null;
    set v_im_qq = null;
    set v_im_ww = null;
    set v_im_wx = null;
    set v_business_scope = null;
    set v_shop_mall = null;
    set v_floor = null;
    set v_see_price = null;
    set v_shop_http = null;
    set v_mk_name = null;
    set v_dangkou_address = null;
    set v_service_daifa = null;
    set v_service_tuixian = null;
    set v_serv_realpic = null;

  end loop;

  close vvic_store_cursor;
  commit;

  set vvic_store_done = false;
  start transaction;
  open vvic_exist_store_cursor;

  vvic_exist_store_loop: loop
    fetch vvic_exist_store_cursor into v_store_name, v_address, v_tel, v_im_qq, v_im_ww, v_im_wx, v_business_scope, v_shop_mall, v_floor, v_see_price, v_shop_http, v_mk_name, v_dangkou_address, v_service_daifa, v_service_tuixian, v_serv_realpic;
    if vvic_store_done then
      leave vvic_exist_store_loop;
    end if;

    if v_see_price != '' and v_see_price != '减半' then
      update ecm_store set store_name = v_store_name, address = v_address, tel = v_tel, im_qq = v_im_qq, im_ww = v_im_ww, im_wx = v_im_wx, business_scope = v_business_scope, shop_mall = v_shop_mall, floor = v_floor, see_price = v_see_price, mk_name = v_mk_name, dangkou_address = v_dangkou_address, service_daifa = v_service_daifa, service_tuixian = v_service_tuixian, serv_realpic = v_serv_realpic where shop_http = v_shop_http;
    else
      update ecm_store set store_name = v_store_name, address = v_address, tel = v_tel, im_qq = v_im_qq, im_ww = v_im_ww, im_wx = v_im_wx, business_scope = v_business_scope, shop_mall = v_shop_mall, floor = v_floor, mk_name = v_mk_name, dangkou_address = v_dangkou_address, service_daifa = v_service_daifa, service_tuixian = v_service_tuixian, serv_realpic = v_serv_realpic where shop_http = v_shop_http;
    end if;

    set vvic_store_done = false;
    set v_store_name = null;
    set v_address = null;
    set v_tel = null;
    set v_im_qq = null;
    set v_im_ww = null;
    set v_im_wx = null;
    set v_business_scope = null;
    set v_shop_mall = null;
    set v_floor = null;
    set v_see_price = null;
    set v_shop_http = null;
    set v_mk_name = null;
    set v_dangkou_address = null;
    set v_service_daifa = null;
    set v_service_tuixian = null;
    set v_serv_realpic = null;

  end loop;

  close vvic_exist_store_cursor;
  commit;

  start transaction;
  update ecm_store s set s.state = 0, s.close_reason = 'sync with vvic' where s.state = 1 and not exists (select 1 from ecm_store_vvic v where v.shop_http = s.shop_http);
  update ecm_store set state = 1, close_reason = '' where store_id in (6527,8131,10114,5867,11925,91134,7604,155600,156207,149278,9772,158398,9038,148204,105851,153569,19306,7241,5808,154398,10896,13778,21062,152975,8715,155480);
  commit;

  call build_market;

end$$

delimiter ;
