var taobao_crawler = require('./lib/taobao_crawler'),
    stores = [];

taobao_crawler.getAllStores('1 order by store_id', function (err, unfetchedStores) {
    if (err) {
        throw err;
    }
    stores = unfetchedStores;
    crawl();
});

function crawl() {
    if (stores.length > 0) {
        store = stores.shift();
        taobao_crawler.crawlStore(store, crawl);
    } else {
        console.log('completed.');
    }
}
