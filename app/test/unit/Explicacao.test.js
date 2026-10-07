// Testes da logica de explicacao (secao "Jev (modo sombra)") + chaves do i18n.
"use strict";

const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const fs = require("node:fs");

const mods = {};
global.sap = { ui: { define: (deps, f) => { mods.__last = f.apply(null, deps.map((d) => mods[d])); } } };
require(path.join(__dirname, "..", "..", "webapp", "jev", "JevClient.js"));
mods["zpocjev/antifraude/jev/JevClient"] = mods.__last;
require(path.join(__dirname, "..", "..", "webapp", "jev", "Explicacao.js"));
const E = mods.__last;

const I18N = Object.fromEntries(
	fs.readFileSync(path.join(__dirname, "..", "..", "webapp", "i18n", "i18n.properties"), "utf8")
		.split(/\r?\n/).filter((l) => l && !l.startsWith("#") && l.includes("="))
		.map((l) => [l.slice(0, l.indexOf("=")), l.slice(l.indexOf("=") + 1)])
);

// Avaliacao 4500001403 (APROVACAO por FRACIONAMENTO 0,36), decimais como o V4 entrega (string)
const AVAL_1403 = {
	Classificacao: "APROVACAO", ChaveRiscoMax: "FRACIONAMENTO", RiscoMax: "0.3600",
	LimiarAprovacaoUsado: "0.2000", LimiarBloqueioUsado: "0.6000", JevDisponivel: true,
	ProbFornecedorFicticio: "0.0200", ProbDesvioPagamento: "0.0200", ProbSobrepreco: "0.0300",
	ProbFracionamento: "0.3600", ProbFraudeInterna: "0.0200", Atipicidade: 3,
	JevAcaoSugerida: "APROVACAO", JevProbLiberar: "0.1600", JevProbAprovacao: "0.8400", JevProbBloquear: "0.0000",
	JevModeloVersao: "typesafe/jev-1.13-20260917"
};

test("veredito por classificacao: texto e estado", () => {
	const casos = {
		LIBERA: ["vereditoLibera", "Success"],
		APROVACAO: ["vereditoAprovacao", "Warning"],
		BLOQUEIA: ["vereditoBloqueia", "Error"],
		BLOQUEIO_REGRA: ["vereditoBloqueioRegra", "Error"],
		INDISPONIVEL: ["vereditoIndisponivel", "Information"]
	};
	for (const [c, [k, st]] of Object.entries(casos)) {
		const v = E.veredito(c);
		assert.deepStrictEqual([v.titulo, v.estado], [k, st], c);
		assert.ok(I18N[v.titulo] && I18N[v.etiqueta], "i18n " + c);
	}
	assert.strictEqual(I18N.vereditoAprovacao, "Recomendado revisar antes de aprovar");
	assert.strictEqual(E.veredito("XYZ").titulo, "vereditoIndisponivel");
});

test("motivo amigavel de INDISPONIVEL", () => {
	const m = (s) => E.motivoIndisponivel(s).key;
	assert.strictEqual(m("INDISPONIVEL:TIMEOUT"), "motivoTimeout");
	assert.strictEqual(m("INDISPONIVEL:HTTP_402"), "motivoSemCreditos");
	assert.strictEqual(m("INDISPONIVEL:HTTP_401"), "motivoAcesso");
	assert.strictEqual(m("INDISPONIVEL:HTTP_429"), "motivoLimite");
	assert.strictEqual(m("INDISPONIVEL:HTTP_503"), "motivoServicoFora");
	assert.strictEqual(m("INDISPONIVEL:HTTP_400"), "motivoPedidoRecusado");
	assert.strictEqual(m("INDISPONIVEL:ERRO_REDE"), "motivoRede");
	assert.strictEqual(m("INDISPONIVEL:RESPOSTA_INVALIDA"), "motivoRespostaInvalida");
	assert.strictEqual(m(""), "motivoDesconhecido");
});

test("cor das barras pelos limiares gravados", () => {
	assert.strictEqual(E.estadoBarra(0.19, 0.2, 0.6), "Success");
	assert.strictEqual(E.estadoBarra(0.2, 0.2, 0.6), "Warning");
	assert.strictEqual(E.estadoBarra(0.6, 0.2, 0.6), "Warning");
	assert.strictEqual(E.estadoBarra(0.61, 0.2, 0.6), "Error");
	// limiares diferentes gravados na avaliacao mudam a cor
	const r = E.riscos(Object.assign({}, AVAL_1403, { LimiarAprovacaoUsado: "0.4000", LimiarBloqueioUsado: "0.8000" }));
	assert.strictEqual(r[0].estado, "Success");
	assert.strictEqual(E.legenda({ LimiarAprovacaoUsado: "0.4000", LimiarBloqueioUsado: "0.8000" }).args.join(), "40,80");
});

test("riscos ordenados do maior para o menor, em %", () => {
	const r = E.riscos(AVAL_1403);
	assert.deepStrictEqual(r.map((x) => x.chave), ["FRACIONAMENTO", "SOBREPRECO", "FORNECEDOR_FICTICIO", "DESVIO_PAGAMENTO", "FRAUDE_INTERNA"]);
	assert.deepStrictEqual([r[0].pct, r[0].estado, r[1].estado], [36, "Warning", "Success"]);
	for (const x of r) assert.ok(I18N[x.rotulo], x.rotulo);
	assert.strictEqual(E.legenda(AVAL_1403).args.join(), "20,60");
	// BLOQUEIA com duas chaves acima de 0,60
	const b = E.riscos(Object.assign({}, AVAL_1403, { Classificacao: "BLOQUEIA", ProbSobrepreco: "0.9100", ProbFornecedorFicticio: "0.7200" }));
	assert.deepStrictEqual(b.slice(0, 2).map((x) => [x.chave, x.estado]), [["SOBREPRECO", "Error"], ["FORNECEDOR_FICTICIO", "Error"]]);
});

test("por que e sugestao", () => {
	const p = E.porQue(AVAL_1403);
	assert.deepStrictEqual([p.key, p.rotulo, p.args[1]], ["porQuePrincipal", "riscoFracionamento", 36]);
	assert.strictEqual(E.porQue(Object.assign({}, AVAL_1403, { Classificacao: "LIBERA", RiscoMax: "0.1000" })).key, "porQueLibera");
	assert.strictEqual(E.porQue({ Classificacao: "BLOQUEIO_REGRA", ChaveRiscoMax: "FORNECEDOR_BLOQUEADO" }), null);
	assert.strictEqual(E.porQue({ Classificacao: "INDISPONIVEL" }), null);
	assert.deepStrictEqual(E.sugestao(AVAL_1403), { rotulo: "sugestaoAprovacao", pct: 84 });
	assert.strictEqual(E.sugestao({ JevDisponivel: false, JevAcaoSugerida: "" }), null);
	assert.strictEqual(E.temRiscos({ Classificacao: "INDISPONIVEL" }), false);
});

test("sinais: 4500001403 acende so pedidos recentes e material novo", () => {
	const s = E.sinais({
		SupplierAgeDays: 1266, SupplierCreatorIsPOCreator: false, SharedBankAccount: false, SharedBankOtherCount: 0,
		MasterDataChanges30d: 0, MaxPriceToInfoRecordRatio: "0.9000", MaxPriceToMaterialAvgRatio: "0.0000",
		SuplrPOCount7d: 2, SuplrPOCount24h: 1, MaterialNewForSupplier: "X", PaymentTermsDiverge: false,
		InvoiceBeforePO: false, CreatorPostedGR: false, AmountToSuplrAvgRatio: "99.0000", SuplrHistPOCount: 1
	});
	assert.deepStrictEqual(s.map((x) => x.key), ["sinalPedidos24h1", "sinalMaterialNovo"]);
	assert.deepStrictEqual(s[0].args, [1, 2]);
});

test("sinais: todos acesos, plurais e historico", () => {
	const s = E.sinais({
		SupplierAgeDays: 30, SupplierCreatorIsPOCreator: true, SharedBankAccount: true, SharedBankOtherCount: 6,
		MasterDataChanges30d: 2, MaxPriceToInfoRecordRatio: "1.2000", MaxPriceToMaterialAvgRatio: "1.0400",
		SuplrPOCount7d: 3, SuplrPOCount24h: 0, MaterialNewForSupplier: "", PaymentTermsDiverge: true,
		InvoiceBeforePO: true, CreatorPostedGR: true, AmountToSuplrAvgRatio: "2.4600", SuplrHistPOCount: 5
	});
	assert.deepStrictEqual(s.map((x) => x.key), [
		"sinalFornecedorNovo", "sinalMesmaPessoaFornecedor", "sinalContaCompartilhada", "sinalAlteracoesCadastro",
		"sinalPrecoRegistroInfo", "sinalPedidos7d", "sinalCondicaoPagamento", "sinalFaturaAntes", "sinalCriadorEntrada", "sinalValorMedia"
	]);
	assert.deepStrictEqual(s.find((x) => x.key === "sinalPrecoRegistroInfo").args, [20]);
	assert.deepStrictEqual(s.find((x) => x.key === "sinalValorMedia").args, ["2,5"]);
	// valor vs media some com historico insuficiente (mesma regra do JevClient)
	assert.ok(!E.sinais({ AmountToSuplrAvgRatio: "9", SuplrHistPOCount: 2 }).some((x) => x.key === "sinalValorMedia"));
	assert.deepStrictEqual(E.sinais({}), []);
	assert.strictEqual(E.sinais({ SupplierAgeDays: 0 })[0].key, "sinalFornecedorNovo0");
	assert.strictEqual(E.sinais({ SupplierAgeDays: 1 })[0].key, "sinalFornecedorNovo1");
	for (const x of s) assert.ok(I18N[x.key], "i18n " + x.key);
});

test("i18n: textos visiveis sem jargao tecnico", () => {
	const visiveis = Object.entries(I18N).filter(([k]) => /^(veredito|etiqueta|motivo[A-Z]|porQue|risco|sinal|rodape|sugestao|vazio|legenda|msg)/.test(k));
	for (const [k, v] of visiveis) {
		assert.ok(!/BLOQUEIO_REGRA|INDISPONIVEL|AVALIADO|noul|\bLIBERA\b/.test(v), "jargao em " + k + ": " + v);
	}
	// todas as chaves usadas pelo modulo existem
	for (const c of ["LIBERA", "APROVACAO", "BLOQUEIA", "BLOQUEIO_REGRA", "INDISPONIVEL"]) assert.ok(I18N[E.veredito(c).etiqueta]);
	for (const k of ["legendaRiscos", "porQuePrincipal", "porQueLibera", "rodapeAvaliado", "rodapeAtipicidade", "rodapeSugestao", "sinaisNenhum", "vazioTitulo", "vazioDescricao"]) assert.ok(I18N[k], k);
});
