import { describe, expect, it } from "vitest";
import { createItem, getItem, listItems } from "../handlers/items.js";

describe("Example Handlers", () => {
  describe("createItem", () => {
    it("should create an item successfully", async () => {
      const itemData = {
        subject: "AP Biology",
        itemType: "multiple-choice",
        difficulty: 3,
        content: {
          question: "What is photosynthesis?",
          options: ["A", "B", "C", "D"],
          correctAnswer: "A",
          explanation: "Photosynthesis is the process...",
        },
        metadata: {
          author: "test-author",
          status: "draft",
          tags: ["biology", "photosynthesis"],
        },
        securityLevel: "standard",
      };
      const result = await createItem({ body: JSON.stringify(itemData) });
      const body = JSON.parse(result.body);

      expect(result.statusCode).toBe(201);
      expect(body).toHaveProperty("id");
      if ("subject" in body) {
        expect(body.subject).toBe("AP Biology");
      }
      if ("metadata" in body) {
        expect(body.metadata).toHaveProperty("author", "test-author");
      }
    });

    it("should return 400 for invalid item data - empty", async () => {
      const invalidItemData = {};
      const result = await createItem({
        body: JSON.stringify(invalidItemData),
      });
      const body = JSON.parse(result.body);

      expect(result.statusCode).toBe(400);
      expect(body).toHaveProperty("error");
    });

    // This is where a lot of testing could be done for different error cases using vitest `.each`
    it("should return 400 for invalid item data - missing required fields", async () => {
      const invalidItemData = {
        // subject: "AP Physics", // intentionally commented out to simulate missing required field
        itemType: "multiple-choice",
        // ... many other fields could be missing or invalid...
      };
      const result = await createItem({
        body: JSON.stringify(invalidItemData),
      });
      const body = JSON.parse(result.body);

      expect(result.statusCode).toBe(400);
      expect(body).toHaveProperty("error");
    });
  });

  describe("getItem", () => {
    it("should return 404 for non-existent item", async () => {
      const result = await getItem({
        pathParameters: { id: "non-existent-id" },
      });

      const body = JSON.parse(result.body);

      expect(result.statusCode).toBe(404);
      expect(body).toHaveProperty("error");
      if ("error" in body) {
        expect(body.error).toBe("Item not found");
      }
    });

    it("should retrieve an existing item", async () => {
      // First create an item
      const itemData = {
        subject: "AP Calculus",
        itemType: "free-response",
        difficulty: 4,
        content: {
          question: "Calculate the derivative...",
          correctAnswer: "42",
          explanation: "Using the chain rule...",
        },
        metadata: {
          author: "test-author",
          status: "approved",
          tags: ["calculus", "derivatives"],
        },
        securityLevel: "standard",
      };

      const createResult = await createItem({ body: JSON.stringify(itemData) });
      const createBody = JSON.parse(createResult.body);

      expect(createBody).toHaveProperty("id");

      if (!("id" in createBody)) {
        throw new Error("Item creation failed");
      }

      const getResult = await getItem({
        pathParameters: { id: createBody.id },
      });
      const body = JSON.parse(getResult.body);
      const itemId = body.id;

      // Then retrieve it

      expect(getResult.statusCode).toBe(200);
      expect(body).toHaveProperty("id", itemId);
      if ("subject" in body) {
        expect(body.subject).toBe("AP Calculus");
      }
    });
  });

  describe("listItems", () => {
    it("should list items with query parameters", async () => {
      const result = await listItems({
        queryStringParameters: { subject: "AP Biology" },
      });

      const { items } = JSON.parse(result.body);

      expect(result.statusCode).toBe(200);
      expect(Array.isArray(items)).toBe(true);

      if (items.length > 0) {
        expect(items[0]).toHaveProperty("subject", "AP Biology");
      }
    });
  });
});
