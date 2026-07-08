export type BridgePayload = Record<string, unknown>;

export interface BridgeRequest {
  action: string;
  payload?: BridgePayload;
}

export interface BridgeError {
  code: string;
  message: string;
}

export interface BridgeResponse {
  ok: boolean;
  result?: unknown;
  error?: BridgeError;
}

export class BridgeClient {
  constructor(
    private readonly baseURL: string,
    private readonly token: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async call(action: string, payload: BridgePayload = {}): Promise<unknown> {
    const response = await this.fetchImpl(`${this.baseURL}/bridge`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${this.token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ action, payload } satisfies BridgeRequest),
    });

    const body = (await response.json()) as BridgeResponse;
    if (!response.ok || !body.ok) {
      const message = body.error?.message ?? `Bridge request failed with ${response.status}`;
      throw new Error(message);
    }
    return body.result;
  }
}
