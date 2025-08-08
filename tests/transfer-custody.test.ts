import { describe, it, expect, beforeEach, vi } from "vitest";

interface PendingTransfer {
  sender: string;
  receiver: string;
  initiatedAt: number;
}

interface TransferHistory {
  sender: string;
  receiver: string;
  transferTimestamp: number;
}

interface MockContract {
  admin: string;
  paused: boolean;
  productRegistry: string;
  pendingTransfers: Map<number, PendingTransfer>;
  transferHistory: Map<string, TransferHistory>;
  transferCount: Map<number, number>;
  isAdmin(caller: string): boolean;
  setPaused(caller: string, pause: boolean): { value: boolean } | { error: number };
  setProductRegistry(caller: string, registry: string): { value: boolean } | { error: number };
  initiateTransfer(caller: string, productId: number, receiver: string): { value: boolean } | { error: number };
  confirmTransfer(caller: string, productId: number): { value: number } | { error: number };
  cancelTransfer(caller: string, productId: number): { value: boolean } | { error: number };
  getPendingTransfer(productId: number): { value: PendingTransfer | undefined };
  getTransferHistory(productId: number, transferId: number): { value: TransferHistory | undefined };
  getTransferCount(productId: number): { value: number };
}

const mockProductRegistry = {
  getProductOwner: vi.fn(),
  nftTransfer: vi.fn(),
};

const mockContract: MockContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  productRegistry: "ST2CY5...",
  pendingTransfers: new Map(),
  transferHistory: new Map(),
  transferCount: new Map(),

  isAdmin(caller: string) {
    return caller === this.admin;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 200 };
    this.paused = pause;
    return { value: pause };
  },

  setProductRegistry(caller: string, registry: string) {
    if (!this.isAdmin(caller)) return { error: 200 };
    if (registry === "SP000000000000000000002Q6VF78") return { error: 203 };
    this.productRegistry = registry;
    return { value: true };
  },

  initiateTransfer(caller: string, productId: number, receiver: string) {
    if (this.paused) return { error: 204 };
    if (productId <= 0) return { error: 209 };
    if (!mockProductRegistry.getProductOwner(productId)) return { error: 201 };
    if (mockProductRegistry.getProductOwner(productId) !== caller) return { error: 202 };
    if (receiver === "SP000000000000000000002Q6VF78") return { error: 203 };
    if (this.pendingTransfers.has(productId)) return { error: 205 };
    this.pendingTransfers.set(productId, {
      sender: caller,
      receiver,
      initiatedAt: 100,
    });
    return { value: true };
  },

  confirmTransfer(caller: string, productId: number) {
    if (this.paused) return { error: 204 };
    if (productId <= 0) return { error: 209 };
    const transfer = this.pendingTransfers.get(productId);
    if (!transfer) return { error: 206 };
    if (transfer.receiver !== caller) return { error: 207 };
    if (!mockProductRegistry.getProductOwner(productId)) return { error: 201 };
    mockProductRegistry.nftTransfer(productId, transfer.sender, transfer.receiver);
    const currentCount = this.transferCount.get(productId) || 0;
    const newCount = currentCount + 1;
    this.transferHistory.set(`${productId}-${newCount}`, {
      sender: transfer.sender,
      receiver: transfer.receiver,
      transferTimestamp: 100,
    });
    this.transferCount.set(productId, newCount);
    this.pendingTransfers.delete(productId);
    return { value: newCount };
  },

  cancelTransfer(caller: string, productId: number) {
    if (this.paused) return { error: 204 };
    if (productId <= 0) return { error: 209 };
    const transfer = this.pendingTransfers.get(productId);
    if (!transfer) return { error: 206 };
    if (transfer.sender !== caller) return { error: 200 };
    this.pendingTransfers.delete(productId);
    return { value: true };
  },

  getPendingTransfer(productId: number) {
    return { value: this.pendingTransfers.get(productId) };
  },

  getTransferHistory(productId: number, transferId: number) {
    return { value: this.transferHistory.get(`${productId}-${transferId}`) };
  },

  getTransferCount(productId: number) {
    return { value: this.transferCount.get(productId) || 0 };
  },
};

describe("Transfer Custody Contract", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.productRegistry = "ST2CY5...";
    mockContract.pendingTransfers.clear();
    mockContract.transferHistory.clear();
    mockContract.transferCount.clear();
    vi.resetAllMocks();
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    mockProductRegistry.nftTransfer.mockReturnValue(true);
  });

  it("should allow owner to initiate transfer", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    const result = mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    expect(result).toEqual({ value: true });
    expect(mockContract.getPendingTransfer(1)).toEqual({
      value: { sender: "ST3NB...", receiver: "ST4RE...", initiatedAt: 100 },
    });
  });

  it("should prevent non-owner from initiating transfer", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    const result = mockContract.initiateTransfer("ST5PQ...", 1, "ST4RE...");
    expect(result).toEqual({ error: 202 });
  });

  it("should prevent initiating transfer to zero address", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    const result = mockContract.initiateTransfer(
      "ST3NB...",
      1,
      "SP000000000000000000002Q6VF78"
    );
    expect(result).toEqual({ error: 203 });
  });

  it("should prevent initiating transfer with invalid product ID", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    const result = mockContract.initiateTransfer("ST3NB...", 0, "ST4RE...");
    expect(result).toEqual({ error: 209 });
  });

  it("should allow receiver to confirm transfer", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    const result = mockContract.confirmTransfer("ST4RE...", 1);
    expect(result).toEqual({ value: 1 });
    expect(mockContract.getPendingTransfer(1)).toEqual({ value: undefined });
    expect(mockContract.getTransferHistory(1, 1)).toEqual({
      value: { sender: "ST3NB...", receiver: "ST4RE...", transferTimestamp: 100 },
    });
    expect(mockContract.getTransferCount(1)).toEqual({ value: 1 });
  });

  it("should prevent non-receiver from confirming transfer", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    const result = mockContract.confirmTransfer("ST5PQ...", 1);
    expect(result).toEqual({ error: 207 });
  });

  it("should prevent confirming transfer with invalid product ID", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    const result = mockContract.confirmTransfer("ST4RE...", 0);
    expect(result).toEqual({ error: 209 });
  });

  it("should allow sender to cancel transfer", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    const result = mockContract.cancelTransfer("ST3NB...", 1);
    expect(result).toEqual({ value: true });
    expect(mockContract.getPendingTransfer(1)).toEqual({ value: undefined });
  });

  it("should prevent non-sender from canceling transfer", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    const result = mockContract.cancelTransfer("ST5PQ...", 1);
    expect(result).toEqual({ error: 200 });
  });

  it("should prevent canceling transfer with invalid product ID", () => {
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    const result = mockContract.cancelTransfer("ST3NB...", 0);
    expect(result).toEqual({ error: 209 });
  });

  it("should prevent actions when paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    mockProductRegistry.getProductOwner.mockReturnValue("ST3NB...");
    const initiateResult = mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    expect(initiateResult).toEqual({ error: 204 });
    const confirmResult = mockContract.confirmTransfer("ST4RE...", 1);
    expect(confirmResult).toEqual({ error: 204 });
    const cancelResult = mockContract.cancelTransfer("ST3NB...", 1);
    expect(cancelResult).toEqual({ error: 204 });
  });

  it("should prevent confirming non-existent transfer", () => {
    const result = mockContract.confirmTransfer("ST4RE...", 1);
    expect(result).toEqual({ error: 206 });
  });

  it("should prevent initiating transfer for non-existent product", () => {
    mockProductRegistry.getProductOwner.mockReturnValue(null);
    const result = mockContract.initiateTransfer("ST3NB...", 1, "ST4RE...");
    expect(result).toEqual({ error: 201 });
  });
});