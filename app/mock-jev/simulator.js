/**
 * SIMULADOR do Jev (somente desenvolvimento/demonstracao).
 *
 * Fala o MESMO formato do Jev real (POST /api/alpha/decisions do OpenRouter, ver jev-api.md):
 *   200 -> { id, model, provider, answers: { <chave>: noul|score|choice }, usage }
 *   erro -> { error: { code, message } }
 * As probabilidades sao DETERMINISTICAS a partir do `state` montado por JevClient.buildRequest
 * (mesmo state -> mesma resposta). A latencia e aleatoria e as vezes estoura o timeout do
 * front (1500 ms), para demonstrar a falha segura (INDISPONIVEL).
 */
"use strict";

const MODELO = "typesafe/jev-1.13-simulador";

function clamp(n, lo, hi) {
	return Math.max(lo, Math.min(hi, n));
}
function r4(n) {
	return Math.round(n * 10000) / 10000;
}
function num(v) {
	const n = typeof v === "number" ? v : parseFloat(v);
	return Number.isFinite(n) ? n : 0;
}

function probabilidadesBrutas(state) {
	const s = (state && state.supplier) || {};
	const o = (state && state.order) || {};
	const v = (state && state.velocity) || {};
	const b = (state && state.buyer) || {};

	const razaoPreco = Math.max(num(o.price_vs_info_record_ratio), num(o.price_vs_material_history_ratio));
	let sobrepreco = 0.03 + (razaoPreco > 1 ? (razaoPreco - 1) * 2.5 : 0) + (o.amount_deviation !== "insufficient_history" && num(o.amount_z_score) > 2 ? 0.1 : 0);

	let ficticio = 0.02;
	if (s.bank_account_shared_with_other_suppliers) ficticio += 0.5 + 0.05 * Math.min(num(s.other_suppliers_with_same_bank_account), 5);
	const idade = num(s.registration_age_days);
	if (idade < 90) ficticio += 0.25;
	else if (idade < 365) ficticio += 0.1;
	if (s.created_by_same_user_as_order) ficticio += 0.15;

	let desvio = 0.02 + Math.min(num(s.bank_or_address_changes_last_30_days) * 0.12, 0.5);
	if (s.last_bank_or_address_change === "within_7_days_of_order") desvio += 0.2;
	if (o.payment_terms_differ_from_supplier_default) desvio += 0.15;
	if (s.bank_account_shared_with_other_suppliers) desvio += 0.15;

	let fracionamento =
		0.02 + Math.min(num(v.other_orders_same_supplier_last_7_days) * 0.08, 0.6) + Math.min(num(v.other_orders_same_supplier_last_24h) * 0.1, 0.3);
	const razaoQtd = num(o.quantity_vs_history_ratio);
	if (razaoQtd > 0 && razaoQtd < 0.5) fracionamento += 0.1;

	let interna = 0.02;
	if (b.buyer_posted_goods_receipt_for_this_order) interna += 0.3;
	if (o.invoice_dated_before_order_creation) interna += 0.35;
	if (s.created_by_same_user_as_order) interna += 0.2;
	if (b.supplier_share_of_buyer_purchases !== "insufficient_history" && num(b.supplier_share_of_buyer_purchases_pct) > 80) interna += 0.1;

	let sinais = 0;
	// insufficient_history nao e desvio (mesma regra dada ao Jev real)
	if (o.amount_vs_supplier_average !== "insufficient_history" && num(o.amount_vs_supplier_average_ratio) > 3) sinais++;
	if (o.amount_deviation !== "insufficient_history" && Math.abs(num(o.amount_z_score)) > 2) sinais++;
	if (razaoPreco > 1.2) sinais++;
	if (o.material_never_bought_from_supplier) sinais++;
	if (num(v.other_orders_same_supplier_last_7_days) >= 3) sinais++;
	if (s.bank_account_shared_with_other_suppliers || num(s.bank_or_address_changes_last_30_days) > 0) sinais++;

	return {
		noul: {
			fornecedor_ficticio: r4(clamp(ficticio, 0.01, 0.97)),
			desvio_pagamento: r4(clamp(desvio, 0.01, 0.97)),
			sobrepreco: r4(clamp(sobrepreco, 0.01, 0.97)),
			fracionamento: r4(clamp(fracionamento, 0.01, 0.97)),
			fraude_interna: r4(clamp(interna, 0.01, 0.97))
		},
		indiceAtipicidade: clamp(sinais, 0, 4)
	};
}

function respostaScore(iCentro, nNiveis, criteria) {
	// distribuicao concentrada no nivel iCentro (0..n-1)
	const pesos = Array.from({ length: nNiveis }, (_, i) => Math.exp(-2.5 * Math.abs(i - iCentro)));
	const tot = pesos.reduce((a, b) => a + b, 0);
	const probs = {};
	const legend = {};
	let score = 0;
	pesos.forEach((w, i) => {
		const p = r4(w / tot);
		probs[String(i)] = p;
		score += i * p;
		const c = Array.isArray(criteria) ? criteria[i] : undefined;
		legend[String(i)] = typeof c === "string" ? c : (c && c.what) || "level " + i;
	});
	const pMax = Math.max(...Object.values(probs));
	return { type: "score", score: r4(score), confidence: r4((pMax - 1 / nNiveis) / (1 - 1 / nNiveis)), probabilities: probs, legend };
}

function respostaChoice(max, opcoes) {
	const z = { liberar: Math.exp(-6 * max + 1.2), aprovacao: Math.exp(-6 * Math.abs(max - 0.4) + 0.6), bloquear: Math.exp(6 * max - 4.2) };
	const tot = z.liberar + z.aprovacao + z.bloquear;
	const probabilities = { liberar: r4(z.liberar / tot), aprovacao: r4(z.aprovacao / tot) };
	probabilities.bloquear = r4(Math.max(0, 1 - probabilities.liberar - probabilities.aprovacao));
	// politica do simulador: mesma faixa dos limiares ABAP (0,20 / 0,60)
	const choice = max < 0.2 ? "liberar" : max <= 0.6 ? "aprovacao" : "bloquear";
	const n = opcoes.length;
	const pMax = Math.max(...Object.values(probabilities));
	return { type: "choice", choice, confidence: r4((pMax - 1 / n) / (1 - 1 / n)), probabilities };
}

/**
 * Responde a um corpo { model, state, questions } como o Jev real.
 * Responde so as chaves presentes em `questions`, respeitando o `type` de cada uma.
 * @returns {{status:number, body:object}}
 */
function simulate(body) {
	if (!body || typeof body !== "object" || !body.state || !body.questions || typeof body.questions !== "object") {
		return { status: 400, body: { error: { code: 400, message: "simulador: state e questions sao obrigatorios" } } };
	}
	const brutas = probabilidadesBrutas(body.state);
	const max = Math.max(...Object.values(brutas.noul));
	const answers = {};
	for (const [k, q] of Object.entries(body.questions)) {
		const tipo = q && q.type;
		if (tipo === "noul") {
			answers[k] = { type: "noul", noul: Object.prototype.hasOwnProperty.call(brutas.noul, k) ? brutas.noul[k] : 0.5 };
		} else if (tipo === "score") {
			const n = Array.isArray(q.criteria) ? q.criteria.length : 0;
			if (n < 2 || n > 10) return { status: 400, body: { error: { code: 400, message: `simulador: score '${k}' precisa de 2 a 10 niveis` } } };
			answers[k] = respostaScore(Math.min(brutas.indiceAtipicidade, n - 1), n, q.criteria);
		} else if (tipo === "choice") {
			answers[k] = respostaChoice(max, Object.keys(q.criteria || {}));
		} else {
			return { status: 400, body: { error: { code: 400, message: `simulador: type invalido em '${k}'` } } };
		}
	}
	const tokens = Math.round(JSON.stringify(body).length / 4);
	return {
		status: 200,
		body: {
			id: "gen-dec-simulador",
			model: MODELO,
			provider: "Simulador local",
			answers,
			usage: { input_tokens: tokens, output_tokens: Object.keys(answers).length * 10, cost: 0 }
		}
	};
}

/**
 * Comportamento da chamada. forcar (header X-Jev-Sim): "timeout" | "erro" | "ok"; senao aleatorio:
 * ~15% estoura o timeout (2,0-3,0 s), ~5% HTTP 503, demais 80-1200 ms.
 */
function plano(forcar, rnd = Math.random) {
	if (forcar === "timeout") return { tipo: "timeout", latenciaMs: 2500 };
	if (forcar === "erro") return { tipo: "erro", latenciaMs: 100 };
	if (forcar === "ok") return { tipo: "ok", latenciaMs: 150 };
	const x = rnd();
	if (x < 0.15) return { tipo: "timeout", latenciaMs: 2000 + Math.floor(rnd() * 1000) };
	if (x < 0.2) return { tipo: "erro", latenciaMs: 50 + Math.floor(rnd() * 200) };
	return { tipo: "ok", latenciaMs: 80 + Math.floor(rnd() * 1120) };
}

const ERRO_503 = { error: { code: 503, message: "simulador: provedor indisponivel" } };

module.exports = { simulate, plano, MODELO, ERRO_503 };
