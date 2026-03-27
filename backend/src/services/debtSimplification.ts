// Debt Simplification Algorithm
// Minimizes total transactions needed to settle all debts in a group.
// E.g., A owes B $10, B owes C $10 -> Simplified: A owes C $10.

export interface Debt {
  fromUserId: number;
  toUserId: number;
  amountCents: number;
}

export function simplifyDebts(transactions: Debt[]): Debt[] {
  // 1. Calculate net balances for every user
  const netBalances = new Map<number, number>();

  for (const t of transactions) {
    if (t.amountCents === 0) continue;
    
    // User sending money (-)
    netBalances.set(t.fromUserId, (netBalances.get(t.fromUserId) || 0) - t.amountCents);
    
    // User receiving money (+)
    netBalances.set(t.toUserId, (netBalances.get(t.toUserId) || 0) + t.amountCents);
  }

  // 2. Separate into Debtors (-) and Creditors (+)
  const debtors = Array.from(netBalances.entries())
    .filter(([_, balance]) => balance < 0)
    .sort((a, b) => a[1] - b[1]); // Sort most negative first (largest debtor)

  const creditors = Array.from(netBalances.entries())
    .filter(([_, balance]) => balance > 0)
    .sort((a, b) => b[1] - a[1]); // Sort most positive first (largest creditor)

  const simplifiedTransactions: Debt[] = [];
  
  let i = 0; // Debtors pointer
  let j = 0; // Creditors pointer

  // 3. Greedy settling algorithm
  while (i < debtors.length && j < creditors.length) {
    const debtorId = debtors[i][0];
    const debtorDebt = Math.abs(debtors[i][1]);
    
    const creditorId = creditors[j][0];
    const creditorCredit = creditors[j][1];

    // The settlement amount is the minimum of what debtor owes and creditor needs
    const settleAmount = Math.min(debtorDebt, creditorCredit);
    
    // Record the explicit transaction
    simplifiedTransactions.push({
      fromUserId: debtorId,
      toUserId: creditorId,
      amountCents: settleAmount
    });

    // Update remaining balances
    debtors[i][1] += settleAmount; // moves toward 0
    creditors[j][1] -= settleAmount;

    // Advance pointers if fully settled
    if (debtors[i][1] === 0) i++;
    if (creditors[j][1] === 0) j++;
  }

  return simplifiedTransactions;
}
