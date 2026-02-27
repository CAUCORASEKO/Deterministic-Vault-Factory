import { invoke } from "@tauri-apps/api/core";

type ErrorPayload = {
  message?: unknown;
  error?: unknown;
  stderr?: unknown;
  stdout?: unknown;
};

export type RunAnalysisResult = {
  stdout: string;
  report_path: string;
  vault_path: string;
};

export class CliInvokeError extends Error {
  stderr?: string;
  stdout?: string;

  constructor(message: string, stderr?: string, stdout?: string) {
    super(message);
    this.name = "CliInvokeError";
    this.stderr = stderr;
    this.stdout = stdout;
  }
}

function asString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0 ? value : undefined;
}

function normalizeInvokeError(error: unknown): CliInvokeError {
  if (error instanceof CliInvokeError) {
    return error;
  }

  if (typeof error === "string") {
    return new CliInvokeError(error);
  }

  if (error instanceof Error) {
    const payload = error as Error & ErrorPayload;
    const message = asString(payload.message) ?? error.message ?? "Unknown error";
    const stderr = asString(payload.stderr);
    const stdout = asString(payload.stdout);
    return new CliInvokeError(message, stderr, stdout);
  }

  if (error && typeof error === "object") {
    const payload = error as ErrorPayload;
    const message = asString(payload.message) ?? asString(payload.error) ?? "Unknown error";
    const stderr = asString(payload.stderr);
    const stdout = asString(payload.stdout);
    return new CliInvokeError(message, stderr, stdout);
  }

  return new CliInvokeError("Unknown error");
}

export async function runAnalysis(inputPath: string): Promise<RunAnalysisResult> {
  try {
    return await invoke<RunAnalysisResult>("run_analysis", { inputPath });
  } catch (error: unknown) {
    throw normalizeInvokeError(error);
  }
}

export async function buildEvidencePackage(inputHash: string): Promise<string> {
  try {
    return await invoke<string>("build_package", { hash: inputHash });
  } catch (error: unknown) {
    throw normalizeInvokeError(error);
  }
}

export async function verifyEvidencePackage(zipPath: string): Promise<string> {
  try {
    return await invoke<string>("verify_package", { zip_path: zipPath });
  } catch (error: unknown) {
    throw normalizeInvokeError(error);
  }
}
