delimiter $$

drop procedure register_vvic_store$$

create procedure register_vvic_store(
  in i_qq varchar(60),
  in i_mk_name varchar(255),
  in i_shop_mall varchar(255),
  in i_floor varchar(255),
  in i_address varchar(255),
  in i_dangkou_address varchar(255),
  in i_store_name varchar(255),
  in i_see_price varchar(255),
  in i_im_ww varchar(255),
  in i_shop_http varchar(255),
  in i_business_scope varchar(50),
  in i_im_wx varchar(60),
  in i_tel varchar(60),
  in i_service_daifa tinyint(1),
  in i_service_tuixian tinyint(1),
  in i_serv_realpic int(2)
)
begin
  declare v_username, v_salt, v_time, v_name varchar(255);
  declare v_uid int(10) unsigned;

  if i_qq = '' then
    set v_name = i_im_ww;
  else
    set v_name = i_qq;
  end if;

  select username into v_username from ucenter51.uc_members where username = concat('mall-', v_name);
  set v_time = timestampdiff(second, '1970-1-1 8:0:0', now());

  if v_username is null then
    set v_username = concat('mall-', v_name);
    set v_salt = substr(rand(), 3, 4);
    insert into ucenter51.uc_members set secques='', username=v_username, password=md5(concat(md5(v_username), v_salt)), email=concat(i_qq, '@qq.com'), regip='112.124.54.224', regdate=v_time, salt=v_salt;
    set v_uid = last_insert_id();
    insert into ucenter51.uc_memberfields set uid = v_uid;
    insert into ecm_member set user_id=v_uid, user_name=v_username, password=md5(concat(md5(v_username), v_salt)), email=concat(i_qq, '@qq.com'), reg_time=v_time;
    insert into ecm_store set store_id=v_uid, owner_name=v_uid, owner_card='', region_id=2, region_name='中国', sgrade=1, domain='', state=1, add_time=v_time, im_qq=i_qq, mk_name=i_mk_name, shop_mall=i_shop_mall, floor=i_floor, address=i_address, dangkou_address=i_dangkou_address, store_name=i_store_name, see_price=i_see_price, im_ww=i_im_ww, shop_http=i_shop_http, has_link=0, serv_refund=0, serv_exchgoods=0, serv_sendgoods=0, serv_probexch=0, serv_deltpic=0, serv_modpic=0, serv_golden=0, last_update=v_time, sort_order=65535, business_scope = i_business_scope, im_wx = i_im_wx, tel = i_tel, service_daifa = i_service_daifa, service_tuixian = i_service_tuixian, serv_realpic = i_serv_realpic;
    insert into ecm_shipping set store_id=v_uid, shipping_name='网站默认快递', shipping_desc='网站默认快递', first_price=10, step_price=0, enabled=1, sort_order=255;
  else
    select concat(v_username, ' user exists') info;
  end if;

  set v_username = null;
  set v_uid = null;
end$$

delimiter ;
