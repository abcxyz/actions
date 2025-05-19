// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import assert from "node:assert/strict";
import { test } from "node:test";
import * as ghCore from "@actions/core";
import { context as ghContext } from "@actions/github";
import { main } from "../src/main";

type Core = typeof ghCore;
type Context = typeof ghContext;

function newFakeCore(inputs: { [key: string]: string }): Core {
  return {
    debug: () => {},
    getInput: (name: string) => inputs[name],
    info: () => {},
    setFailed: () => {},
  } as unknown as Core;
}

const BASE_PULL_REQUEST = {
  eventName: "pull_request",
  runId: 1,
  payload: {
    pull_request: {
      number: 1,
      head: {
        ref: "fake-branch",
      },
      user: {
        login: "test-user",
        id: 12345,
      },
    },
    repository: {
      name: "fake-repository",
      owner: {
        login: "test-org",
      },
    },
  },
} as unknown as Context;

function createFakeContext(overrides: Partial<Context> = {}): Context {
  return Object.assign({}, BASE_PULL_REQUEST, overrides) as Context;
}

test("#main", { concurrency: true }, async (suite) => {
  await suite.test("should fail on unsupported event", async (t) => {
    const core = newFakeCore({ token: "fake-token", team: "fake-team" });
    const setFailed = t.mock.method(core, "setFailed", () => {});
    const context = createFakeContext({ eventName: "push" });

    await main(core, context);

    assert.equal(setFailed.mock.calls.length, 1);
    const failMsg = setFailed.mock.calls[0].arguments[0];
    assert.equal(
      failMsg,
      "Multi-approvers action failed: unexpected event [push].",
    );
  });

  await suite.test(
    "should fail if user-id-allowlist contains invalid numeric ID",
    async (t) => {
      const invalidAllowlistInput = "123,abc,456";
      const core = newFakeCore({
        token: "fake-token",
        team: "fake-team",
        "user-id-allowlist": invalidAllowlistInput,
      });
      const setFailed = t.mock.method(core, "setFailed", () => {});
      const context = createFakeContext();

      await main(core, context);

      assert.equal(setFailed.mock.calls.length, 1);
      const failMsg = String(setFailed.mock.calls[0].arguments[0]);

      assert.equal(
        failMsg,
        "Multi-approvers action failed: invalid allowlisted user ID: [abc]. Full input (user-id-allowlist): [123,abc,456]",
      );
    },
  );

  await suite.test(
    "should fail if user-id-allowlist contains invalid numeric IDs with spaces",
    async (t) => {
      const allowlistWithSpacesInput = "123, 9, 456, a, b";
      const core = newFakeCore({
        token: "fake-token",
        team: "fake-team",
        "user-id-allowlist": allowlistWithSpacesInput,
      });
      const setFailed = t.mock.method(core, "setFailed", () => {});
      const context = createFakeContext();

      await main(core, context);

      assert.equal(setFailed.mock.calls.length, 1);
      const failMsg = String(setFailed.mock.calls[0].arguments[0]);

      assert.equal(
        failMsg,
        "Multi-approvers action failed: invalid allowlisted user ID: [a]. Full input (user-id-allowlist): [123, 9, 456, a, b]",
      );
    },
  );
});
