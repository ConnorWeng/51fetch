var taobao_crawler = require('./lib/taobao_crawler'),
    database = require('./lib/database');

var db = new database({
    host: 'localhost',
    user: 'root',
    password: '57826502',
    database: 'ecmall51',
    port: 3306
});

taobao_crawler.setDatabase(db);

var unfetchedGoods = [];
db.getUnfetchedGoods(function (err, result) {
    if (err) throw err;
    unfetchedGoods = result;
    crawl();
});

function crawl() {
    if (unfetchedGoods.length > 0) {
        good = unfetchedGoods.shift();
        taobao_crawler.crawlItem(good.good_http, crawl);
    } else {
        console.log('complete');
        db.end();
    }
}
