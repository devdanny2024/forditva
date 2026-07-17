import 'package:flutter_test/flutter_test.dart';
import 'package:forditva/services/gemini_cost.dart';

void main() {
  group('geminiWiuCost', () {
    test('zero tokens cost nothing', () {
      expect(geminiWiuCost(promptTokens: 0, outputTokens: 0), 0);
    });

    test('applies the +30% fee margin on top of the real cost', () {
      // Markus's own worked example: 300 in / 300 out.
      const realCost = 300 * 0.00012 + 300 * 0.001; // 0.336 WIU
      expect(
        geminiWiuCost(promptTokens: 300, outputTokens: 300),
        closeTo(realCost * 1.30, 1e-9),
      );
    });

    test('billed cost is exactly feeMargin times the raw cost', () {
      const rawInput = 1000 * 0.00012;
      const rawOutput = 500 * 0.001;
      expect(
        geminiWiuCost(promptTokens: 1000, outputTokens: 500),
        closeTo((rawInput + rawOutput) * feeMargin, 1e-9),
      );
    });
  });
}
