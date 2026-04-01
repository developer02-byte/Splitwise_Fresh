import { describe, expect, test } from 'vitest';
import { simplifyDebts, Debt } from '../src/services/debtSimplification';

describe('Debt Simplification Algorithm', () => {
  test('A owes B $10, B owes C $10 → A owes C $10 (chain reduction)', () => {
    const transactions: Debt[] = [
      { fromUserId: 1, toUserId: 2, amountCents: 1000 },
      { fromUserId: 2, toUserId: 3, amountCents: 1000 },
    ];
    
    const simplified = simplifyDebts(transactions);
    
    expect(simplified).toHaveLength(1);
    expect(simplified[0]).toEqual({
      fromUserId: 1,
      toUserId: 3,
      amountCents: 1000
    });
  });

  test('circular debt: A→B $10, B→C $10, C→A $10 → all settled', () => {
    const transactions: Debt[] = [
      { fromUserId: 1, toUserId: 2, amountCents: 1000 },
      { fromUserId: 2, toUserId: 3, amountCents: 1000 },
      { fromUserId: 3, toUserId: 1, amountCents: 1000 },
    ];
    
    const simplified = simplifyDebts(transactions);
    expect(simplified).toEqual([]);
    expect(simplified).toHaveLength(0);
  });

  test('complex graph with 4 people reduces to minimum transactions', () => {
    // A(1) owes B(2) $5
    // A(1) owes C(3) $5
    // B(2) owes D(4) $10
    // C(3) owes D(4) $10
    // Net:
    // A: -10
    // B: +5 - 10 = -5
    // C: +5 - 10 = -5
    // D: +20
    const transactions: Debt[] = [
      { fromUserId: 1, toUserId: 2, amountCents: 500 },
      { fromUserId: 1, toUserId: 3, amountCents: 500 },
      { fromUserId: 2, toUserId: 4, amountCents: 1000 },
      { fromUserId: 3, toUserId: 4, amountCents: 1000 },
    ];
    
    const simplified = simplifyDebts(transactions);
    
    // Minimum transactions should be 3: A->D, B->D, C->D
    expect(simplified.length).toBeLessThanOrEqual(3);
    
    const totalSentToD: number = simplified
      .filter(t => t.toUserId === 4)
      .reduce((sum, t) => sum + t.amountCents, 0);
      
    expect(totalSentToD).toBe(2000);
  });

  test('already minimal debts are not modified', () => {
    const transactions: Debt[] = [
      { fromUserId: 1, toUserId: 2, amountCents: 1500 },
      { fromUserId: 3, toUserId: 4, amountCents: 500 },
    ];
    
    const simplified = simplifyDebts(transactions);
    expect(simplified).toHaveLength(2);
    expect(simplified).toEqual(expect.arrayContaining([
      { fromUserId: 1, toUserId: 2, amountCents: 1500 },
      { fromUserId: 3, toUserId: 4, amountCents: 500 },
    ]));
  });

  test('empty debt graph returns empty', () => {
    expect(simplifyDebts([])).toEqual([]);
  });

  test('ignores transactions below threshold if specified', () => {
    // A owes B $10
    // C owes D 1 cent
    const transactions: Debt[] = [
      { fromUserId: 1, toUserId: 2, amountCents: 1000 },
      { fromUserId: 3, toUserId: 4, amountCents: 1 },
    ];
    
    // Ignore anything under and equal to 1 cent
    const simplified = simplifyDebts(transactions, 1);
    
    expect(simplified).toHaveLength(1);
    expect(simplified[0].toUserId).toBe(2);
    expect(simplified[0].fromUserId).toBe(1);
  });

  test('handles exact rounding and penny overlaps safely', () => {
    const transactions: Debt[] = [
      { fromUserId: 1, toUserId: 2, amountCents: 3333 },
      { fromUserId: 2, toUserId: 3, amountCents: 3334 },
    ];
    
    // A owes B 33.33, B owes C 33.34
    // Net: A (-3333), B (-1), C (+3334)
    const simplified = simplifyDebts(transactions);
    
    expect(simplified).toHaveLength(2);
    const amountToC = simplified.filter(t => t.toUserId === 3).reduce((acc, t) => acc + t.amountCents, 0);
    expect(amountToC).toBe(3334);
  });
});
