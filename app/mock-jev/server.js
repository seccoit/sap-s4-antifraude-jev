/**
 * Simulador do Jev como servidor HTTP isolado (opcional), no mesmo formato do Jev real.
 * O caminho padrao NAO precisa dele: sem OPENROUTER_API_KEY o middleware ui5-middleware/jevProxy.js
 * ja usa o simulador em processo. Use este servidor para exercitar o modo "real" do proxy sem
 * gastar creditos:
 *   npm run mock-jev                                  (porta 4005)
 *   .env: OPENROUTER_API_KEY=teste-local  JEV_URL=http://localhost:4005/api/alpha/decisions
 */
"use strict";

const http = require("node:http");
const { simulate, plano, ERRO_503 } = require("./simulator");

const PORT = Number(process.env.MOCK_JEV_PORT || 4005);

function enviar(res, status, obj) {
	res.writeHead(status, { "Content-Type": "application/json" });
	res.end(JSON.stringify(obj));
}

http
	.createServer((req, res) => {
		if (req.method !== "POST") {
			return enviar(res, 405, { error: { code: 405, message: "use POST" } });
		}
		let body = "";
		req.on("data", (c) => (body += c));
		req.on("end", () => {
			if (!/^Bearer \S+/.test(req.headers.authorization || "")) {
				return enviar(res, 401, { error: { code: 401, message: "simulador: Authorization ausente" } });
			}
			let json;
			try {
				json = JSON.parse(body || "{}");
			} catch (e) {
				return enviar(res, 400, { error: { code: 400, message: "JSON invalido" } });
			}
			const p = plano(req.headers["x-jev-sim"]);
			console.log(`[mock-jev] ${req.url} modelo=${json.model} -> ${p.tipo} ${p.latenciaMs}ms`);
			setTimeout(() => {
				if (p.tipo === "erro") return enviar(res, 503, ERRO_503);
				const r = simulate(json);
				enviar(res, r.status, r.body);
			}, p.latenciaMs);
		});
	})
	.listen(PORT, () => console.log(`[mock-jev] simulador do Jev em http://localhost:${PORT}/api/alpha/decisions`));
