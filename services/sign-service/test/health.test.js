import http from "http";

test("health schema shape", (done) => {
  // Adjust port if needed; CI can hit a running container or a mocked handler
  http.get("http://localhost:8080/v1/health", (res) => {
    expect(res.statusCode).toBeGreaterThanOrEqual(200);
    expect(res.statusCode).toBeLessThan(500);
    let data = "";
    res.on("data", (c) => (data += c));
    res.on("end", () => {
      try {
        const body = JSON.parse(data);
        expect(body).toHaveProperty("ok");
        expect(typeof body.ok).toBe("boolean");
        done();
      } catch (e) {
        done(e);
      }
    });
  }).on("error", done);
});
