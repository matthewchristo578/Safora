import { describe, it, expect, beforeEach } from "vitest";

interface ProductMetadata {
  batchId: string;
  manufacturingDate: number;
  origin: string;
  manufacturer: string;
  mintTimestamp: number;
}

interface ManufacturerInfo {
  name: string;
  registrationTimestamp: number;
}

interface MockContract {
  admin: string;
  paused: boolean;
  lastProductId: number;
  manufacturers: Map<string, boolean>;
  productMetadata: Map<number, ProductMetadata>;
  manufacturerInfo: Map<string, ManufacturerInfo>;
  productOwners: Map<number, string>;
  isAdmin(caller: string): boolean;
  setPaused(caller: string, pause: boolean): { value: boolean } | { error: number };
  addManufacturer(caller: string, manufacturer: string, name: string): { value: boolean } | { error: number };
  removeManufacturer(caller: string, manufacturer: string): { value: boolean } | { error: number };
  mintProduct(caller: string, batchId: string, manufacturingDate: number, origin: string): { value: number } | { error: number };
  getProductMetadata(productId: number): { value: ProductMetadata | undefined };
  getProductOwner(productId: number): { value: string | undefined };
  getManufacturerInfo(manufacturer: string): { value: ManufacturerInfo | undefined };
  isAuthorizedManufacturer(manufacturer: string): { value: boolean };
}

const mockContract: MockContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  lastProductId: 0,
  manufacturers: new Map(),
  productMetadata: new Map(),
  manufacturerInfo: new Map(),
  productOwners: new Map(),

  isAdmin(caller: string) {
    return caller === this.admin;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    return { value: pause };
  },

  addManufacturer(caller: string, manufacturer: string, name: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (manufacturer === "SP000000000000000000002Q6VF78") return { error: 103 };
    if (name.length === 0) return { error: 102 };
    this.manufacturers.set(manufacturer, true);
    this.manufacturerInfo.set(manufacturer, { name, registrationTimestamp: 100 });
    return { value: true };
  },

  removeManufacturer(caller: string, manufacturer: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (!this.manufacturers.get(manufacturer)) return { error: 104 };
    this.manufacturers.delete(manufacturer);
    this.manufacturerInfo.delete(manufacturer);
    return { value: true };
  },

  mintProduct(caller: string, batchId: string, manufacturingDate: number, origin: string) {
    if (this.paused) return { error: 105 };
    if (!this.manufacturers.get(caller)) return { error: 104 };
    if (batchId.length === 0 || batchId.length > 64 || origin.length === 0 || origin.length > 128) return { error: 102 };
    const productId = this.lastProductId + 1;
    if (this.productOwners.get(productId)) return { error: 101 };
    this.productOwners.set(productId, caller);
    this.productMetadata.set(productId, {
      batchId,
      manufacturingDate,
      origin,
      manufacturer: caller,
      mintTimestamp: 100,
    });
    this.lastProductId = productId;
    return { value: productId };
  },

  getProductMetadata(productId: number) {
    return { value: this.productMetadata.get(productId) };
  },

  getProductOwner(productId: number) {
    return { value: this.productOwners.get(productId) };
  },

  getManufacturerInfo(manufacturer: string) {
    return { value: this.manufacturerInfo.get(manufacturer) };
  },

  isAuthorizedManufacturer(manufacturer: string) {
    return { value: !!this.manufacturers.get(manufacturer) };
  },
};

describe("Product Registry Contract", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.lastProductId = 0;
    mockContract.manufacturers.clear();
    mockContract.productMetadata.clear();
    mockContract.manufacturerInfo.clear();
    mockContract.productOwners.clear();
  });

  it("should allow admin to add manufacturer", () => {
    const result = mockContract.addManufacturer(
      mockContract.admin,
      "ST2CY5...",
      "Test Manufacturer"
    );
    expect(result).toEqual({ value: true });
    expect(mockContract.manufacturers.get("ST2CY5...")).toBe(true);
    expect(mockContract.manufacturerInfo.get("ST2CY5...")).toEqual({
      name: "Test Manufacturer",
      registrationTimestamp: 100,
    });
  });

  it("should prevent non-admin from adding manufacturer", () => {
    const result = mockContract.addManufacturer(
      "ST3NB...",
      "ST2CY5...",
      "Test Manufacturer"
    );
    expect(result).toEqual({ error: 100 });
  });

  it("should allow manufacturer to mint product", () => {
    mockContract.addManufacturer(mockContract.admin, "ST2CY5...", "Test Manufacturer");
    const result = mockContract.mintProduct(
      "ST2CY5...",
      "BATCH123",
      1697059200,
      "Factory A"
    );
    expect(result).toEqual({ value: 1 });
    expect(mockContract.productOwners.get(1)).toBe("ST2CY5...");
    expect(mockContract.productMetadata.get(1)).toEqual({
      batchId: "BATCH123",
      manufacturingDate: 1697059200,
      origin: "Factory A",
      manufacturer: "ST2CY5...",
      mintTimestamp: 100,
    });
  });

  it("should prevent minting when paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    mockContract.addManufacturer(mockContract.admin, "ST2CY5...", "Test Manufacturer");
    const result = mockContract.mintProduct(
      "ST2CY5...",
      "BATCH123",
      1697059200,
      "Factory A"
    );
    expect(result).toEqual({ error: 105 });
  });

  it("should prevent non-manufacturer from minting", () => {
    const result = mockContract.mintProduct(
      "ST3NB...",
      "BATCH123",
      1697059200,
      "Factory A"
    );
    expect(result).toEqual({ error: 104 });
  });

  it("should prevent minting with invalid metadata", () => {
    mockContract.addManufacturer(mockContract.admin, "ST2CY5...", "Test Manufacturer");
    const result = mockContract.mintProduct(
      "ST2CY5...",
      "",
      1697059200,
      "Factory A"
    );
    expect(result).toEqual({ error: 102 });
  });

  it("should retrieve product metadata", () => {
    mockContract.addManufacturer(mockContract.admin, "ST2CY5...", "Test Manufacturer");
    mockContract.mintProduct("ST2CY5...", "BATCH123", 1697059200, "Factory A");
    const result = mockContract.getProductMetadata(1);
    expect(result).toEqual({
      value: {
        batchId: "BATCH123",
        manufacturingDate: 1697059200,
        origin: "Factory A",
        manufacturer: "ST2CY5...",
        mintTimestamp: 100,
      },
    });
  });

  it("should retrieve product owner", () => {
    mockContract.addManufacturer(mockContract.admin, "ST2CY5...","Test Manufacturer");
    mockContract.mintProduct("ST2CY5...", "BATCH123", 1697059200, "Factory A");
    const result = mockContract.getProductOwner(1);
    expect(result).toEqual({ value: "ST2CY5..." });
  });
});