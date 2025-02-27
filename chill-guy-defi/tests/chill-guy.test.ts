import { describe, expect, it } from "vitest";

// Ensure simnet is properly initialized before running tests
const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1");

if (!address1) {
  throw new Error("Failed to retrieve wallet_1 account.");
}

describe("Simnet Initialization & Smart Contract Tests", () => {
  it("should initialize simnet successfully", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("should retrieve wallet_1 address", () => {
    expect(address1).toBeDefined();
  });

  // Example test for a read-only function call
  it("should execute a read-only function correctly", () => {
    const { result, success } = simnet.callReadOnlyFn(
      "counter",
      "get-count",
      [],
      address1
    );

    expect(success).toBe(true);
    expect(result).toBeDefined();
  });
});
