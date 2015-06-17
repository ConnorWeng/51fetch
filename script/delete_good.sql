delimiter $$

drop procedure delete_good$$

create procedure delete_good(
  in i_like_good_http varchar(255)
)
begin
  declare v_goods_id int(10) unsigned;

  select goods_id into v_goods_id from ecm_goods where good_http like i_like_good_http limit 1;

  if v_goods_id is not null then
    delete from ecm_goods where goods_id = v_goods_id;
    delete from ecm_goods_spec where goods_id = v_goods_id;
    delete from ecm_goods_attr where goods_id = v_goods_id;
    delete from ecm_goods_image where goods_id = v_goods_id;
    delete from ecm_category_goods where goods_id = v_goods_id;
  end if;

end$$

delimiter ;
