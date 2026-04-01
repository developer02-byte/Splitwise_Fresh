(async () => {
    try {
        let r = await fetch('http://localhost:3000/api/currencies/rates');
        console.log("RATES STATUS:", r.status, await r.text());
        r = await fetch('http://localhost:3000/api/health');
        console.log("HEALTH STATUS:", r.status, await r.text());
    } catch (e) { console.error(e); }
})();
