/**
 * Middleware do UI5 server para a rota /jev (montado em ui5.yaml). Contrato: ../../jev-api.md
 *
 * O navegador chama POST /jev/decisions com { state, questions }.
 * - Com OPENROUTER_API_KEY (ambiente ou .env): repassa para JEV_URL
 *   (padrao https://openrouter.ai/api/alpha/decisions) com Authorization: Bearer <chave>
 *   injetado AQUI e `model` forcado para JEV_MODEL (padrao typesafe/jev-1.13).
 *   A chave e a URL real nunca chegam ao navegador e nunca sao escritas no log.
 * - Sem a chave: SIMULADOR local (mock-jev/simulator.js), mesmo formato de resposta.
 *   Header X-Jev-Sim: timeout|erro|ok forca o comportamento (ignorado no modo real).
 * Cookies/Authorization do navegador NAO sao repassados. So state/questions seguem adiante.
 */
"use strict";

const path = require("node:path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env"), quiet: true });
const { simulate, plano, ERRO_503 } = require("../mock-jev/simulator");

const MAX_BODY = 128 * 1024;
const URL_PADRAO = "https://openrouter.ai/api/alpha/decisions";
const MODELO_PADRAO = "typesafe/jev-1.13";

function lerCorpo(req) {
	return new Promise((resolve, reject) => {
		let size = 0;
		const chunks = [];
		req.on("data", (c) => {
			size += c.length;
			if (size > MAX_BODY) {
				reject(Object.assign(new Error("payload grande demais"), { status: 413 }));
				req.destroy();
				return;
			}
			chunks.push(c);
		});
		req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
		req.on("error", reject);
	});
}

function enviar(res, status, obj) {
	res.statusCode = status;
	res.setHeader("Content-Type", "application/json");
	res.setHeader("Cache-Control", "no-store");
	res.end(JSON.stringify(obj));
}

module.exports = function ({ log }) {
	const chave = (process.env.OPENROUTER_API_KEY || "").trim();
	const urlReal = (process.env.JEV_URL || "").trim() || URL_PADRAO;
	const modelo = (process.env.JEV_MODEL || "").trim() || MODELO_PADRAO;
	const timeoutMs = Number(process.env.JEV_TIMEOUT_MS || 5000);
	const modoReal = !!chave;
	log.info(modoReal ? `/jev -> Jev real (${new URL(urlReal).host}, modelo ${modelo})` : "/jev -> SIMULADOR local (defina OPENROUTER_API_KEY no .env para o Jev real)");

	return async function jevProxy(req, res, next) {
		const sub = (req.url || "/").split("?")[0].replace(/\/$/, ""); // sem o mountPath /jev
		if (req.method === "GET" && sub === "/health") {
			return enviar(res, 200, { ok: true, modo: modoReal ? "real" : "simulador", modelo });
		}
		if (req.method !== "POST" || sub !== "/decisions") {
			return next();
		}
		let clienteFechou = false;
		res.on("close", () => (clienteFechou = true));

		let entrada;
		try {
			entrada = JSON.parse((await lerCorpo(req)) || "{}");
		} catch (e) {
			return enviar(res, e.status || 400, { error: { code: e.status || 400, message: e.status ? e.message : "JSON invalido" } });
		}
		if (!entrada || typeof entrada !== "object" || !entrada.state || !entrada.questions) {
			return enviar(res, 400, { error: { code: 400, message: "state e questions sao obrigatorios" } });
		}
		// so estes campos seguem; model e definido pelo servidor
		const corpo = { model: modelo, state: entrada.state, questions: entrada.questions };

		if (!modoReal) {
			const p = plano(req.headers["x-jev-sim"]);
			log.verbose(`simulador -> ${p.tipo} ${p.latenciaMs}ms`);
			setTimeout(() => {
				if (res.writableEnded || clienteFechou) return; // o cliente abortou (timeout)
				if (p.tipo === "erro") return enviar(res, 503, ERRO_503);
				const r = simulate(corpo);
				enviar(res, r.status, r.body);
			}, p.latenciaMs);
			return;
		}

		const ctrl = new AbortController();
		const t = setTimeout(() => ctrl.abort(), timeoutMs);
		res.on("close", () => ctrl.abort());
		const t0 = Date.now();
		try {
			const r = await fetch(urlReal, {
				method: "POST",
				headers: { "Content-Type": "application/json", Accept: "application/json", Authorization: `Bearer ${chave}` },
				body: JSON.stringify(corpo),
				signal: ctrl.signal
			});
			const texto = await r.text();
			log.info(`Jev ${r.status} em ${Date.now() - t0} ms`);
			if (!clienteFechou) {
				res.statusCode = r.status;
				res.setHeader("Content-Type", r.headers.get("content-type") || "application/json");
				res.setHeader("Cache-Control", "no-store");
				res.end(texto);
			}
		} catch (e) {
			if (!res.writableEnded && !clienteFechou) {
				enviar(res, 504, { error: { code: 504, message: ctrl.signal.aborted ? "timeout ao chamar o Jev" : "falha de rede ao chamar o Jev" } });
			}
			log.warn(`falha ao chamar o Jev (${e.name})`);
		} finally {
			clearTimeout(t);
		}
	};
};
