import {
  Action,
  ActionPanel,
  Form,
  popToRoot,
  showToast,
  Toast,
} from "@raycast/api";
import { spawn } from "node:child_process";
import { userInfo } from "node:os";
import { useState } from "react";

type Values = {
  name: string;
  value: string;
  prompt: boolean;
};

function store({ name, value, prompt }: Values): Promise<void> {
  return new Promise((resolve, reject) => {
    const args = [
      "add-generic-password",
      "-U",
      "-a",
      userInfo().username,
      "-s",
      `clau:${name}`,
      "-l",
      `clau:${name}`,
    ];
    if (prompt) args.push("-T", "");
    args.push("-w");
    const child = spawn("/usr/bin/security", args);
    child.stdin.write(`${value}\n${value}\n`);
    child.stdin.end();
    child.on("close", (code) =>
      code === 0
        ? resolve()
        : reject(new Error(`security exited with ${code}`)),
    );
    child.on("error", reject);
  });
}

export default function Command() {
  const [nameError, setNameError] = useState<string | undefined>();

  const submit = async (values: Values) => {
    if (!values.name.trim()) {
      setNameError("Required");
      return;
    }
    if (!values.value) {
      await showToast({ style: Toast.Style.Failure, title: "Value is empty" });
      return;
    }
    try {
      await store(values);
      await showToast({
        style: Toast.Style.Success,
        title: `Stored clau:${values.name}`,
      });
      await popToRoot();
    } catch (error: unknown) {
      await showToast({
        style: Toast.Style.Failure,
        title: "Could not store secret",
        message: error instanceof Error ? error.message : String(error),
      });
    }
  };

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Store in Keychain" onSubmit={submit} />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="name"
        title="Variable"
        placeholder="NOTION_TOKEN"
        error={nameError}
        onChange={() => setNameError(undefined)}
        info="Stored as clau:<name>; reference it as ${name} in mcp.json or keychain:name in .env"
      />
      <Form.PasswordField id="value" title="Value" />
      <Form.Checkbox
        id="prompt"
        label="Ask for approval on every read"
        defaultValue={true}
      />
    </Form>
  );
}
