// Testes do orquestrador (AvaliacaoService) com um modelo OData V4 falso.
"use strict";

const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

const mods = {};
global.sap = {
	ui: {
		define: (deps, factory) => {
			const resolved = deps.map((d) => mods[d]);
			mods.__last = factory.apply(null, resolved);
		}
	}
};
require(path.join(__dirname, "..", "..", "webapp", "jev", "JevClient.js"));
mods["zpocjev/antifraude/jev/JevClient"] = mods.__last;
require(path.join(__dirname, "..", "..", "webapp", "jev", "AvaliacaoService.js"));
const Service = mods.__last;
const JevClient = mods["zpocjev/antifraude/jev/JevClient"];
const { simulate } = require(path.join(__dirname, "..", "..", "mock-jev", "simulator.js"));

function fakeContext(oDados) {
	const chamadas = { leituras: [], acoes: [] };
	const oModel = {
		bindContext(sPath, oCtx, mParams) {
			if (sPath.endsWith("(...)")) {
				const params = {};
				return {
					setParameter: (k, v) => (params[k] = v),
					invoke: async () => {
						chamadas.acoes.push({ acao: sPath, ctx: oCtx.getPath(), params });
						return oCtx;
					},
					destroy() {}
				};
			}
			chamadas.leituras.push({ sPath, mParams });
			return { requestObject: async () => Object.assign({}, oDados), destroy() {} };
		}
	};
	return { ctx: { getModel: () => oModel, getPath: () => "/Pedido('" + oDados.PurchaseOrder + "')" }, chamadas };
}

const BASE = { PurchaseOrder: "4500009999", RuleClassification: "AVALIAR_JEV", SuplrPOCount7d: 2, SuplrPOCount24h: 1, SupplierAgeDays: 1000 };

test("le so a lista branca (sem SupplierName/Supplier/CreatedByUser)", async () => {
	globalThis.fetch = async (u, o) => ({ ok: true, json: async () => simulate(JSON.parse(o.body)).body });
	const { ctx, chamadas } = fakeContext(BASE);
	await Service.avaliarPedido(ctx);
	const sel = chamadas.leituras[0].mParams.$select.split(",");
	for (const p of ["SupplierName", "Supplier", "CreatedByUser"]) assert.ok(!sel.includes(p), p);
});

test("BLOQUEIO_REGRA: nao chama o Jev e registra com JevDisponivel=false", async () => {
	let chamouJev = false;
	globalThis.fetch = async () => {
		chamouJev = true;
		throw new Error("nao devia chamar");
	};
	const { ctx, chamadas } = fakeContext(Object.assign({}, BASE, { RuleClassification: "BLOQUEIO_REGRA" }));
	const r = await Service.avaliarPedido(ctx);
	assert.strictEqual(r.status, "BLOQUEIO_REGRA");
	assert.strictEqual(chamouJev, false);
	assert.strictEqual(chamadas.acoes.length, 1);
	assert.strictEqual(chamadas.acoes[0].acao, Service.ACAO + "(...)");
	assert.strictEqual(chamadas.acoes[0].params.JevDisponivel, false);
});

test("sucesso: acao recebe probabilidades com 4 casas", async () => {
	globalThis.fetch = async (u, o) => {
		assert.strictEqual(u, "/jev/decisions");
		return { ok: true, json: async () => simulate(JSON.parse(o.body)).body };
	};
	const { ctx, chamadas } = fakeContext(BASE);
	const r = await Service.avaliarPedido(ctx);
	assert.strictEqual(r.status, "AVALIADO");
	const p = chamadas.acoes[0].params;
	assert.strictEqual(p.JevDisponivel, true);
	assert.strictEqual(p.ProbFracionamento, "0.2800");
	assert.strictEqual(Object.keys(p).length, 12);
});

test("falha do Jev: acao com JevDisponivel=false (INDISPONIVEL)", async () => {
	globalThis.fetch = async () => ({ ok: false, status: 503 });
	const { ctx, chamadas } = fakeContext(BASE);
	const r = await Service.avaliarPedido(ctx);
	assert.strictEqual(r.status, "INDISPONIVEL");
	assert.strictEqual(chamadas.acoes[0].params.JevDisponivel, false);
	assert.strictEqual(chamadas.acoes[0].params.JevModeloVersao, "INDISPONIVEL:HTTP_503");
	assert.ok(JevClient);
});
