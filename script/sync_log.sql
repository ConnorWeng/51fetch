drop table if exists `sync_log`;
create table if not exists `sync_log` (
  `log_id` int(10) unsigned not null auto_increment,
  `happen_time` timestamp,
  `action` varchar(10),
  `store_id` int(10) unsigned,
  `goods_id` int(10) unsigned,
  `last_update` int(10) unsigned,
  `count` int(10) unsigned,
  primary key (`log_id`),
  key `happen_time` (`happen_time`),
  key `store_id` (`store_id`),
  key `goods_id` (`goods_id`)
) engine=MyISAM default charset=utf8 comment='同步宝贝数据日志';

delimiter $$

drop procedure log_sync$$

create procedure log_sync(
  in i_action varchar(10),
  in i_store_id int(10) unsigned,
  in i_goods_id int(10) unsigned,
  in i_last_update int(10) unsigned,
  in i_count int(10) unsigned
)
begin
  insert into sync_log(happen_time, action, store_id, goods_id, last_update, count) values (now(), i_action, i_store_id, i_goods_id, i_last_update, i_count);
end$$

delimiter ;
