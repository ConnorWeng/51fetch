# 数据库结构 #

采集涉及以下相关数据表：

ecm\_store
ecm\_goods
ecm\_goods\_image
ecm\_goods\_spec
ecm\_attribute
ecm\_goods\_attr
ecm\_gcategory
ecm\_category\_goods

采集基本流程，从ecm\_store表中获取店铺的淘宝地址(shop\_http)，首先采集店铺的html分类信息，放进ecm\_store表的cate_content字段，再把分类信息结构化后，写入ecm\_gcategory表。ecm\_gcategory表中如果store\_id为0，则说明是网站全局分类，如不为0，则是具体店铺的自定义分类。

采集完店铺分类后，采集具体的宝贝信息，基本信息写入ecm\_goods表，宝贝主图写入ecm\_goods\_image表，sku信息写入ecm\_goods\_spec表，宝贝属性写入ecm\_goods\_attr表。其中需注意的是ecm\_goods表中cate\_id\_1、cate\_id\_2、cate\_id\_3、cate\_id\_4对于ecm\_goods\_gcategory中的四级分类。宝贝属性中必须写入一条数据attr_id为1，内容为商家编码。
