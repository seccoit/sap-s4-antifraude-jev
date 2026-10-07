// Testa o middleware /jev nos dois modos, SEM chamar a API real:
// o "Jev real" e um servidor HTTP local configurado via JEV_URL.
"use strict";

const test = require("node:test");
const assert = require("node:assert");
const http = require("node:http");
const path = require("node:path");

const MIDDLEWARE = path.join(__dirname, "..", "..", "ui5-middleware", "jevProxy.js");
const CHAVE_FALSA = "chave-falsa-de-teste-123";

function logCaptura() {
	const linhas = [];
	const f = (...a) => linhas.push(a.join(" "));
	return { linhas, log: { info: f, warn: f, verbose: f, error: f } };
}

function servir(handler) {
	return new Promise((resolve) => {
		const srv = http.createServer(handler).listen(0, () => resolve(srv));
	});
}

async function montarProxy(env) {
	const antes = {};
	for (const k of ["OPENROUTER_API_KEY", "JEV_URL", "JEV_MODEL"]) {
		antes[k] = process.env[k];
		// "" (e nao delete): o dotenv nao sobrescreve, entao um .env local com chave real nunca e usado aqui
		process.env[k] = env[k] === undefined ? "" : env[k];
	}
	delete require.cache[require.resolve(MIDDLEWARE)];
	const cap = logCaptura();
	const mw = require(MIDDLEWARE)({ log: cap.log });
	for (const k of Object.keys(antes)) {
		if (antes[k] === undefined) delete process.env[k];
		else process.env[k] = antes[k];
	}
	// simula o mountPath /jev do ui5 server
	const srv = await servir((req, res) => {
		req.url = req.url.replace(/^\/jev/, "");
		mw(req, res, () => { res.statusCode = 404; res.end(); });
	});
	return { srv, cap, base: `http://localhost:${srv.address().port}/jev` };
}

const CORPO = { state: { order: { price_vs_info_record: "in_line" } }, questions: { q: { type: "noul", instructions: "x", criteria: { true: "a", false: "b" } } }, model: "modelo-do-navegador", user: "nao-deve-passar" };

test("modo real: injeta Authorization, forca model, filtra campos, repassa resposta", async () => {
	let recebido;
	const alvo = await servir((req, res) => {
		let b = "";
		req.on("data", (c) => (b += c));
		req.on("end", () => {
			recebido = { auth: req.headers.authorization, cookie: req.headers.cookie, body: JSON.parse(b) };
			res.writeHead(200, { "Content-Type": "application/json" });
			res.end(JSON.stringify({ model: "typesafe/jev-1.13-20260917", answers: {} }));
		});
	});
	const { srv, cap, base } = await montarProxy({ OPENROUTER_API_KEY: CHAVE_FALSA, JEV_URL: `http://localhost:${alvo.address().port}/api/alpha/decisions` });
	try {
		const r = await fetch(base + "/decisions", { method: "POST", headers: { "Content-Type": "application/json", Cookie: "SAP_SESSIONID=xyz", "X-Jev-Sim": "timeout" }, body: JSON.stringify(CORPO) });
		assert.strictEqual(r.status, 200);
		assert.strictEqual((await r.json()).model, "typesafe/jev-1.13-20260917");
		assert.strictEqual(recebido.auth, "Bearer " + CHAVE_FALSA);
		assert.strictEqual(recebido.cookie, undefined);
		assert.deepStrictEqual(Object.keys(recebido.body), ["model", "state", "questions"]);
		assert.strictEqual(recebido.body.model, "typesafe/jev-1.13");
		const h = await (await fetch(base + "/health")).json();
		assert.deepStrictEqual(h, { ok: true, modo: "real", modelo: "typesafe/jev-1.13" });
		assert.ok(!cap.linhas.join("\n").includes(CHAVE_FALSA), "chave apareceu no log");
	} finally {
		srv.close();
		alvo.close();
	}
});

test("modo real: erro HTTP do Jev (402) e repassado com o corpo {error}", async () => {
	const alvo = await servir((req, res) => {
		req.resume();
		req.on("end", () => {
			res.writeHead(402, { "Content-Type": "application/json" });
			res.end(JSON.stringify({ error: { code: 402, message: "Insufficient credits" } }));
		});
	});
	const { srv, base } = await montarProxy({ OPENROUTER_API_KEY: CHAVE_FALSA, JEV_URL: `http://localhost:${alvo.address().port}/x`, JEV_MODEL: "~typesafe/jev-latest" });
	try {
		const r = await fetch(base + "/decisions", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(CORPO) });
		assert.strictEqual(r.status, 402);
		assert.strictEqual((await r.json()).error.code, 402);
	} finally {
		srv.close();
		alvo.close();
	}
});

test("sem chave: simulador no formato do Jev; erro forcado vem como {error}", async () => {
	const { srv, base } = await montarProxy({});
	try {
		const ok = await fetch(base + "/decisions", { method: "POST", headers: { "Content-Type": "application/json", "X-Jev-Sim": "ok" }, body: JSON.stringify(CORPO) });
		const j = await ok.json();
		assert.strictEqual(ok.status, 200);
		assert.strictEqual(j.answers.q.type, "noul");
		assert.match(j.model, /^typesafe\/jev-1\.13/);
		const er = await fetch(base + "/decisions", { method: "POST", headers: { "Content-Type": "application/json", "X-Jev-Sim": "erro" }, body: JSON.stringify(CORPO) });
		assert.strictEqual(er.status, 503);
		assert.strictEqual((await er.json()).error.code, 503);
		const ruim = await fetch(base + "/decisions", { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
		assert.strictEqual(ruim.status, 400);
		assert.strictEqual((await (await fetch(base + "/health")).json()).modo, "simulador");
	} finally {
		srv.close();
	}
});
