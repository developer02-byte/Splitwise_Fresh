(async () => {
    try {
        const r = await fetch('http://localhost:8080/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: 'test@example.com', password: 'password123' })
        });
        const d = await r.json();
        console.log("STATUS:", r.status);
        console.log("BODY:", d);
    } catch (e) { console.error(e); }
})();
