// Testes em Node (node --test) do cliente do Jev e do simulador. Contrato: ../../../jev-api.md
"use strict";

const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");

let JevClient;
global.sap = { ui: { define: (deps, factory) => { JevClient = factory(); } } };
require(path.join(__dirname, "..", "..", "webapp", "jev", "JevClient.js"));
const { simulate, plano } = require(path.join(__dirname, "..", "..", "mock-jev", "simulator.js"));

// Pedido 4500001403 como veio do S/4 em 2026-10-06 (com identificadores, que NAO podem vazar)
const PO_1403 = {
	PurchaseOrder: "4500001403", Supplier: "14300001", SupplierName: "Domestic BR Supplier 1 - BANCO RISC",
	CreatedByUser: "MVADEARAUJOM", SupplierAgeDays: 1266, SupplierCreatorIsPOCreator: false,
	MasterDataChanges30d: 0, DaysSinceLastMDChange: -1, SharedBankOtherCount: 0, SharedBankAccount: false,
	SuplrHistPOCount: 1, SuplrHistAvgAmount: "500.00", SuplrHistStdDevAmount: "0.00",
	AmountToSuplrAvgRatio: "99.0000", AmountZScore: "0.0000", MaxPriceToMaterialAvgRatio: "0.0000",
	MaxPriceToInfoRecordRatio: "0.9000", MaxQtyToHistRatio: "0.0000", MaterialNewForSupplier: "X",
	PaymentTermsDiverge: false, InvoiceBeforePO: false, SuplrPOCount24h: 1, SuplrPOCount7d: 2,
	BuyerSupplierSharePct: "100.00", CreatorPostedGR: false, RuleClassification: "AVALIAR_JEV"
};

// Resposta 200 no formato documentado (jev-api.md), com as chaves da POC
const FIXTURE_200 = {
	id: "gen-dec-abc",
	model: "typesafe/jev-1.13-20260917",
	provider: "TypeSafe",
	answers: {
		fornecedor_ficticio: { type: "noul", noul: 0.04 },
		desvio_pagamento: { type: "noul", noul: 0.123456 },
		sobrepreco: { type: "noul", noul: 0.96 },
		fracionamento: { type: "noul", noul: 0.31 },
		fraude_interna: { type: "noul", noul: 0.00004 },
		atipicidade: {
			type: "score", score: 1.99, confidence: 0.99,
			probabilities: { 0: 0, 1: 0.01, 2: 0.99, 3: 0, 4: 0 },
			legend: { 0: "Typical", 1: "Slightly unusual", 2: "Unusual", 3: "Highly unusual", 4: "Extremely atypical" }
		},
		acao: { type: "choice", choice: "aprovacao", confidence: 0.75, probabilities: { liberar: 0.16, aprovacao: 0.84, bloquear: 0 } }
	},
	usage: { input_tokens: 476, output_tokens: 70, cost: 0.000019992 }
};

function clone(o) {
	return JSON.parse(JSON.stringify(o));
}

test("buildRequest: sem identificadores, state em ingles agrupado, sem model", () => {
	const req = JevClient.buildRequest(PO_1403);
	const s = JSON.stringify(req);
	for (const proibido of ["SupplierName", "Domestic BR", "14300001", "MVADEARAUJOM", "4500001403", "CreatedByUser"]) {
		assert.ok(!s.includes(proibido), "vazou: " + proibido);
	}
	assert.deepStrictEqual(Object.keys(req), ["state", "questions"]);
	assert.deepStrictEqual(Object.keys(req.state), ["supplier", "order", "velocity", "buyer", "baseline"]);
	for (const grupo of Object.values(req.state)) {
		for (const k of Object.keys(grupo)) assert.match(k, /^[a-z0-9_]+$/, "snake_case: " + k);
	}
	assert.strictEqual(req.state.order.price_vs_info_record, "10_pct_below");
	// 1 pedido anterior < MIN_PEDIDOS_HISTORICO (3): numero cru mantido, rotulo nao comparavel
	assert.strictEqual(JevClient.MIN_PEDIDOS_HISTORICO, 3);
	assert.strictEqual(req.state.order.amount_vs_supplier_average_ratio, 99);
	assert.strictEqual(req.state.order.amount_vs_supplier_average, "insufficient_history");
	assert.strictEqual(req.state.order.amount_deviation, "insufficient_history");
	assert.strictEqual(req.state.buyer.supplier_share_of_buyer_purchases_pct, 100);
	assert.strictEqual(req.state.buyer.supplier_share_of_buyer_purchases, "insufficient_history");
	assert.strictEqual(req.state.order.material_never_bought_from_supplier, true, "X -> true");
	assert.strictEqual(req.state.supplier.last_bank_or_address_change, "none_in_last_30_days");
});

test("com historico suficiente os rotulos voltam a comparar", () => {
	const st = JevClient.buildRequest(Object.assign({}, PO_1403, { SuplrHistPOCount: 3, AmountZScore: "2.5" })).state;
	assert.strictEqual(st.order.amount_vs_supplier_average, "99x_reference");
	assert.strictEqual(st.order.amount_deviation, "2_to_3_std_dev_above");
	assert.strictEqual(st.buyer.supplier_share_of_buyer_purchases, "over_80_pct");
	const st2 = JevClient.buildRequest(Object.assign({}, PO_1403, { SuplrHistPOCount: 2 })).state;
	assert.strictEqual(st2.order.amount_vs_supplier_average, "insufficient_history");
});

test("criterios dizem que insufficient_history nao e desvio; acao e so sinal", () => {
	const q = JevClient.buildRequest(PO_1403).questions;
	assert.match(JSON.stringify(q.atipicidade), /insufficient_history[^"]*NOT a deviation/);
	assert.match(JSON.stringify(q.fraude_interna.criteria.false), /insufficient_history is not a signal/);
});

test("rotulos de razao", () => {
	assert.strictEqual(JevClient.rotuloRazao("1.2"), "20_pct_above");
	assert.strictEqual(JevClient.rotuloRazao(1.03), "in_line");
	assert.strictEqual(JevClient.rotuloRazao(0), "not_comparable");
	assert.strictEqual(JevClient.rotuloRazao(0.85), "15_pct_below");
	assert.strictEqual(JevClient.rotuloRazao(3.5), "3.5x_reference");
});

test("perguntas: 7 chaves, tipos e criterios conforme o contrato", () => {
	const q = JevClient.buildRequest(PO_1403).questions;
	assert.deepStrictEqual(Object.keys(q), ["fornecedor_ficticio", "desvio_pagamento", "sobrepreco", "fracionamento", "fraude_interna", "atipicidade", "acao"]);
	for (const k of ["fornecedor_ficticio", "desvio_pagamento", "sobrepreco", "fracionamento", "fraude_interna"]) {
		assert.strictEqual(q[k].type, "noul");
		assert.deepStrictEqual(Object.keys(q[k].criteria).sort(), ["false", "true"]);
	}
	assert.strictEqual(q.atipicidade.type, "score");
	assert.strictEqual(q.atipicidade.criteria.length, 5);
	assert.strictEqual(q.acao.type, "choice");
	assert.deepStrictEqual(Object.keys(q.acao.criteria), ["liberar", "aprovacao", "bloquear"]);
	// sem acentos/portugues nos textos (instructions/criteria em ingles)
	assert.ok(!/[À-ÿ]/.test(JSON.stringify(q)));
});

test("toda referencia com crase aponta para um campo existente do state", () => {
	const req = JevClient.buildRequest(PO_1403);
	const refs = JSON.stringify(req.questions).match(/`[^`]+`/g) || [];
	assert.ok(refs.length > 10);
	for (const r of refs) {
		const caminho = r.slice(1, -1).split(".");
		let v = req.state;
		for (const p of caminho) v = v && v[p];
		assert.notStrictEqual(v, undefined, "campo inexistente: " + r);
	}
});

test("parseResponse: mapeamento da fixture documentada", () => {
	const p = JevClient.parseResponse(FIXTURE_200);
	assert.deepStrictEqual(p, {
		JevDisponivel: true,
		ProbFornecedorFicticio: "0.0400",
		ProbDesvioPagamento: "0.1235",
		ProbSobrepreco: "0.9600",
		ProbFracionamento: "0.3100",
		ProbFraudeInterna: "0.0000",
		Atipicidade: 3, // round(1.99) + 1
		JevAcaoSugerida: "APROVACAO",
		JevProbLiberar: "0.1600",
		JevProbAprovacao: "0.8400",
		JevProbBloquear: "0.0000",
		JevModeloVersao: "typesafe/jev-1.13-20260917"
	});
	assert.strictEqual(JevClient.extrairCusto(FIXTURE_200), 0.000019992);
});

test("parseResponse: qualquer desvio de forma e erro (nunca default)", () => {
	const casos = [
		(j) => delete j.model,
		(j) => delete j.answers,
		(j) => delete j.answers.sobrepreco,
		(j) => (j.answers.sobrepreco.type = "choice"),
		(j) => (j.answers.sobrepreco.noul = 1.2),
		(j) => (j.answers.sobrepreco.noul = "0.5"),
		(j) => (j.answers.atipicidade.type = "noul"),
		(j) => (j.answers.atipicidade.score = 4.6), // round -> 5 -> 6 fora de 1..5
		(j) => delete j.answers.atipicidade.score,
		(j) => (j.answers.acao.choice = "aprovar"),
		(j) => delete j.answers.acao.probabilities,
		(j) => delete j.answers.acao.probabilities.bloquear
	];
	casos.forEach((mut, i) => {
		const j = clone(FIXTURE_200);
		mut(j);
		assert.throws(() => JevClient.parseResponse(j), /RESPOSTA_INVALIDA/, "caso " + i);
	});
});

test("simulador fala o formato real e e deterministico (4500001403 -> APROVACAO)", () => {
	const corpo = Object.assign({ model: "typesafe/jev-1.13" }, JevClient.buildRequest(PO_1403));
	const a = simulate(corpo), b = simulate(corpo);
	assert.deepStrictEqual(a, b);
	assert.strictEqual(a.status, 200);
	assert.strictEqual(a.body.answers.atipicidade.type, "score");
	assert.deepStrictEqual(Object.keys(a.body.answers.atipicidade.probabilities), ["0", "1", "2", "3", "4"]);
	const p = JevClient.parseResponse(a.body);
	assert.strictEqual(p.ProbFracionamento, "0.2800");
	// participacao 100% com historico insuficiente nao pesa em fraude interna; atipicidade so pelo material novo
	assert.strictEqual(p.ProbFraudeInterna, "0.0200");
	assert.strictEqual(p.Atipicidade, 2);
	assert.strictEqual(p.JevAcaoSugerida, "APROVACAO");
	assert.ok(p.Atipicidade >= 1 && p.Atipicidade <= 5);
	assert.strictEqual(simulate({}).status, 400);
	assert.ok(simulate({}).body.error.code === 400);
});

test("sinais do state dirigem as probabilidades do simulador", () => {
	const r = (extra) => simulate(JevClient.buildRequest(Object.assign({}, PO_1403, extra))).body.answers;
	assert.ok(r({ MaxPriceToInfoRecordRatio: "1.4" }).sobrepreco.noul > 0.9);
	assert.ok(r({ SharedBankAccount: true, SharedBankOtherCount: 6 }).fornecedor_ficticio.noul > 0.7);
	assert.ok(r({ CreatorPostedGR: true, InvoiceBeforePO: true }).fraude_interna.noul > 0.6); // 0,67: participacao 100% nao soma (historico insuficiente)
	assert.ok(r({ SuplrPOCount7d: 0, SuplrPOCount24h: 0 }).fracionamento.noul < 0.1);
});

test("avaliar: sucesso devolve params e custo; POST em /jev/decisions", async () => {
	let url;
	const r = await JevClient.avaliar(PO_1403, { fetch: async (u) => { url = u; return { ok: true, json: async () => FIXTURE_200 }; } });
	assert.strictEqual(url, "/jev/decisions");
	assert.strictEqual(r.ok, true);
	assert.strictEqual(r.custoUsd, 0.000019992);
});

test("avaliar: HTTP 4xx/5xx, forma invalida e timeout viram INDISPONIVEL", async () => {
	for (const st of [400, 401, 402, 429, 503, 529]) {
		const r = await JevClient.avaliar(PO_1403, { fetch: async () => ({ ok: false, status: st, json: async () => ({ error: { code: st, message: "x" } }) }) });
		assert.deepStrictEqual([r.ok, r.motivo], [false, "HTTP_" + st]);
	}
	assert.strictEqual(JevClient.parametrosIndisponivel("INDISPONIVEL:HTTP_402").JevModeloVersao, "INDISPONIVEL:HTTP_402");

	const inv = await JevClient.avaliar(PO_1403, { fetch: async () => ({ ok: true, json: async () => ({ model: "m", answers: {} }) }) });
	assert.deepStrictEqual([inv.ok, inv.motivo], [false, "RESPOSTA_INVALIDA"]);
	assert.ok(("INDISPONIVEL:" + inv.motivo).length <= 30);

	const lento = (u, o) => new Promise((res, rej) => o.signal.addEventListener("abort", () => rej(Object.assign(new Error("abort"), { name: "AbortError" }))));
	const t = await JevClient.avaliar(PO_1403, { fetch: lento, timeoutMs: 50 });
	assert.deepStrictEqual([t.ok, t.motivo], [false, "TIMEOUT"]);

	const rede = await JevClient.avaliar(PO_1403, { fetch: async () => { throw new TypeError("Failed to fetch"); } });
	assert.strictEqual(rede.motivo, "ERRO_REDE");
});

test("limitador respeita no maximo 3 simultaneas", async () => {
	const lim = JevClient.createLimiter(3);
	let ativos = 0, pico = 0;
	await Promise.all(Array.from({ length: 10 }, () => lim.run(async () => {
		ativos++; pico = Math.max(pico, ativos);
		await new Promise((r) => setTimeout(r, 10));
		ativos--;
	})));
	assert.strictEqual(pico, 3);
	assert.strictEqual(JevClient.TIMEOUT_MS, 1500);
});

test("plano do simulador: forcar timeout/erro", () => {
	assert.ok(plano("timeout").latenciaMs > 1500);
	assert.strictEqual(plano("erro").tipo, "erro");
	assert.strictEqual(plano(undefined, () => 0.01).tipo, "timeout");
	assert.strictEqual(plano(undefined, () => 0.9).tipo, "ok");
});
