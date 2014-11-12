delimiter $$

drop procedure proc_merge_good$$

create procedure proc_merge_good(
    in i_store_id int(10) unsigned,
    in i_default_image varchar(255),
    in i_price decimal(10,2),
    in i_good_http varchar(100),
    in i_cid varchar(20),
    in i_store_name varchar(255),
    in i_goods_name varchar(255),
    in i_now_time varchar(255),
    in i_cat_name varchar(255),
    out o_retcode int)
begin
    declare v_good_id int(10) unsigned;
    declare v_cids varchar(500);
    declare pos int(10);

    select goods_id,cids into v_good_id, v_cids from ecm_goods where good_http=i_good_http and store_id=i_store_id limit 1;

    set o_retcode = -1;

    if v_good_id is not null then
       select locate(i_cid, v_cids) into pos;
       if pos > 0 then
          update ecm_goods set goods_name=i_goods_name, default_image=i_default_image, price=i_price, good_http=i_good_http, last_update=i_now_time where goods_id=v_good_id;
       else
          update ecm_goods set goods_name=i_goods_name, default_image=i_default_image, price=i_price, good_http=i_good_http, last_update=i_now_time, cids=concat(cids,',',i_cid) where goods_id=v_good_id;
       end if;
       set o_retcode = 1;
    else
       insert into ecm_goods(store_id, goods_name, default_image, price, good_http, cids, add_time, last_update) values (i_store_id, i_goods_name, i_default_image, i_price, i_good_http, i_cid, i_now_time, i_now_time);
       set o_retcode = 2;
       set v_good_id = LAST_INSERT_ID();
    end if;

    replace into ecm_category_goods(cate_id, goods_id) values (i_cid, v_good_id);

    select i_store_name, i_goods_name, o_retcode;

end$$

delimiter ;
