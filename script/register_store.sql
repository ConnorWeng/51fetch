delimiter $$

drop procedure register_store$$

create procedure register_store(
  in i_qq varchar(255),
  in i_mk_name varchar(255),
  in i_shop_mall varchar(255),
  in i_floor varchar(255),
  in i_address varchar(255),
  in i_dangkou_address varchar(255),
  in i_store_name varchar(255),
  in i_see_price varchar(255),
  in i_im_ww varchar(255),
  in i_shop_http varchar(255)
)
begin
  declare v_username, v_salt varchar(255);
  declare v_uid int(10) unsigned;
  select username into v_username from dguc51.uc_members where username = concat('mall-', i_qq);

  if v_username is null then
    set v_username = concat('mall-', i_qq);
    set v_salt = substr(rand(), 3, 4);
    insert into dguc51.uc_members set secques='', username=v_username, password=md5(concat(md5(v_username), v_salt)), email=concat(i_qq, '@qq.com'), regip='112.124.54.224', regdate=1443279642, salt=v_salt;
    set v_uid = last_insert_id();
    insert into dguc51.uc_memberfields set uid = v_uid;
    insert into ecm_store set store_id=v_uid, owner_name=v_uid, owner_card='', region_id=2, region_name='中国', sgrade=1, domain='', state=1, add_time=1443279642, im_qq=i_qq, mk_name=i_mk_name, shop_mall=i_shop_mall, floor=i_floor, address=i_address, dangkou_address=i_dangkou_address, store_name=i_store_name, see_price=i_see_price, im_ww=i_im_ww, shop_http=i_shop_http, has_link=0, serv_refund=0, serv_exchgoods=0, serv_sendgoods=0, serv_probexch=0, serv_deltpic=0, serv_modpic=0, serv_golden=0, last_update=1443279642;
    insert into ecm_shipping set store_id=v_uid, shipping_name='网站默认快递', shipping_desc='网站默认快递', first_price=10, step_price=0, enabled=1, sort_order=255;
  end if;

  set v_username = null;
  set v_uid = null;
end$$

delimiter ;
