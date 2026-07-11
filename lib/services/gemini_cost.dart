/// Converts Gemini's real per-token pricing into WIU cost, at the same
/// $0.0025/WIU consumer rate used everywhere else (10,000 WIU = $25).
///
/// Real Gemini 2.5 Flash pricing: $0.30 per 1M input tokens, $2.50 per 1M
/// output tokens. The previous billing charged every token (input or output)
/// as 1 WIU flat, which overcharged input-heavy calls (like image bytes) by
/// roughly 8000x and output-heavy calls by roughly 1000x versus real cost
/// (Markus, 2026-07-11: "I want to earn nothing... if we reduce 1000 WIU
/// from the user, he needs to be getting $2.50 of real AI work for it").
/// This makes the WIU deducted, converted back to dollars at $0.0025/WIU,
/// equal the real Google cost.
double geminiWiuCost({required int promptTokens, required int outputTokens}) {
  const inputWiuPerToken = 0.00012; // (0.30 / 1e6) / 0.0025
  const outputWiuPerToken = 0.001; // (2.50 / 1e6) / 0.0025
  return promptTokens * inputWiuPerToken + outputTokens * outputWiuPerToken;
}
