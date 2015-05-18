delimiter $$

create event if not exists sync_event
on schedule every 1 day
starts '2015-05-19 04:30:00'
on completion preserve
do begin
   call sync_goods_data(5000, 99999);
end$$

delimiter ;
