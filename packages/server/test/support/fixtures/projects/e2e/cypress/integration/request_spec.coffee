describe "redirects + requests", ->
  it "gets and sets cookies from cy.request", ->
    oneMinuteFromNow = Cypress.moment().add(1, "minute").unix()

    cy
      .request("http://localhost:2293/")
      .request("http://localhost:2293/cookies")
        .its("body").should("deep.eq", {
          "2293": "true"
          "2293-session": "true"
        })
      .getCookies().then (cookies) ->
        console.log cookies

        expect(cookies[0].domain).to.eq("localhost")
        expect(cookies[0].name).to.eq("2293")
        expect(cookies[0].value).to.eq("true")
        expect(cookies[0].httpOnly).to.eq(true)
        expect(cookies[0].path).to.eq("/")
        expect(cookies[0].secure).to.eq(false)
        expect(cookies[0].expiry).to.be.closeTo(oneMinuteFromNow, 5)

        expect(cookies[1]).to.deep.eq({
          domain: "localhost"
          name: "2293-session"
          value: "true"
          httpOnly: false
          path: "/"
          secure: false
        })

  it "visits idempotant", ->
    cy
      .visit("http://localhost:2290")
      .url()
        .should("eq", "http://localhost:2292/")
      .request("http://localhost:2290/cookies/one")
        .its("body").should("deep.eq", {"2290": "true"})
      .request("http://localhost:2291/cookies/two")
        .its("body").should("deep.eq", {"2291": "true"})
      .request("http://localhost:2292/cookies/three")
        .its("body").should("deep.eq", {"2292": "true"})
      .request("http://localhost:2292/counts")
        .its("body").should("deep.eq", {
          "localhost:2290": 1
          "localhost:2291": 1
          "localhost:2292": 1
          "localhost:2293": 1 ## from the previous test
        })

  it "automatically follows redirects", ->
    cy
      .request("http://localhost:2294/redirect")
      .then (resp) ->
        expect(resp.status).to.eq(200)
        expect(resp.body).to.eq("<html>home</html>")

  it "can turn off automatically following redirects", ->
    cy
      .request({
        url: "http://localhost:2294/redirect"
        followRedirect: false
      })
      .then (resp) ->
        expect(resp.status).to.eq(302)
        expect(resp.body).to.eq("Found. Redirecting to /home")
        expect(resp.redirectedToUrl).to.eq("http://localhost:2294/home")

  it "follows all redirects even when they change methods", ->
    cy
      .request({
        method: "POST"
        url: "http://localhost:2294/redirectPost"
      })
      .then (resp) ->
        expect(resp.status).to.eq(200)
        expect(resp.body).to.eq("<html>home</html>")

  it "can submit json body", ->
    cy
      .request({
        method: "POST"
        url: "http://localhost:2294/json"
        body: {
          foo: "bar"
          baz: "quux"
        }
      })
      .its("body")
      .should("deep.eq", {
        foo: "bar"
        baz: "quux"
      })

  it "can submit form url encoded body", ->
    cy
      .request({
        method: "POST"
        url: "http://localhost:2294/form"
        form: true
        body: {
          foo: "bar"
          baz: "quux"
        }
      })
      .its("body")
      .should("deep.eq", {
        foo: "bar"
        baz: "quux"
      })

  it "can send qs query params", ->
    cy
      .request({
        url: "http://localhost:2294/params"
        qs: {
          foo: "bar"
          baz: "quux"
          a: 1
        }
      })
      .its("body")
      .should("deep.eq", {
        url: "/params?foo=bar&baz=quux&a=1"
        params: {
          foo: "bar"
          baz: "quux"
          a: "1"
        }
      })

  it "passes even on non 2xx or 3xx status code", ->
    cy
      .request({
        url: "http://localhost:2294/statusCode?code=401"
        failOnStatusCode: false
      })
      .its("status").should("eq", 401)
      .request({
        url: "http://localhost:2294/statusCode?code=500"
        failOnStatusCode: false
      })
      .its("status").should("eq", 500)

  it "sets Accept header to */* by default", ->
    cy
      .request("http://localhost:2294/headers")
      .its("body")
      .its("headers")
      .its("accept")
      .should("eq", "*/*")

  it "can override the accept header", ->
    cy
      .request({
        url: "http://localhost:2294/headers"
        headers: {
          Accept: "text/html"
        }
      })
      .its("body")
      .its("headers")
      .its("accept")
      .should("eq", "text/html")

  it "issue #375: does not duplicate request cookies on 302 redirect", ->
    cy
      .request("http://localhost:2295/login")
      .request("POST", "http://localhost:2295/login")
      .its("body.cookie")
      .should("eq", "session=2")
