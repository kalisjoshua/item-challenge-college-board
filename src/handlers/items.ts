import { createStorage } from "../storage/index.js";

type APIGWResponse = {
  body: any;
  statusCode: number;
};

const storage = createStorage();

export async function createItem(event: any) {
  return withError(async () => {
    // TODO: Add validation using Zod
    if (!event.body || event.body.trim() === "" || event.body === "{}") {
      return {
        body: { error: "Missing request body" },
        statusCode: 400,
      };
    }

    const itemData = JSON.parse(event.body);

    if (!itemData.subject || !itemData.itemType) {
      return {
        body: { error: "Missing required fields: subject and itemType" },
        statusCode: 400,
      };
    }

    const item = await storage.createItem(itemData);

    return {
      body: item,
      statusCode: 201,
    };
  });
}

export async function getItem(event: any) {
  return withError(async () => {
    const item = await storage.getItem(event.pathParameters.id);

    if (!item) {
      return {
        body: { error: "Item not found" },
        statusCode: 404,
      };
    }

    return {
      body: item,
      statusCode: 200,
    };
  });
}

export async function listItems(event: any) {
  return withError(async () => {
    const query = event.queryStringParameters || {};
    const result = await storage.listItems(query);

    return {
      body: result,
      statusCode: 200,
    };
  });
}

async function withError(callback: () => Promise<APIGWResponse>) {
  try {
    const response = await callback();

    response.body = JSON.stringify(response.body);

    return response;
  } catch (error) {
    console.error("Internal error:", error);

    return {
      body: JSON.stringify({ error: "Internal server error" }),
      statusCode: 500,
    };
  }
}

// TODO: Implement other handlers:
// - updateItem
// - createVersion
// - getAuditTrail
