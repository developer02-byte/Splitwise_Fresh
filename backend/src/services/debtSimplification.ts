// Debt Simplification Algorithm
// Minimizes total transactions needed to settle all debts in a group.
// E.g., A owes B $10, B owes C $10 -> Simplified: A owes C $10.

export interface Debt {
  fromUserId: number;
  toUserId: number;
  amountCents: number;
}

/**
 * Simplifies a list of transactions into the minimum possible number of payments.
 * @param transactions - List of raw debts between users
 * @param threshold - (Optional) Minimum amount in cents below which a debt is ignored
 */
export function simplifyDebts(transactions: Debt[], threshold: number = 0): Debt[] {
  // 1. Calculate net balances for every user
  const netBalances = new Map<number, number>();

  for (const t of transactions) {
    if (t.amountCents === 0) continue;
    netBalances.set(t.fromUserId, (netBalances.get(t.fromUserId) || 0) - t.amountCents);
    netBalances.set(t.toUserId, (netBalances.get(t.toUserId) || 0) + t.amountCents);
  }

  // 2. Filter out balances below the threshold
  // This helps avoid tiny 1-cent transfers in large groups
  const activeBalances = Array.from(netBalances.entries())
    .filter(([_, balance]) => Math.abs(balance) > threshold);

  const debtors = activeBalances
    .filter(([_, balance]) => balance < 0)
    .map(b => [b[0], b[1]] as [number, number])
    .sort((a, b) => a[1] - b[1]);

  const creditors = activeBalances
    .filter(([_, balance]) => balance > 0)
    .map(b => [b[0], b[1]] as [number, number])
    .sort((a, b) => b[1] - a[1]);

  const simplifiedTransactions: Debt[] = [];
  
  let i = 0; // Debtors pointer
  let j = 0; // Creditors pointer

  // 3. Greedy settling algorithm
  while (i < debtors.length && j < creditors.length) {
    const debtorId = debtors[i][0];
    const debtorDebt = Math.abs(debtors[i][1]);
    
    const creditorId = creditors[j][0];
    const creditorCredit = creditors[j][1];

    const settleAmount = Math.round(Math.min(debtorDebt, creditorCredit));
    if (settleAmount > 0) {
      simplifiedTransactions.push({
        fromUserId: debtorId,
        toUserId: creditorId,
        amountCents: settleAmount
      });
    }

    debtors[i][1] += settleAmount; 
    creditors[j][1] -= settleAmount;

    if (Math.abs(debtors[i][1]) < 0.01) i++;
    if (Math.abs(creditors[j][1]) < 0.01) j++;
  }

  return simplifiedTransactions;
}
